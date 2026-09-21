local oo = require("loop.simple")
local Applet = require("jive.Applet")
local Framework = require("jive.ui.Framework")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Window = require("jive.ui.Window")
local Popup = require("jive.ui.Popup")
local Group = require("jive.ui.Group")
local Icon = require("jive.ui.Icon")
local Label = require("jive.ui.Label")
local Slider = require("jive.ui.Slider")
local SpotifyService = require("applets.SpotifyConnect.SpotifyService")
local SpotifyPlayback = require("applets.SpotifyConnect.SpotifyPlayback")
local SpotifyNowPlaying = require("applets.SpotifyConnect.SpotifyNowPlaying")
local Player = require("jive.slim.Player")
local Timer = require("jive.ui.Timer")
local math = require("math")
local Log = require("jive.utils.log")
local state = require("applets.SpotifyConnect.SpotifyConnectState")
local tostring = tostring

module(..., Framework.constants)
oo.class(_M, Applet)

local function showRemoteVolume(self, percent)
    if not self._volumePopup then
        local popup = Popup("slider_popup")
        popup:setAutoHide(false)
        popup:setAlwaysOnTop(true)
        self._volumeTitle = Label("heading", "")
        self._volumeIcon = Icon("icon_popup_volume")
        self._volumeSlider = Slider("volume_slider", -1, 100, percent, function() end)
        popup:addWidget(self._volumeTitle)
        popup:addWidget(self._volumeIcon)
        popup:addWidget(Group("slider_group", { slider = self._volumeSlider }))
        popup:focusWidget(nil)
        self._volumePopup = popup
    end
    self._volumeTitle:setValue(percent == 0 and "Muted" or tostring(percent))
    self._volumeIcon:setStyle(percent == 0 and "icon_popup_mute" or "icon_popup_volume")
    self._volumeSlider:setValue(percent)
    local popup = self._volumePopup
    popup:showBriefly(1800, function()
        if self._volumePopup == popup then
            self._volumePopup, self._volumeTitle = nil, nil
            self._volumeIcon, self._volumeSlider = nil, nil
        end
    end, Window.transitionNone, Window.transitionNone)
end

function init(self)
    self._settings = self._settings or { enabled = false, deviceName = "Squeezebox Radio" }
    state.applet = self
    self.service = SpotifyService()
    self.service:init(self)
    self.playback = SpotifyPlayback()
    self.playback:init(self)
    self.nowPlaying = SpotifyNowPlaying.new(self, Log.logger("SpotifyConnect"))
    self._lastLoadingTrack = nil
    self._lastStreamMarker = nil
    self._lastPlaybackState = nil
    self._lastRemoteVolume = nil
    self._trackWatcher = Timer(100, function()
        local d = self.service:eventData()
        if d.loading and d.loading ~= self._lastLoadingTrack then
            Log.logger("SpotifyConnect"):info("track loading: ", d.loading)
            self.playback:stop()
        end
        self._lastLoadingTrack = d.loading or self._lastLoadingTrack
        local streamChanged = d.stream and d.stream ~= self._lastStreamMarker
        if d.playback_state and d.playback_state ~= self._lastPlaybackState then
            if d.playback_state == "paused" or d.playback_state == "stopped" then
                Log.logger("SpotifyConnect"):info("remote playback state: ", d.playback_state)
                self.playback:stop()
            elseif d.playback_state == "playing" and self._lastPlaybackState == "paused" and not streamChanged then
                Log.logger("SpotifyConnect"):info("remote playback resumed")
                self.playback:start("127.0.0.1", 17880, "/spotify.ogg")
            end
        end
        self._lastPlaybackState = d.playback_state or self._lastPlaybackState
        if streamChanged then
            Log.logger("SpotifyConnect"):info("stream ready: ", d.stream, "; starting local playback")
            self.playback:start("127.0.0.1", 17880, "/spotify.ogg")
        end
        self._lastStreamMarker = d.stream or self._lastStreamMarker
        if d.volume and d.volume ~= self._lastRemoteVolume then
            local percent = math.floor((d.volume * 100 / 65535) + 0.5)
            percent = math.max(0, math.min(100, percent))
            local applied = self.playback:setRemoteVolume(percent)
            Log.logger("SpotifyConnect"):info("remote volume: ", percent, " applied=", applied)
            if applied then showRemoteVolume(self, percent) end
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
