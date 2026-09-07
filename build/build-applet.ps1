$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Out = Join-Path $PSScriptRoot 'out/applet/SpotifyConnect'
New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item "$Root/applet/*.lua","$Root/applet/strings.txt" $Out -Force
if (Test-Path "$PSScriptRoot/out/ogg-http-bridge-arm") { Copy-Item "$PSScriptRoot/out/ogg-http-bridge-arm" "$Out/ogg-http-bridge" -Force }
if (Test-Path "$PSScriptRoot/out/ogg-test-source-arm") { Copy-Item "$PSScriptRoot/out/ogg-test-source-arm" "$Out/ogg-test-source" -Force }
Write-Host "Applet staged in $Out"
