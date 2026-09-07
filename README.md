# SBSpotifyConnect

Clean Spotify Connect applet project for the Logitech Squeezebox Radio (`baby`).

The `0.2.0` production release packages a Jive applet, the pinned Phase 7
streaming-only librespot engine, an owned local Ogg bridge, and a status
supervisor. First use shows Spotify's device-authorization pairing URL; the
supported librespot credential cache then allows automatic reconnect after
restart and reboot.

The production path is compressed audio throughout:

`Spotify → stream-only librespot → Vorbis passthrough → bounded HTTP Ogg bridge → stock SqueezePlay/Tremor → jive_alsa → speaker`

The Radio is ARM926EJ-S/ARMv5TEJ, soft-float, Linux 2.6.26. PCM decoding in
librespot, direct ALSA, shared memory, effects FIFOs, and stock Playback patches
are excluded because the research repository proved they are the wrong boundary.

See [docs/architecture.md](docs/architecture.md), [docs/development.md](docs/development.md),
and [docs/packaging.md](docs/packaging.md).
