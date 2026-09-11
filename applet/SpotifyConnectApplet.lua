local oo = require("loop.simple")
local Applet = require("jive.Applet")
local Framework = require("jive.ui.Framework")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Window = require("jive.ui.Window")
local SpotifyService = require("applets.SpotifyConnect.SpotifyService")
local SpotifyPlayback = require("applets.SpotifyConnect.SpotifyPlayback")
local SpotifyNowPlaying = require("applets.SpotifyConnect.SpotifyNowPlaying")
local Player = require("jive.slim.Player")
local Timer = require("jive.ui.Timer")
local math = require("math")
local Log = require("jive.utils.log")
local state = require("applets.SpotifyConnect.SpotifyConnectState")

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self)
    self._settings = self._settings or { enabled = false, deviceName = "Squeezebox Radio" }
    state.applet = self
    self.service = SpotifyService()
    self.service:init(self)
    self.playback = SpotifyPlayback()
    self.playback:init(self)
    self.nowPlaying = SpotifyNowPlaying.new(self, Log.logger("SpotifyConnect"))
    self._lastTrackId = nil
    self._lastRemoteVolume = nil
    self._trackWatcher = Timer(500, function()
        local d = self.service:statusData()
        if d.track_id and self._lastTrackId and d.track_id ~= self._lastTrackId then
            Log.logger("SpotifyConnect"):info("track changed; reconnecting local playback")
            self.playback:stop()
            Timer(50, function()
                self.playback:start("127.0.0.1", 17880, "/spotify.ogg")
            end, true):start()
        end
        self._lastTrackId = d.track_id or self._lastTrackId
        if d.volume and d.volume ~= self._lastRemoteVolume then
            local percent = math.floor((d.volume * 100 / 65535) + 0.5)
            percent = math.max(0, math.min(100, percent))
            local applied = self.playback:setRemoteVolume(percent)
            Log.logger("SpotifyConnect"):info("remote volume: ", percent, " applied=", applied)
            self._lastRemoteVolume = d.volume
        end
    end)
    self._trackWatcher:start()
    state.service = self.service
    local settings = self._settings
    if settings.enabled and self.service:credentialsExist() then
        Timer(2500, function()
            self.service:start(false)
            Timer(1500, function() self.playback:start("127.0.0.1", 17880, "/spotify.ogg") end, true):start()
        end, true):start()
    end
end

local function statusText(self)
    return self.service:isRunning() and self:string("STATUS_RUNNING") or self:string("STATUS_STOPPED")
end

function menu(self)
    local window = Window("text_list", self:string("SPOTIFY_CONNECT"))
    local menu = SimpleMenu("menu")
    window:addWidget(menu)
    menu:addItem({text = self:string("START_TEST_STREAM"), sound = "WINDOW_OPEN", callback = function() self.service:start() end})
    menu:addItem({text = self:string("STOP"), callback = function() self.service:stop() end})
    menu:addItem({text = self:string("STATUS"), callback = function() log:info("SpotifyConnect: ", statusText(self)) end})
    menu:addItem({text = self:string("RESTART_SERVICE"), callback = function() self.service:restart() end})
    self:tieAndShowWindow(window)
end

-- Keep the public name used by older menu registrations as an alias.
showMenu = menu

-- Explicit exports keep the methods visible on older Lua module loaders.
_M.menu = menu
_M.showMenu = menu
return _M
