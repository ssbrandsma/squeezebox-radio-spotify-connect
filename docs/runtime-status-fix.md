# Shared status-reader failure

The live Radio log repeatedly reported `SpotifyService.lua:65: attempt to call global 'tonumber' (a nil value)`. Lua 5.1's `module(...)` environment does not inherit globals. Reading the volume file therefore raised an error before `statusData()` could return, interrupting both the Now Playing timer and the track/volume watcher.

The fix imports `tonumber` before entering the module. The JSON decoder now calls `pcall` directly: placing that call behind `and` discarded the decoded second return value. The screen again displays the actual event state rather than inferring playback from a title. Volume uses the build's verified `u16` event scale (0–65535); low raw values are not interpreted as percentages. Redundant gain calls were removed. The fallback image is no longer explicitly freed while a UI widget can still reference it.

Validation: `python -m pip install lupa pytest`, then `python -m pytest -q`. The tests run the real Lua files under Lua 5.1 with isolated module environments, file/API fixtures, and timer callbacks. They cover track changes, state changes, quoted titles, zero volume, and volume scaling. Four tests passed. The three deployed Lua files were checked against local MD5 hashes.

SqueezePlay restart triggered a watchdog reboot; the Radio subsequently returned online. Audible switching latency, physical volume changes, and the display require the user's live test. No new release tag was created or moved for this fix.

After reboot, live logs confirmed remote volumes applied at 52% and 61%, track-change reconnect callbacks, and updated artwork lookups without the status-reader exception. A second delay remained: artwork fetching used `Process:read` on a wget/dd pipeline that produced no stdout while downloading. Firmware `Process.lua` uses a blocking stdio read in its task. Artwork now launches the bounded download in the background with an eight-second wget timeout and polls a completion marker; no pipe read runs in the UI thread. The deployed artwork Lua hash was verified as well. A normal reboot was requested to load that follow-up.
