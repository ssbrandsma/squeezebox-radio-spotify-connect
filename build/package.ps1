$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/build-applet.ps1"
$stage = Join-Path $PSScriptRoot 'out/applet'
$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<extensions><extension name="SpotifyConnect" version="0.2.0" target="baby"><file>SpotifyConnect/</file></extension></extensions>
'@
Set-Content (Join-Path $dist 'extensions.xml') $xml -NoNewline
$zip = Join-Path $dist 'SpotifyConnect-0.2.0.zip'
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $stage 'SpotifyConnect') -DestinationPath $zip
$sha1 = (Get-FileHash (Join-Path $dist 'extensions.xml') -Algorithm SHA1).Hash
Set-Content (Join-Path $dist 'extensions.xml.sha1') $sha1
Write-Host "Package: $zip"
Write-Host "ZIP size: $((Get-Item $zip).Length) bytes"
Write-Host "extensions.xml SHA1: $sha1"
