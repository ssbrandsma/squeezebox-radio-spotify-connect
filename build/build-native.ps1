$ErrorActionPreference = 'Stop'
$Out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $Out | Out-Null
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { throw 'WSL Ubuntu-24.04 is required for reproducible native builds' }
wsl -d Ubuntu-24.04 -- bash /mnt/c/Projects/SBSpotifyConnect/build/build-native.sh
if ($LASTEXITCODE -ne 0) { throw "Native build failed with exit code $LASTEXITCODE" }
Write-Host "Native Spotify binaries built in $Out"
