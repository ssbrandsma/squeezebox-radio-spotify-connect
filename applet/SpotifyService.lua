local oo = require("loop.simple")
local Timer = require("jive.ui.Timer")
local os = require("os")
local io = require("io")
local pcall = pcall
local type = type
local tonumber = tonumber
local okJson, json = pcall(require, "json")
if not okJson then json = nil end

module(...)
oo.class(_M)

local ROOT = "/usr/share/jive/applets/SpotifyConnect"
local USER = "/etc/squeezeplay/userpath/SpotifyConnect"
local FIFO = USER .. "/audio.fifo"
local PID = USER .. "/librespot.pid"
local BPID = USER .. "/bridge.pid"
local STATUS = USER .. "/status.json"
local METADATA = USER .. "/metadata.json"
local METADATA_STATE = METADATA .. ".state"
local METADATA_VOLUME = METADATA .. ".volume"
local METADATA_LOADING = METADATA .. ".loading"
local STREAM_MARKER = USER .. "/stream.ready"
local LOG = USER .. "/engine.log"
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

function init(self, applet) self.applet = applet end
function credentialsExist(self) return os.execute("test -s " .. q(USER .. "/credentials.json") .. " 2>/dev/null") == 0 end
function isRunning(self)
    return os.execute("test -s " .. q(PID) .. " && p=`cat " .. q(PID) .. "` && kill -0 $p 2>/dev/null && tr '\\000' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q spotify-supervisor") == 0
end
function status(self)
    local f = io.open(STATUS, "r"); if not f then return "not_connected" end
    local s = f:read("*a"); f:close(); return s:match('"state":"([^"]+)"') or "starting"
end
function statusData(self)
    local d = { state = "not_connected" }
    local f = io.open(STATUS, "r")
    if f then
        local s = f:read("*a"); f:close()
        d.state = s:match('"state":"([^"]+)"') or d.state
        d.url, d.message = s:match('"url":"([^"]+)"'), s:match('"message":"([^"]+)"')
    end
    local m = io.open(METADATA, "r")
    if m then
        local ms = m:read("*a"); m:close()
        local ok, parsed = pcall(function() return json.decode(ms) end)
        if ok and type(parsed) == "table" then
            d.playback_state, d.track_id = parsed.playback_state, parsed.track_id
            d.title, d.artist, d.album = parsed.title, parsed.artist, parsed.album
            d.duration_ms, d.artwork_url = parsed.duration_ms, parsed.artwork_url
        else
            -- Keep the display useful on firmware without the JSON module.
            d.playback_state = ms:match('"playback_state":"([^"]*)"')
            d.track_id = ms:match('"track_id":"([^"]*)"')
            d.title = ms:match('"title":"([^"]*)"')
            d.artist = ms:match('"artist":"([^"]*)"')
            d.album = ms:match('"album":"([^"]*)"')
            d.duration_ms = ms:match('"duration_ms":"([^"]*)"')
            d.artwork_url = ms:match('"artwork_url":"([^"]*)"')
        end
    end
    local st = io.open(METADATA_STATE, "r")
    if st then d.playback_state = st:read("*a"):gsub("%s", ""); st:close() end
    local vf = io.open(METADATA_VOLUME, "r")
    if vf then d.volume = tonumber(vf:read("*a")); vf:close() end
    return d
end
local function readSmall(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local value = f:read("*a"); f:close()
    if not value then return nil end
    return (value:gsub("%s+$", ""))
end
-- Read only the tiny files written by native event producers. This method is
-- called frequently, so it deliberately avoids process creation and JSON.
function eventData(self)
    return {
        loading = readSmall(METADATA_LOADING),
        stream = readSmall(STREAM_MARKER),
        volume = tonumber(readSmall(METADATA_VOLUME)),
    }
end
local function defaultName()
    local f = io.open("/sys/class/net/wlan0/address", "r")
    if not f then return "Squeezebox Radio" end
    local mac = f:read("*a"); f:close(); mac = mac:gsub("%s", "")
    if #mac >= 2 then return "Squeezebox Radio-" .. mac:sub(-2):upper() end
    return "Squeezebox Radio"
end
function start(self, pairing)
    if self:isRunning() then return true end
    os.execute("mkdir -p " .. q(USER) .. "; chmod 700 " .. q(USER) .. "; rm -f " .. q(STATUS) .. " " .. q(METADATA) .. " " .. q(METADATA_STATE) .. " " .. q(METADATA_VOLUME) .. " " .. q(METADATA_LOADING) .. " " .. q(STREAM_MARKER))
    os.execute("test -p " .. q(FIFO) .. " || mkfifo " .. q(FIFO) .. "; chmod 600 " .. q(FIFO))
    os.execute("( exec 3<>" .. q(FIFO) .. "; exec " .. q(ROOT .. "/ogg-http-bridge") .. " 17880 --unpaced --stream-marker " .. q(STREAM_MARKER) .. " <" .. q(FIFO) .. " >>" .. q(LOG) .. " 2>&1 ) & echo $! >" .. q(BPID))
    local auth = ""; if pairing or not self:credentialsExist() then auth = " --enable-device-auth" end
    local settings = self.applet._settings or {}
    local name = settings.deviceName or "Squeezebox Radio"
    if name == "Squeezebox Radio" then name = defaultName() end
    local metadataCommand = ROOT .. "/spotify-metadata " .. METADATA
    local cmd = "( exec " .. q(ROOT .. "/spotify-supervisor") .. " --status " .. q(STATUS) .. " -- " .. q(ROOT .. "/librespot") ..
        " --name " .. q(name) .. " --onevent " .. q(metadataCommand) .. " --backend pipe --device " .. q(FIFO) .. " --passthrough --disable-audio-cache --disable-discovery --system-cache " .. q(USER) .. " --bitrate 96" .. auth .. " >>" .. q(LOG) .. " 2>&1 ) & echo $! >" .. q(PID)
    os.execute(cmd); return true
end
function stop(self)
    local cmd = "if test -s " .. q(PID) .. "; then kill -TERM `cat " .. q(PID) .. "` 2>/dev/null; fi; if test -s " .. q(BPID) .. "; then kill -TERM `cat " .. q(BPID) .. "` 2>/dev/null; fi; for p in `ps | grep '/usr/share/jive/applets/SpotifyConnect/librespot' | grep -v grep | awk '{print $1}'`; do kill -TERM $p 2>/dev/null; done; for p in `ps | grep '/usr/share/jive/applets/SpotifyConnect/ogg-http-bridge' | grep -v grep | awk '{print $1}'`; do kill -TERM $p 2>/dev/null; done; sleep 1; rm -f " .. q(PID) .. " " .. q(BPID) .. " " .. q(FIFO)
    os.execute(cmd .. "; rm -f " .. q(STATUS) .. " " .. q(METADATA) .. " " .. q(METADATA_STATE) .. " " .. q(METADATA_VOLUME) .. " " .. q(METADATA_LOADING) .. " " .. q(STREAM_MARKER))
end
function restart(self) self:stop(); Timer(400, function() self:start(false) end, true):start(); return true end
function disconnect(self) self:stop(); os.execute("rm -f " .. q(USER .. "/credentials.json") .. " " .. q(USER .. "/volume")) end
return _M
