#!/usr/bin/env bash
set -euo pipefail
source "$HOME/.cargo/env"
ROOT=/mnt/c/Projects/SBSpotifyConnect
OUT="$ROOT/build/out"
mkdir -p "$OUT"
arm-linux-gnueabi-gcc -c -Os -march=armv5te -mfloat-abi=soft -marm "$ROOT/native/linux26-compat/linux26-compat.c" -o /tmp/sbspotify-linux26-compat.o
rustc --edition 2021 -C opt-level=z -C strip=symbols "$ROOT/native/bridge/bridge.rs" -o "$OUT/ogg-http-bridge-host"
rustc --edition 2021 -C opt-level=z -C strip=symbols "$ROOT/native/supervisor/main.rs" -o "$OUT/spotify-supervisor-host"
rustc --edition 2021 -C opt-level=z -C strip=symbols "$ROOT/native/metadata/main.rs" -o "$OUT/spotify-metadata-host"
rustc --edition 2021 --target armv5te-unknown-linux-musleabi -C linker=arm-linux-gnueabi-gcc -C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie -C opt-level=z -C strip=symbols -C link-arg=/tmp/sbspotify-linux26-compat.o -C link-arg=-Wl,--wrap=epoll_create1,--wrap=eventfd,--wrap=socket,--wrap=accept4 "$ROOT/native/bridge/bridge.rs" -o "$OUT/ogg-http-bridge"
rustc --edition 2021 --target armv5te-unknown-linux-musleabi -C linker=arm-linux-gnueabi-gcc -C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie -C opt-level=z -C strip=symbols "$ROOT/native/supervisor/main.rs" -o "$OUT/spotify-supervisor"
rustc --edition 2021 --target armv5te-unknown-linux-musleabi -C linker=arm-linux-gnueabi-gcc -C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie -C opt-level=z -C strip=symbols "$ROOT/native/metadata/main.rs" -o "$OUT/spotify-metadata"
cd "$ROOT/native/librespot"
export CARGO_TARGET_DIR=/tmp/sbspotify-librespot-target
export CARGO_TARGET_ARMV5TE_UNKNOWN_LINUX_MUSLEABI_LINKER=arm-linux-gnueabi-gcc
export CC_armv5te_unknown_linux_musleabi=arm-linux-gnueabi-gcc
export CFLAGS_armv5te_unknown_linux_musleabi='-march=armv5te -mfloat-abi=soft -marm'
export RUSTFLAGS='-C target-cpu=arm926ej-s -C target-feature=+crt-static -C link-arg=-no-pie'
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z
export CARGO_PROFILE_RELEASE_LTO=thin
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_STRIP=symbols
cargo rustc --locked --release --bin librespot --target armv5te-unknown-linux-musleabi --no-default-features --features rustls-tls-webpki-roots,with-libmdns,passthrough-decoder,streaming-only -- -C link-arg=/tmp/sbspotify-linux26-compat.o -C link-arg=-Wl,--wrap=epoll_create1,--wrap=eventfd,--wrap=socket,--wrap=accept4
cp /tmp/sbspotify-librespot-target/armv5te-unknown-linux-musleabi/release/librespot "$OUT/librespot"
