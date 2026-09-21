local os, pcall, tostring, setmetatable = os, pcall, tostring, setmetatable
local io = require("io")
local math = require("math")
local Framework = require("jive.ui.Framework")
local Font = require("jive.ui.Font")
local Icon = require("jive.ui.Icon")
local Label = require("jive.ui.Label")
local Surface = require("jive.ui.Surface")
local Tile = require("jive.ui.Tile")
local Window = require("jive.ui.Window")
local Timer = require("jive.ui.Timer")
local Artwork = require("applets.SpotifyConnect.SpotifyArtwork")
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local LAYOUT_NONE = jive.ui.LAYOUT_NONE
local FALLBACK_ART = "/usr/share/jive/applets/SpotifyConnect/spotify-logo.jpg"
local ARTWORK_SIZE = 168
local SCREEN_WIDTH = 320
local SCREEN_HEIGHT = 240
module(...)
local NowPlaying = {}; NowPlaying.__index = NowPlaying
local function loadImage(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local data = f:read("*a"); f:close(); if not data or data == "" then return nil end
    return Surface:loadImageData(data, #data)
end
local function setInfo(label, text)
    label:setValue(text)
    if label.reLayout then label:reLayout() end
    if label.reDraw then label:reDraw() end
end
function new(applet, log)
    local self = setmetatable({ applet = applet, log = log, key = nil, surface = nil, timer = nil }, NowPlaying)
    self.artwork = Artwork.new(log, function(path, key) self:_setArtwork(path, key) end)
    return self
end
function NowPlaying:_window()
    if self.window then return end
    local w = Window("spotify_nowplaying")
    w:setSkin({
        spotify_nowplaying = {
            w = SCREEN_WIDTH,
            h = SCREEN_HEIGHT,
            layout = Window.borderLayout,
            bgImg = Tile:fillColor(0x000000ff),
            artist = {
                position = LAYOUT_NONE,
                x = 8, y = 4, w = SCREEN_WIDTH - 16, h = 24,
                padding = 0,
                align = "left",
                font = Font:load("fonts/FreeSans.ttf", 16),
                fg = { 0xb3, 0xb3, 0xb3 },
            },
            track = {
                position = LAYOUT_NONE,
                x = 8, y = 28, w = SCREEN_WIDTH - 16, h = 28,
                padding = 0,
                align = "left",
                font = Font:load("fonts/FreeSansBold.ttf", 18),
                fg = { 0xe7, 0xe7, 0xe7 },
            },
            artwork = {
                position = LAYOUT_NONE,
                x = 0, y = 64, w = SCREEN_WIDTH, h = SCREEN_HEIGHT - 64,
                padding = 0,
                align = "center",
            },
        },
    })
    w:setShowFrameworkWidgets(false)
    self.artist = Label("artist", "Waiting for Spotify...")
    self.title = Label("track", "")
    self.icon = Icon("artwork")
    local fallback = loadImage(FALLBACK_ART)
    if fallback then self.surface = fallback; self.icon:setValue(fallback) end
    w:addWidget(self.artist)
    w:addWidget(self.title)
    w:addWidget(self.icon)
    w:addListener(EVENT_WINDOW_POP, function() self:close() end)
    self.window = w
end
function NowPlaying:_setArtwork(path, key)
    if key ~= self.key then os.remove(path); return end
    local ok, surface = pcall(loadImage, path); os.remove(path)
    if not ok or not surface then return end
    local width, height = surface:getSize(); local scale = math.min(ARTWORK_SIZE / width, ARTWORK_SIZE / height)
    if scale < 1 then local scaled = surface:zoom(scale, scale, 1); surface:release(); surface = scaled end
    if surface then self.surface = surface; self.icon:setValue(surface); self.icon:reLayout(); self.icon:reDraw() end
end
function NowPlaying:_showFallback()
    local surface = loadImage(FALLBACK_ART)
    if surface then
        self.surface = surface; self.icon:setValue(surface); self.icon:reLayout(); self.icon:reDraw()
    end
end
function NowPlaying:update()
    local d = self.applet.service:statusData()
    local title, artist = d.title or "", d.artist or ""
    if title == "" and artist == "" then
        setInfo(self.artist, "Waiting for Spotify...")
        setInfo(self.title, "")
    else
        setInfo(self.artist, artist)
        setInfo(self.title, title)
    end
    local key = d.track_id or (artist .. "\0" .. title)
    if key ~= self.key then
        self.key = key; self.artwork:cancel()
        self:_showFallback()
        if title ~= "" and artist ~= "" then self.artwork:lookup(title, artist, d.artwork_url, key) end
    end
end
function NowPlaying:show()
    self:_window(); self:update(); self.window:show()
    if not self.timer then self.timer = Timer(1000, function() self:update() end); self.timer:start() end
end
function NowPlaying:close()
    if self.timer then self.timer:stop(); self.timer = nil end
    self.artwork:cancel()
end
return _M
