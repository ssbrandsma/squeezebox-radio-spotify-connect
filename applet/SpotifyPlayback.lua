local oo = require("loop.simple")
local Player = require("jive.slim.Player")
local decode = require("squeezeplay.decode")
local Stream = require("squeezeplay.stream")
local string = require("string")
local math = require("math")

module(...)
oo.class(_M)

function init(self, applet)
    self.applet = applet
    self.playback = nil
    self.paused = false
end

function start(self, host, port, path)
    local player = Player:getLocalPlayer() or Player:getCurrentPlayer()
    if not player then return false end
    self.playback = player.playback
    if not self.playback then return false end
    self.paused = false
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
    Stream:icyMetaInterval(0)
    decode:start(string.byte('o'), 0, 0, 0, 0, 0, 0, 0, 0, 0)
    self.playback:_streamConnect(host, port)
    if self.remoteVolume then self:setRemoteVolume(self.remoteVolume) end
    return true
end

function setRemoteVolume(self, percent)
    self.remoteVolume = math.max(0, math.min(100, math.floor(percent)))
    if not self.playback then return false end
    local player = Player:getLocalPlayer()
    if not player or player.playback ~= self.playback then return false end
    -- Keep server gain messages from overriding this local command. Store
    -- the volume through the firmware API, then apply its curve explicitly
    -- to the Spotify decoder (including a defined zero/mute gain).
    player:volumeLocal(self.remoteVolume, true, true)
    local gain = self.remoteVolume == 0 and 0 or self.playback:_getGainFromVolume(self.remoteVolume)
    decode:audioGain(gain, gain)
    return true
end

function stop(self)
    if self.playback then self.playback:stopInternal(); self.playback = nil end
    self.paused = false
end

function pause(self)
    if not self.playback then return false end
    local player = Player:getLocalPlayer()
    if not player or player.playback ~= self.playback then return false end
    self.playback:pause()
    self.paused = true
    return true
end

function resume(self)
    if not self.playback or not self.paused then return false end
    local player = Player:getLocalPlayer()
    if not player or player.playback ~= self.playback or not self.playback.stream then
        self.paused = false
        return false
    end
    decode:resumeAudio()
    self.playback.sentResume = true
    self.playback.sentDecoderFullEvent = true
    self.paused = false
    return true
end
