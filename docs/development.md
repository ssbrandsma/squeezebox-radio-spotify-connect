# Development

The research source and evidence remain in `C:\Projects\Squeezify`; this tree
contains only production-facing source. Target hardware is the Logitech
Squeezebox Radio (`baby`) using ARMv5TEJ soft-float and Linux 2.6.26.

Build the host bridge with Rust, then cross-build the ARM helper with the
`armv5te-unknown-linux-musleabi` target and the Linux 2.6 compatibility shim.
The initial framework has no Spotify credentials and no account pairing.

The initial framework test source is `http://live.chbnradio.org:8000/chbn.ogg`.
The bridge also accepts `--source URL` or `TEST_OGG_URL` for later test streams.
