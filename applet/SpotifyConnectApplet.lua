local oo = require("loop.simple")
local Applet = require("jive.Applet")
local Framework = require("jive.ui.Framework")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Window = require("jive.ui.Window")
local SpotifyService = require("applets.SpotifyConnect.SpotifyService")

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self)
    self.service = SpotifyService(self)
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
