local oo = require("loop.simple")
local AppletMeta = require("jive.AppletMeta")
local Window = require("jive.ui.Window")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Label = require("jive.ui.Label")
local Timer = require("jive.ui.Timer")
local jiveMain = jiveMain
module(...)
oo.class(_M, AppletMeta)
function jiveVersion() return 1, 1 end

local function showPairing(self, applet)
    local window = Window("text_list", "Connect Spotify")
    local label = Label("text", "Starting...\n")
    window:addWidget(label); window:show()
    local timer
    timer = Timer(1000, function()
        local d = applet.service:statusData()
        local text = d.state == "pairing" and ("Open this address on your phone:\nspotify.com/pair\n\nCode/link:\n" .. (d.url or "waiting") .. "\n\nWaiting for approval...") or (d.state == "connected" and "Connected\n\nSelect Squeezebox Radio in Spotify." or (d.state == "error" and "Failed:\n" .. (d.message or "unknown error") or "Waiting for Spotify..."))
        label:setValue(text)
        if d.state == "connected" then
            local settings = applet:getSettings(); settings.enabled = true
            applet:storeSettings()
            Timer(1200, function() applet.playback:start("127.0.0.1", 17880, "/spotify.ogg") end, true):start()
            timer:stop()
        elseif d.state == "error" then timer:stop() end
    end); timer:start()
    return window
end

function registerApplet(self)
    jiveMain:addItem(self:menuItem("spotifyConnect", "home", "SPOTIFY_CONNECT", function(applet)
        local window = Window("text_list", "Spotify Connect")
        local menu = SimpleMenu("menu"); window:addWidget(menu)
        local state = applet.service:status()
        if state == "not_connected" or state == "error" then
            menu:addItem({ text = "Connect Spotify", callback = function() applet.service:start(true); showPairing(self, applet) end })
        end
        menu:addItem({ text = "Status: " .. state, callback = function() showPairing(self, applet) end })
        menu:addItem({ text = "Device name: " .. (applet:getSettings().deviceName or "Squeezebox Radio") })
        if applet.service:isRunning() then
            menu:addItem({ text = "Restart service", callback = function() applet.service:restart() end })
            menu:addItem({ text = "Disconnect account", callback = function() applet.service:disconnect(); local settings = applet:getSettings(); settings.enabled = false; applet:storeSettings() end })
        end
        window:show()
    end, 1))
end
function defaultSettings() return { enabled = false, deviceName = "Squeezebox Radio" } end
function upgradeSettings(_, settings) settings = settings or {}; if settings.deviceName == nil then settings.deviceName = "Squeezebox Radio" end; if settings.enabled == nil then settings.enabled = false end; return settings end
function configureApplet() end
