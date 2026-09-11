"""Run the real service under Lua 5.1's isolated module environment.

Requires lupa (python -m pip install lupa).
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime


def test_status_reader_with_volume_and_track_changes():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        files = {}
        package.loaded["loop.simple"] = { class = function() end }
        package.loaded["jive.ui.Timer"] = function() end
        package.loaded["os"] = { execute = function() return 0 end }
        package.loaded["io"] = { open = function(path)
            local value = files[path]
            if not value then return nil end
            return { read = function() return value end, close = function() end }
        end }
        decoded = { title = 'Title with "quotes"', artist = 'Artist',
                    album = 'Album', track_id = 'first', playback_state = 'playing' }
        package.loaded["json"] = { decode = function() return decoded end }
    ''')
    path = Path(__file__).parents[1] / "applet/SpotifyService.lua"
    service = lua.execute(path.read_text(), "service_test")
    files = lua.globals().files
    base = "/etc/squeezeplay/userpath/SpotifyConnect/"
    files[base + "metadata.json"] = "{}"
    files[base + "metadata.json.state"] = "playing\n"
    files[base + "metadata.json.volume"] = "38911"
    for state, track, volume in [('playing', 'first', 38911), ('paused', 'second', 0), ('stopped', 'third', 65535)]:
        files[base + "metadata.json.state"] = state
        files[base + "metadata.json.volume"] = str(volume)
        lua.globals().decoded.track_id = track
        data = service.statusData(service)
        assert data.playback_state == state
        assert data.track_id == track
        assert data.volume == volume
        assert data.title == 'Title with "quotes"'


def test_watcher_switches_tracks_and_applies_u16_volume():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        timers, volumes = {}, {}
        data = {track_id = 'first', volume = 32768}
        starts, stops = 0, 0
        package.loaded['loop.simple'] = { class = function() end }
        package.loaded['jive.Applet'] = {}
        package.loaded['jive.ui.Framework'] = { constants = function() end }
        package.loaded['jive.ui.SimpleMenu'] = {}
        package.loaded['jive.ui.Window'] = {}
        package.loaded['jive.utils.log'] = {logger = function() return {info=function() end} end}
        package.loaded['jive.ui.Timer'] = function(ms, callback, once)
            local t = {ms=ms, callback=callback, once=once, start=function() end}
            table.insert(timers, t); return t
        end
        package.loaded['applets.SpotifyConnect.SpotifyService'] = function()
            return {init=function() end, statusData=function() return data end}
        end
        package.loaded['applets.SpotifyConnect.SpotifyPlayback'] = function()
            return {init=function() end, stop=function() stops=stops+1 end,
                    start=function() starts=starts+1 end}
        end
        package.loaded['applets.SpotifyConnect.SpotifyNowPlaying'] = {new=function() return {} end}
        package.loaded['applets.SpotifyConnect.SpotifyConnectState'] = {}
        package.loaded['jive.slim.Player'] = {getLocalPlayer=function()
            return {volumeLocal=function(_, v) table.insert(volumes, v) end}
        end}
    ''')
    path = Path(__file__).parents[1] / 'applet/SpotifyConnectApplet.lua'
    applet = lua.execute(path.read_text(), 'applet_test')
    applet.init(applet)
    watcher = applet._trackWatcher
    watcher.callback()
    assert lua.globals().volumes[1] == 50
    lua.globals().data.track_id = 'second'
    lua.globals().data.volume = 0
    watcher.callback()
    assert lua.globals().stops == 1
    lua.globals().timers[2].callback()
    assert lua.globals().starts == 1
    assert lua.globals().volumes[2] == 0
    lua.globals().data.volume = 100
    watcher.callback()
    assert lua.globals().volumes[3] == 0  # u16 value, never interpreted as 100%
