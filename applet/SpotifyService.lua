local oo = require("loop.simple")
local Process = require("jive.net.Process")
local System = require("jive.System")
local Playback = require("applets.SpotifyConnect.SpotifyPlayback")
local jnt = jnt

module(...)
oo.class(_M)

function init(self, applet)
    self.applet = applet
    self.process = nil
    self.playback = Playback(applet)
    self.binary = "/usr/share/jive/applets/SpotifyConnect/ogg-http-bridge"
end

function isRunning(self)
    return self.process ~= nil
end

function status(self)
    return self:isRunning() and "running" or "stopped"
end

function start(self)
    if self:isRunning() then return true end
    -- The applet owns only this executable; chmod is idempotent and local.
    os.execute("chmod 755 " .. self.binary .. " 2>/dev/null")
    self.process = Process(jnt, self.binary .. " --source http://live.chbnradio.org:8000/chbn.ogg")
    self.process:read(function(chunk)
        if chunk then log:debug("SpotifyConnect: ", chunk) end
    end)
    self.playback:start("127.0.0.1", 17880, "/test.ogg")
    return true
end

function stop(self)
    self.playback:stop()
    if self.process then
        self.process:kill()
        self.process = nil
    end
end

function restart(self)
    self:stop()
    return self:start()
end
