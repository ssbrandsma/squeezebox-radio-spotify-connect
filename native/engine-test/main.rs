//! Lifecycle-only native helper for framework packaging tests.
//! The real Spotify engine will replace this binary in a later release.
fn main() {
    eprintln!("SpotifyConnect engine-test: no Spotify authentication configured");
    eprintln!("Set TEST_OGG_URL for the external stream test; exiting cleanly");
}
