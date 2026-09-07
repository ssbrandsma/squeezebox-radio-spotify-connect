local oo = require("loop.simple")
local Player = require("jive.slim.Player")

module(...)
oo.class(_M)

function init(self, applet)
    self.applet = applet
    self.playback = nil
end

function start(self, host, port, path)
    local player = Player:getLocalPlayer() or Player:getCurrentPlayer()
    if not player then return false end
    self.playback = player.playback
    if not self.playback then return false end
    self.playback:stopInternal()
    if player.incrementSequenceNumber then player:incrementSequenceNumber() end
    self.playback.flags = 0
    self.playback.mode = 'o'
    self.playback.header = "GET " .. path .. " HTTP/1.0\n" ..
        "Host: " .. host .. "\n" ..
        "Accept: audio/ogg,audio/vorbis,*/*\n" ..
        "Connection: close\n\n"
    self.playback.autostart = '1'
    self.playback.threshold = 0
    self.playback.decodeThreshold = 2048
    self.playback.sentResume = false
    self.playback.sentResumeDecoder = false
    self.playback.sentDecoderFullEvent = false
    self.playback.sentOutputUnderrunEvent = false
    self.playback.sentAudioUnderrunEvent = false
    self.playback.isLooping = false
    self.playback.ignoreStream = false
    local decode = require("squeezeplay.decode")
    require("squeezeplay.stream"):icyMetaInterval(0)
    decode:start(string.byte('o'), 0, 0, 0, 0, 0, 0, 0, 0, 0)
    self.playback:_streamConnect(host, port)
    return true
end

function stop(self)
    if self.playback then self.playback:stopInternal(); self.playback = nil end
end
