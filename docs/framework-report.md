# Framework release report

## Source review and migration

Reviewed `Squeezify/PHASE6-REPORT.md`, `PHASE6-COMMANDS.md`,
`PHASE7-REPORT.md`, `PHASE7-COMMANDS.md`, `phase6/bridge.rs`,
`phase6/applet/PresetStore.lua`, `phase6/applet/Resolver.lua`,
`evidence/phase6/20260907-081712/device-before/StreamPlayer.lua`,
`build-phase6.sh`, `build-phase7.sh`, and `linux26-compat.c`.

Carried forward: baby/ARM926EJ-S/ARMv5TEJ soft-float/Linux 2.6.26, the
`armv5te-unknown-linux-musleabi` target, the Linux compatibility wrappers,
compressed Vorbis passthrough, sequential bounded fetching, loopback HTTP Ogg,
stock mode `o`, numeric loopback handling, and the fact that stock Tremor and
volume control are the viable audio path.

Deliberately excluded: PCM decode, effects FIFOs, shared memory, direct ALSA,
custom Tremor bridges, stock Playback modifications, full-track staging files,
old phase launchers, evidence, credentials, and experiment binaries.

The applet files were rewritten cleanly. The Linux compatibility source is the
minimal reviewed wrapper set required by the ARM target. No StandaloneRadio
dependency is included.

## Release contents

The project layout is the documented `applet`, `native`, `build`, `dist`,
`docs`, and `tests` structure. The ZIP contains five Lua/text files and two
ARM binaries: `ogg-http-bridge` and `ogg-test-source`.

The ARM binaries are reproducible from `build/build-native.ps1` using WSL
Ubuntu 24.04, Rust 1.98.1, `arm-linux-gnueabi-gcc`, and target
`armv5te-unknown-linux-musleabi`:

| File | SHA-256 |
|---|---|
| `ogg-http-bridge` | `CFC53F815DD1AC62EAE715A1E94834F32AB7510C1F95D8015806488CC5A5D0C1` |
| `ogg-test-source` | `7F111B510AF69E87E2CE1810B431AC6DFC37C29FB6D0762837F4561AD7D958C8` |

`dist/SpotifyConnect-0.1.0.zip` is 451,601 bytes and has SHA-256
`E1EB680B986C5CC041AA622FEF796475FE4325800CA04EE6D3DDC466E88A5D20`.
`extensions.xml` SHA1 is
`28B7F3914EC648D2906157C4852D414286F03791`.

## Test status

The layout tests pass (`2 passed`) and the host and ARM native builds pass. The
initial test URL is `http://live.chbnradio.org:8000/chbn.ogg`; a Radio-side HTTP
probe returned the expected `OggS` signature. Spotify authentication is not part
of 0.1.0.

The applet directory and ARM binaries were deployed to
`/usr/share/jive/applets/SpotifyConnect/` on `192.168.1.232`. The binaries have
execute mode `755`; Lua and string files have mode `644`. After reboot,
SqueezePlay logged `Registering: SpotifyConnect`, with no applet load errors.
The bridge was started directly, fetched CHBN, and returned an `OggS` response
through the local endpoint before cleanup.

Before real Spotify integration, exercise the menu start/stop/restart and stock
Ogg playback from the applet UI. Then integrate the already validated
stream-only librespot engine as a separately reproducible native build.
