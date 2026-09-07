$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Out = Join-Path $PSScriptRoot 'out/applet/SpotifyConnect'
New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item "$Root/applet/*.lua","$Root/applet/strings.txt" $Out -Force
if (Test-Path "$PSScriptRoot/out/ogg-http-bridge") { Copy-Item "$PSScriptRoot/out/ogg-http-bridge" "$Out/ogg-http-bridge" -Force }
if (Test-Path "$PSScriptRoot/out/spotify-supervisor") { Copy-Item "$PSScriptRoot/out/spotify-supervisor" "$Out/spotify-supervisor" -Force }
if (Test-Path "$PSScriptRoot/out/librespot") { Copy-Item "$PSScriptRoot/out/librespot" "$Out/librespot" -Force }
Write-Host "Applet staged in $Out"
