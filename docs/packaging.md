# Packaging

`build/package.ps1` creates `dist/SpotifyConnect-0.1.0.zip` from the applet and
native files, and writes the SHA1 of `dist/extensions.xml`. The archive contains
only applet Lua, strings, native test binaries, and metadata. Credentials,
research evidence, PC artifacts, and source checkouts are excluded.

Applet-owned executables install under
`/usr/share/jive/applets/SpotifyConnect/`. The applet applies `chmod 755`
idempotently to its own files; it never writes `/usr/bin`, `/usr/local/bin`, or
`/etc/init.d`.
