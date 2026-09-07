local oo = require("loop.simple")
local AppletMeta = require("jive.AppletMeta")
local Window = require("jive.ui.Window")
local SimpleMenu = require("jive.ui.SimpleMenu")
local Popup = require("jive.ui.Popup")
local Label = require("jive.ui.Label")
local Timer = require("jive.ui.Timer")
local Player = require("jive.slim.Player")
local decode = require("squeezeplay.decode")
local Stream = require("squeezeplay.stream")
local jiveMain = jiveMain
local pidfile = "/tmp/spotify-connect.pid"
local logfile = "/tmp/spotify-connect.log"
local playback
local serviceRunning

local function notify(text)
    local popup = Popup("popup", text)
    popup:addWidget(Label("text", text))
    popup:show()
    Timer(1800, function() popup:hide() end, true):start()
end

local function startPlayback()
    local player = Player:getLocalPlayer() or Player:getCurrentPlayer()
    local pb = player and player.playback
    if not pb then notify("Spotify Connect: no player"); return end
    playback = pb
    pb:stopInternal()
    if player.incrementSequenceNumber then player:incrementSequenceNumber() end
    pb.flags = 0
    pb.mode = 'o'
    pb.header = "GET /test.ogg HTTP/1.0\nHost: 127.0.0.1\nAccept: audio/ogg,audio/vorbis,*/*\nConnection: close\n\n"
    pb.autostart = '1'
    pb.threshold = 0
    pb.sentResume = false
    pb.sentResumeDecoder = false
    pb.sentDecoderFullEvent = false
    pb.sentOutputUnderrunEvent = false
    pb.sentAudioUnderrunEvent = false
    pb.isLooping = false
    pb.ignoreStream = false
    pb.decodeThreshold = 2048
    Stream:icyMetaInterval(0)
    decode:start(string.byte('o'), 0, 0, 0, 0, 0, 0, 0, 0, 0)
    pb:_streamConnect("127.0.0.1", 17880)
end

local function stopPlayback()
    if playback then playback:stopInternal(); playback = nil end
end

local function startPlaybackAfterBind()
    Timer(1000, function()
        if serviceRunning() then startPlayback() end
    end, true):start()
end

local function startService()
    os.execute("if test -s " .. pidfile .. " && kill -0 `cat " .. pidfile .. "` 2>/dev/null; then exit 0; fi; /usr/share/jive/applets/SpotifyConnect/ogg-http-bridge --source http://live.chbnradio.org:8000/chbn.ogg >" .. logfile .. " 2>&1 & echo $! >" .. pidfile)
end

local function stopService()
    os.execute("if test -s " .. pidfile .. "; then kill -TERM `cat " .. pidfile .. "` 2>/dev/null; rm -f " .. pidfile .. "; fi")
end

serviceRunning = function()
    return os.execute("test -s " .. pidfile .. " && kill -0 `cat " .. pidfile .. "` 2>/dev/null") == 0
end

module(...)
oo.class(_M, AppletMeta)

function jiveVersion() return 1, 1 end

function registerApplet(self)
    jiveMain:addItem(self:menuItem("spotifyConnect", "home", "SPOTIFY_CONNECT", function()
        local window = Window("text_list", self:string("SPOTIFY_CONNECT"))
        local menu = SimpleMenu("menu")
        window:addWidget(menu)
        menu:addItem({text = self:string("START_TEST_STREAM"), callback = function()
            startService()
            startPlaybackAfterBind()
            notify("Spotify Connect: started")
        end})
        menu:addItem({text = self:string("STOP"), callback = function()
            stopPlayback()
            stopService()
            notify("Spotify Connect: stopped")
        end})
        menu:addItem({text = self:string("STATUS"), callback = function()
            local text = serviceRunning() and "Spotify Connect: running" or "Spotify Connect: stopped"
            log:info("SpotifyConnect status=", text)
            notify(text)
        end})
        menu:addItem({text = self:string("RESTART_SERVICE"), callback = function()
            stopPlayback()
            stopService()
            startService()
            startPlaybackAfterBind()
            notify("Spotify Connect: restarted")
        end})
        window:show()
    end, 1))
end

function defaultSettings() return {} end
function upgradeSettings(_, settings) return settings or {} end

function configureApplet() end
