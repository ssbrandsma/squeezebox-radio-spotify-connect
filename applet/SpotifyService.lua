local oo = require("loop.simple")
local Timer = require("jive.ui.Timer")

module(...)
oo.class(_M)

local ROOT = "/usr/share/jive/applets/SpotifyConnect"
local USER = "/etc/squeezeplay/userpath/SpotifyConnect"
local FIFO = USER .. "/audio.fifo"
local PID = USER .. "/librespot.pid"
local BPID = USER .. "/bridge.pid"
local STATUS = USER .. "/status.json"
local LOG = USER .. "/engine.log"
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

function init(self, applet) self.applet = applet end
function credentialsExist(self) return os.execute("test -s " .. q(USER .. "/credentials.json") .. " 2>/dev/null") == 0 end
function isRunning(self) return os.execute("test -s " .. q(PID) .. " && kill -0 `cat " .. q(PID) .. "` 2>/dev/null") == 0 end
function status(self)
    local f = io.open(STATUS, "r"); if not f then return "not_connected" end
    local s = f:read("*a"); f:close(); return s:match('"state":"([^"]+)"') or "starting"
end
function statusData(self)
    local f = io.open(STATUS, "r"); if not f then return { state = "not_connected" } end
    local s = f:read("*a"); f:close()
    return { state = s:match('"state":"([^"]+)"') or "starting", url = s:match('"url":"([^"]+)"'), message = s:match('"message":"([^"]+)"') }
end
function start(self, pairing)
    if self:isRunning() then return true end
    os.execute("mkdir -p " .. q(USER) .. "; chmod 700 " .. q(USER) .. "; rm -f " .. q(STATUS))
    os.execute("test -p " .. q(FIFO) .. " || mkfifo " .. q(FIFO) .. "; chmod 600 " .. q(FIFO))
    os.execute("( exec 3<>" .. q(FIFO) .. "; exec " .. q(ROOT .. "/ogg-http-bridge") .. " 17880 <" .. q(FIFO) .. " >>" .. q(LOG) .. " 2>&1 ) & echo $! >" .. q(BPID))
    local auth = ""; if pairing or not self:credentialsExist() then auth = " --enable-device-auth" end
    local settings = self.applet:getSettings()
    local name = settings.deviceName or "Squeezebox Radio"
    local cmd = "( exec " .. q(ROOT .. "/spotify-supervisor") .. " --status " .. q(STATUS) .. " -- " .. q(ROOT .. "/librespot") ..
        " --name " .. q(name) .. " --backend pipe --device " .. q(FIFO) .. " --passthrough --disable-audio-cache --system-cache " .. q(USER) .. " --bitrate 96" .. auth .. " >>" .. q(LOG) .. " 2>&1 ) & echo $! >" .. q(PID)
    os.execute(cmd); return true
end
function stop(self)
    os.execute("if test -s " .. q(PID) .. "; then kill -TERM `cat " .. q(PID) .. "` 2>/dev/null; fi; if test -s " .. q(BPID) .. "; then kill -TERM `cat " .. q(BPID) .. "` 2>/dev/null; fi; rm -f " .. q(PID) .. " " .. q(BPID) .. " " .. q(FIFO))
end
function restart(self) self:stop(); Timer(400, function() self:start(false) end, true):start(); return true end
function disconnect(self) self:stop(); os.execute("rm -f " .. q(USER .. "/credentials.json") .. " " .. q(USER .. "/volume")) end
return _M
