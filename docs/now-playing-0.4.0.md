# Spotify Connect Now Playing

## Implementation report

The pinned librespot fork already receives `TrackChanged`, `Playing`,
`Paused`, and `Stopped` events. `TrackChanged` includes the Spotify track ID,
title, artist list, album, duration, and cover URL. The service now passes
librespot's existing `--onevent` option to `spotify-metadata`, a small static
ARM helper. Track metadata is written atomically to `metadata.json`; transient
playback state is written to `metadata.json.state`. The existing connection
status file and audio path are unchanged.

Lua polls the merged service data once per second while the Now Playing window
is open. Track changes use the track ID, falling back to artist and title. The
screen updates text immediately and starts one artwork lookup. Artwork first
uses the direct Spotify cover URL, then the LMS Community API over HTTP with
URL-encoded title and artist and `Connection: close`. Downloads are bounded to
512 KiB, decoded from memory, scaled to the 143-pixel artwork area, and the
temporary file is removed. Each request carries the track key and cannot
replace a newer track's artwork.

## Physical test checklist

1. Boot the Radio and start Spotify Connect.
2. Select a Spotify track and open **Spotify Connect → Now Playing**.
3. Check title, artist, album, and Playing state.
4. Change tracks and verify text updates immediately and artwork changes once.
5. Pause and resume; metadata should remain while state changes.
6. Skip through at least ten tracks and check for stale artwork or memory growth.
7. Test accented, apostrophe, ampersand, slash, long, and non-English titles.
8. Test a track without artwork and confirm playback continues with the fallback.
9. Close and reopen Now Playing; confirm no duplicate timers or requests.
10. Run at least 30 minutes of playback while monitoring audio stability.

Build/static checks do not replace this physical validation.
