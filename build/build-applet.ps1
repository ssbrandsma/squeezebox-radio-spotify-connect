$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Out = Join-Path $PSScriptRoot 'out/applet/SpotifyConnect'
if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Recurse -Force }
New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item "$Root/applet/*.lua","$Root/applet/strings.txt" $Out -Force
Copy-Item "$Root/applet/spotify-metadata-event" "$Out/spotify-metadata-event" -Force
Copy-Item "$Root/applet/spotify-logo.jpg" "$Out/spotify-logo.jpg" -Force
if (Test-Path "$PSScriptRoot/out/ogg-http-bridge") { Copy-Item "$PSScriptRoot/out/ogg-http-bridge" "$Out/ogg-http-bridge" -Force }
if (Test-Path "$PSScriptRoot/out/spotify-supervisor") { Copy-Item "$PSScriptRoot/out/spotify-supervisor" "$Out/spotify-supervisor" -Force }
if (Test-Path "$PSScriptRoot/out/spotify-metadata") { Copy-Item "$PSScriptRoot/out/spotify-metadata" "$Out/spotify-metadata" -Force }
if (Test-Path "$PSScriptRoot/out/librespot") { Copy-Item "$PSScriptRoot/out/librespot" "$Out/librespot" -Force }
Write-Host "Applet staged in $Out"
