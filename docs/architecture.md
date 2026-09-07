# Architecture

The Jive applet owns the user interface and child-process lifecycle. It does
not decode Spotify audio and does not modify the stock player.

The eventual native engine handles Spotify authentication and bounded,
sequential encrypted-track transport. Its output is compressed Vorbis
passthrough. The local bridge exposes one loopback HTTP/1.0 endpoint at
`127.0.0.1:17880`, with `Content-Type: audio/ogg`, no TLS, no chunked encoding,
and bounded header buffering.

`SpotifyPlayback.lua` selects stock decoder mode `o` and invokes the existing
SqueezePlay stream connection. Stock Tremor performs fixed-point Vorbis decode;
the normal floating-point librespot decoder is intentionally disabled for this
CPU. Stream-only mode is intentional: it requests sequential 64 KiB ranges,
uses a bounded queue, does not create a full-track file or cache, and does not
support seek. A nonzero resume request restarts at offset zero.

The bridge and applet are independent of StandaloneRadio. Numeric IPv4 loopback
addresses bypass DNS because the Radio's resolver is unreliable for them.
