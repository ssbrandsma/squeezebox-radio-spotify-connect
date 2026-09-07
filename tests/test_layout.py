from pathlib import Path

ROOT = Path(__file__).parents[1]

def test_required_sources_exist():
    for name in ("SpotifyConnectMeta.lua", "SpotifyConnectApplet.lua", "SpotifyService.lua", "SpotifyPlayback.lua", "strings.txt"):
        assert (ROOT / "applet" / name).is_file()

def test_no_research_tree_is_embedded():
    assert not (ROOT / "evidence").exists()
    assert not (ROOT / "phase1").exists()
