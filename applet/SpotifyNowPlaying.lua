local os, pcall, tostring = os, pcall, tostring
local io = require("io")
local math = require("math")
local Framework = require("jive.ui.Framework")
local Group = require("jive.ui.Group")
local Icon = require("jive.ui.Icon")
local Label = require("jive.ui.Label")
local Surface = require("jive.ui.Surface")
local Window = require("jive.ui.Window")
local Timer = require("jive.ui.Timer")
local Artwork = require("applets.SpotifyConnect.SpotifyArtwork")
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
module(...)
local NowPlaying = {}; NowPlaying.__index = NowPlaying
local function loadImage(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local data = f:read("*a"); f:close(); if not data or data == "" then return nil end
    return Surface:loadImageData(data, #data)
end
function new(applet, log)
    local self = setmetatable({ applet = applet, log = log, key = nil, surface = nil, timer = nil }, NowPlaying)
    self.artwork = Artwork.new(log, function(path, key) self:_setArtwork(path, key) end)
    return self
end
function NowPlaying:_window()
    if self.window then return end
    local w = Window("linein", "Spotify Connect")
    self.title = Label("text", "Spotify Connect"); self.info = Label("nptrack", "Waiting for Spotify..."); self.icon = Icon("icon_linein")
    w:addWidget(Group("title", { lbutton = w:createDefaultLeftButton(), text = self.title, rbutton = nil }))
    w:addWidget(Group("nptitle", { nptrack = self.info, xofy = nil }))
    w:addWidget(Group("npartwork", { artwork = self.icon }))
    w:addListener(EVENT_WINDOW_POP, function() self:close() end)
    self.window = w
end
function NowPlaying:_setArtwork(path, key)
    if key ~= self.key then os.remove(path); return end
    local ok, surface = pcall(loadImage, path); os.remove(path)
    if not ok or not surface then return end
    local width, height = surface:getSize(); local scale = math.min(143 / width, 143 / height)
    if scale < 1 then local scaled = surface:zoom(scale, scale, 1); surface:release(); surface = scaled end
    if surface then self.surface = surface; self.icon:setValue(surface); self.icon:reLayout(); self.icon:reDraw() end
end
function NowPlaying:update()
    local d = self.applet.service:statusData(); local state = d.playback_state or "not_playing"
    local title, artist, album = d.title or "", d.artist or "", d.album or ""
    local key = d.track_id or (artist .. "\0" .. title)
    if key ~= self.key then
        self.key = key; self.artwork:cancel()
        self.info:setValue((title ~= "" and title or "Nothing playing") .. "\n" .. artist .. "\n" .. album .. "\n" .. (state == "playing" and "Playing" or state == "paused" and "Paused" or "Not playing"))
        if title ~= "" and artist ~= "" then self.artwork:lookup(title, artist, d.artwork_url, key) end
    else
        self.info:setValue((title ~= "" and title or "Nothing playing") .. "\n" .. artist .. "\n" .. album .. "\n" .. (state == "playing" and "Playing" or state == "paused" and "Paused" or "Not playing"))
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
