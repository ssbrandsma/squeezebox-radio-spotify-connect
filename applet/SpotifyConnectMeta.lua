local oo = require("loop.simple")
local AppletMeta = require("jive.AppletMeta")
local Window = require("jive.ui.Window")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Icon = require("jive.ui.Icon")
local Label = require("jive.ui.Label")
local Surface = require("jive.ui.Surface")
local qrencode = require("applets.SpotifyConnect.qrencode")
local pcall = pcall
local Timer = require("jive.ui.Timer")
local jiveMain = jiveMain
local appletManager = appletManager
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local state = require("applets.SpotifyConnect.SpotifyConnectState")
module(...)
oo.class(_M, AppletMeta)
function jiveVersion() return 1, 1 end

local function makeQrSurface(value)
    local called, success, matrix = pcall(qrencode.qrcode, value)
    if not called or not success or not matrix then return nil end
    local modules, quiet, scale = #matrix, 4, 3
    local side = (modules + quiet * 2) * scale
    local surface = Surface:newRGB(side, side)
    surface:filledRectangle(0, 0, side - 1, side - 1, 0xffffffff)
    for x = 1, modules do
        for y = 1, modules do
            if matrix[x][y] and matrix[x][y] > 0 then
                local x0, y0 = (x - 1 + quiet) * scale, (y - 1 + quiet) * scale
                surface:filledRectangle(x0, y0, x0 + scale - 1, y0 + scale - 1, 0x000000ff)
            end
        end
    end
    return surface
end

local function showPairing(self, applet)
    local window = Window("text_list", "Connect Spotify")
    local label = Label("text", "Starting...\n")
    local qr = Icon("icon")
    local qrUrl
    window:addWidget(qr); window:addWidget(label); window:show()
    local timer
    timer = Timer(1000, function()
        local d = applet.service:statusData()
        if d.state == "pairing" and d.url and d.url ~= qrUrl then
            qrUrl = d.url
            local surface = makeQrSurface(d.url)
            if surface then qr:setValue(surface) end
        end
        label:setValue(d.state == "pairing" and ("Scan QR or open this address:\n" .. (d.url or "waiting") .. "\n\nWaiting for approval...") or (d.state == "connected" and "Connected\n\nSelect Squeezebox Radio in Spotify." or (d.state == "error" and ("Connection failed\n\n" .. (d.message or "Unknown error") .. "\n\nPress Back and try Connect again.") or "Waiting for Spotify...")))
        if d.state == "connected" then
            local settings = applet._settings; settings.enabled = true
            self:storeSettings()
            Timer(1200, function() applet.playback:start("127.0.0.1", 17880, "/spotify.ogg") end, true):start()
            timer:stop()
        elseif d.state == "error" then timer:stop() end
    end); timer:start()
    return window
end

function registerApplet(self)
    -- This applet owns a background service, so instantiate it during boot.
    -- Merely registering the menu leaves saved enabled accounts offline until
    -- the user opens the menu for the first time.
    appletManager:loadApplet("SpotifyConnect")
    jiveMain:addItem(self:menuItem("spotifyConnect", "home", "SPOTIFY_CONNECT", function()
        local applet = state.applet
        local service = state.service
        if not applet or not service then return end
        local window = Window("text_list", "Spotify Connect")
        local menu = SimpleMenu("menu"); window:addWidget(menu)
        local state = service:status()
        menu:addItem({ text = "Now Playing", callback = function() applet.nowPlaying:show() end })
        if state == "not_connected" or state == "error" then
            menu:addItem({ text = "Connect", callback = function() service:start(true); showPairing(self, applet) end })
        end
        local statusItem = { text = "Status: " .. state, callback = function() showPairing(self, applet) end }
        menu:addItem(statusItem)
        local statusTimer = Timer(1000, function() menu:setText(statusItem, "Status: " .. service:status()) end)
        statusTimer:start()
        window:addListener(EVENT_WINDOW_POP, function() statusTimer:stop() end)
        menu:addItem({ text = "Device name: " .. ((applet._settings and applet._settings.deviceName) or "Squeezebox Radio") })
        menu:addItem({ text = "Restart service", callback = function() service:restart() end })
        local disconnectItem
        disconnectItem = { text = "Disconnect account", callback = function()
            service:disconnect()
            local settings = applet._settings; settings.enabled = false; self:storeSettings()
            menu:setText(disconnectItem, "Disconnected")
            menu:setText(statusItem, "Status: not_connected")
            Timer(2500, function() menu:setText(disconnectItem, "Disconnect account") end, true):start()
        end }
        menu:addItem(disconnectItem)
        window:show()
    end, 1))
end
function defaultSettings() return { enabled = false, deviceName = "Squeezebox Radio" } end
function upgradeSettings(_, settings) settings = settings or {}; if settings.deviceName == nil then settings.deviceName = "Squeezebox Radio" end; if settings.enabled == nil then settings.enabled = false end; return settings end
function configureApplet() end
