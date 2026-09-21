# Spotify control responsiveness

## Previous critical path

The applet polled the complete status every 500 ms. Each poll launched a shell
pipeline to inspect the process table and then read status, metadata, playback
state, and volume files. A song switch was detected only after librespot emitted
the full `track_changed` metadata event. On the Radio this happened several
seconds after `loading`, so the old decoder could continue for about three
seconds and the replacement HTTP stream was commonly opened about five seconds
later.

Volume changes used the same heavy poll. The onevent handler also executed a
shell wrapper, and the metadata helper synchronously flushed full track metadata
to flash. Since librespot serializes these event handlers, that flush could
delay a following volume event.

## Current critical path

The metadata helper now writes a small loading marker as soon as librespot emits
`loading`. The applet polls only the loading, stream-ready, and volume marker
files at 100 ms and stops the old decoder immediately.

The Ogg bridge writes an atomic stream marker after it has cached all three
Vorbis headers for a new logical stream. The applet opens the local HTTP stream
at that point, so it no longer waits for full track metadata and it cannot open
too early against the previous Ogg headers.

The high-frequency path no longer invokes a shell, scans processes, or parses
JSON. Normal status display also reads the supervisor status file directly.
librespot invokes the native metadata helper directly, and metadata replacement
remains atomic without forcing a synchronous flash flush.

Spotify volume changes use the same 100 ms event poll, update decoder gain, and
show a standard SqueezePlay-style volume popup. Now Playing uses the Radio
skin's smaller `npartistalbum` font and displays artist, song title, and album in
that order.

## Expected limits

The applet can now add at most about 100 ms after it sees a native marker.
Network fetch, Spotify command delivery, librespot track loading, and decoder
startup remain outside that bound. Real end-to-end timing must be measured on
the target Radio because its ARM CPU, flash, and network connection dominate
those stages.
