# SBSpotifyConnect

Clean Spotify Connect applet project for the Logitech Squeezebox Radio (`baby`).

This repository starts with a framework-only release (`0.1.0`). It packages a
Jive applet, an owned local Ogg bridge, and an ARM test helper. Spotify
authentication and librespot integration are deliberately deferred.

The production path is compressed audio throughout:

`Spotify → stream-only librespot → Vorbis passthrough → bounded HTTP Ogg bridge → stock SqueezePlay/Tremor → jive_alsa → speaker`

The Radio is ARM926EJ-S/ARMv5TEJ, soft-float, Linux 2.6.26. PCM decoding in
librespot, direct ALSA, shared memory, effects FIFOs, and stock Playback patches
are excluded because the research repository proved they are the wrong boundary.

See [docs/architecture.md](docs/architecture.md), [docs/development.md](docs/development.md),
and [docs/packaging.md](docs/packaging.md).
