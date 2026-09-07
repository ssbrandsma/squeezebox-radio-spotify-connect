$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $Out | Out-Null
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl -d Ubuntu-24.04 -- bash -lc "rustc --edition 2021 -C opt-level=z -C strip=symbols /mnt/c/Projects/SBSpotifyConnect/native/bridge/bridge.rs -o /mnt/c/Projects/SBSpotifyConnect/build/out/ogg-http-bridge-host && rustc --edition 2021 -C opt-level=z -C strip=symbols /mnt/c/Projects/SBSpotifyConnect/native/engine-test/main.rs -o /mnt/c/Projects/SBSpotifyConnect/build/out/ogg-test-source-host && arm-linux-gnueabi-gcc -c -Os -march=armv5te -mfloat-abi=soft -marm /mnt/c/Projects/SBSpotifyConnect/native/linux26-compat/linux26-compat.c -o /tmp/sbspotify-linux26-compat.o && rustc --edition 2021 --target armv5te-unknown-linux-musleabi -C linker=arm-linux-gnueabi-gcc -C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie -C opt-level=z -C strip=symbols -C link-arg=/tmp/sbspotify-linux26-compat.o -C link-arg=-Wl,--wrap=epoll_create1,--wrap=eventfd,--wrap=socket,--wrap=accept4 /mnt/c/Projects/SBSpotifyConnect/native/bridge/bridge.rs -o /mnt/c/Projects/SBSpotifyConnect/build/out/ogg-http-bridge-arm && rustc --edition 2021 --target armv5te-unknown-linux-musleabi -C linker=arm-linux-gnueabi-gcc -C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie -C opt-level=z -C strip=symbols /mnt/c/Projects/SBSpotifyConnect/native/engine-test/main.rs -o /mnt/c/Projects/SBSpotifyConnect/build/out/ogg-test-source-arm"
} else {
    throw 'WSL Ubuntu-24.04 is required for reproducible native builds'
}
Write-Host "Host binaries built in $Out"
if (Test-Path "$Out/ogg-http-bridge-arm") { Write-Host "ARM bridge built for armv5te-unknown-linux-musleabi" }
