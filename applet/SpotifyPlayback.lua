local oo = require("loop.simple")
local Player = require("jive.slim.Player")
local jive = jive

module(...)
oo.class(_M)

function init(self)
    self.playback = nil
end

function start(self, host, port, path)
    local player = Player:getCurrentPlayer()
    if not player then return false end
    self.playback = player:getPlayback()
    if not self.playback then return false end
    self.playback.flags = 0
    self.playback.mode = 'o'
    self.playback.header = "GET " .. path .. " HTTP/1.0\n" ..
        "Host: " .. host .. "\n" ..
        "Accept: audio/ogg,audio/vorbis,*/*\n" ..
        "Connection: close\n\n"
    self.playback.autostart = '1'
    self.playback.threshold = 0
    self.playback.decodeThreshold = 2048
    local decode = self.playback.decode
    if decode then decode:start(string.byte('o'), 0, 0, 0, 0, 0, 0, 0, 0, 0) end
    self.playback:_streamConnect(host, port)
    return true
end

function stop(self)
    if self.playback then self.playback:stopInternal(); self.playback = nil end
end
