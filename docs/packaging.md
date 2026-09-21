# Packaging

`build/package.ps1` reads `VERSION`, creates the matching
`dist/SpotifyConnect-<version>.zip`, and generates Applet Installer repository
metadata in `dist/extensions.xml`. The XML contains the release URL and SHA-1
of the ZIP; `dist/extensions.xml.sha1` contains the SHA-1 of the XML itself.
The archive contains only the applet Lua, strings, artwork, event hook, and
four ARM runtime executables. Credentials, research evidence, test binaries,
PC artifacts, and source checkouts are excluded.

By default, package URLs point to
`http://49.12.198.91/sbspotifyconnect`. Publish both `extensions.xml` and the
versioned ZIP in the server's `sbspotifyconnect` web directory so the stock
Radio can download them without TLS. Pass `-BaseUrl` when publishing through a
different static web directory.

Add `http://49.12.198.91/sbspotifyconnect/extensions.xml` to LMS under **Additional
Repositories**. The two public files for version 0.5.0 are:

```text
http://49.12.198.91/sbspotifyconnect/extensions.xml
http://49.12.198.91/sbspotifyconnect/SpotifyConnect-0.5.0.zip
```

Applet-owned executables install under
`/usr/share/jive/applets/SpotifyConnect/`. The applet applies `chmod 755`
idempotently to its own files; it never writes `/usr/bin`, `/usr/local/bin`, or
`/etc/init.d`.
