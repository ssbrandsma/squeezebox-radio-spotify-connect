local os, pcall, tostring, type, setmetatable = os, pcall, tostring, type, setmetatable
local io = require("io")
local string = require("string")
local Timer = require("jive.ui.Timer")
local RequestHttp = require("jive.net.RequestHttp")
local Resolver = require("applets.StandaloneRadio.Resolver")
local SocketHttp = require("jive.net.SocketHttp")
local okJson, json = pcall(require, "json")
if not okJson then json = nil end
local jnt = jnt
module(...)

local Artwork = {}; Artwork.__index = Artwork
local API_HOST, API_PORT = "api.lms-community.org", 80
local function enc(v) return string.gsub(tostring(v or ""), "[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end) end
local function quote(v) return "'" .. tostring(v):gsub("'", "'\\''") .. "'" end
local function validUrl(v)
    v = tostring(v or ""):gsub("^https://", "http://")
    return v:match("^http://[%w%.%-]+[:%d]*/?.*") and v or nil
end
function new(log, callback) return setmetatable({ log = log, callback = callback, resolver = Resolver.new({ log = log }), generation = 0, key = nil, temp = nil }, Artwork) end
function Artwork:cancel() self.generation = self.generation + 1; self.key = nil; if self.temp then os.remove(self.temp); self.temp = nil end end
function Artwork:lookup(title, artist, direct, key)
    if not title or title == "" or not artist or artist == "" or key == self.key then return end
    self.generation = self.generation + 1; local generation = self.generation; self.key = key
    if self.temp then os.remove(self.temp); self.temp = nil end
    self.log:info("SpotifyConnect: artwork lookup ", title, " / ", artist)
    local function fetchPicture(picture)
        if generation ~= self.generation or key ~= self.key then return end
        if picture then self:_download(picture, key, generation) end
    end
    if validUrl(direct) then fetchPicture(validUrl(direct)); return end
    self.resolver:resolve(API_HOST, function(ip)
        if generation ~= self.generation or key ~= self.key or not ip or not json then return end
        local request = RequestHttp(function(body, err)
            if generation ~= self.generation or key ~= self.key or err or not body then return end
            local ok, response = pcall(function() return json.decode(body) end)
            local picture = ok and type(response) == "table" and validUrl(response.picture)
            fetchPicture(picture)
        end, "GET", "/music/track/" .. enc(title) .. "/" .. enc(artist) .. "/cover", { headers = { Host = API_HOST, Accept = "application/json", ["Connection"] = "close" } })
        self.http = SocketHttp(jnt, ip, API_PORT, "SpotifyConnectArtwork"); self.http:fetch(request)
    end)
end
function Artwork:_download(url, key, generation)
    local path = "/tmp/spotify-connect-artwork-" .. tostring(generation) .. ".img"; self.temp = path
    local done = path .. ".done"
    os.remove(done)
    -- Process:read uses a blocking stdio read on this firmware. The pipe
    -- produces no stdout while dd writes its file, stalling all UI timers.
    -- Launch independently and poll a completion marker without pipe reads.
    os.execute("( wget -q -T 8 -O - " .. quote(url) ..
        " | dd of=" .. quote(path) .. " bs=1024 count=513; touch " .. quote(done) ..
        " ) </dev/null >/dev/null 2>&1 &")
    local timer
    timer = Timer(200, function()
        local f = io.open(done, "r")
        if not f then return end
        f:close(); timer:stop(); os.remove(done)
        if generation ~= self.generation or key ~= self.key then os.remove(path); return end
        if self.callback then self.callback(path, key) end
    end)
    timer:start()
end
return _M
