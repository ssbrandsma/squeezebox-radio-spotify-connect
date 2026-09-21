# Packaging

`build/package.ps1` reads `VERSION`, creates the matching
`dist/SpotifyConnect-<version>.zip`, and generates Applet Installer repository
metadata in `dist/extensions.xml`. The XML contains the release URL and SHA-1
of the ZIP; `dist/extensions.xml.sha1` contains the SHA-1 of the XML itself.
The archive contains only the applet Lua, strings, artwork, event hook, and
four ARM runtime executables. Credentials, research evidence, test binaries,
PC artifacts, and source checkouts are excluded.

By default, package URLs point to the matching tag under this project's GitHub
Releases. Pass `-BaseUrl` when publishing the files through another web server.

Applet-owned executables install under
`/usr/share/jive/applets/SpotifyConnect/`. The applet applies `chmod 755`
idempotently to its own files; it never writes `/usr/bin`, `/usr/local/bin`, or
`/etc/init.d`.
