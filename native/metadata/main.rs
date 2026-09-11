use std::{env, fs::{self, OpenOptions}, io::Write};

fn esc(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r")
}

fn main() -> std::io::Result<()> {
    let path = env::args().nth(1).ok_or_else(|| std::io::Error::other("metadata path required"))?;
    let event = env::var("PLAYER_EVENT").unwrap_or_default();
    let state = match event.as_str() {
        "paused" => "paused",
        "stopped" | "end_of_track" | "unavailable" => "stopped",
        "playing" | "track_changed" | "loading" => "playing",
        _ => return Ok(()),
    };
    if event != "track_changed" {
        let state_path = format!("{}.state", path);
        fs::write(state_path, state.as_bytes())?;
        return Ok(());
    }
    let track_id = env::var("TRACK_ID").unwrap_or_default();
    let title = env::var("NAME").unwrap_or_default();
    let artist = env::var("ARTISTS").unwrap_or_default().replace('\n', ", ");
    let album = env::var("ALBUM").unwrap_or_default();
    let duration = env::var("DURATION_MS").unwrap_or_default();
    let covers = env::var("COVERS").unwrap_or_default();
    let artwork = covers.lines().next().unwrap_or("");
    let json = format!(r#"{{"playback_state":"{}","track_id":"{}","title":"{}","artist":"{}","album":"{}","duration_ms":"{}","artwork_url":"{}"}}
"#, state, esc(&track_id), esc(&title), esc(&artist), esc(&album), esc(&duration), esc(artwork));
    if let Some(parent) = std::path::Path::new(&path).parent() { let _ = fs::create_dir_all(parent); }
    let tmp = format!("{}.tmp", path);
    let mut f = OpenOptions::new().create(true).write(true).truncate(true).open(&tmp)?;
    f.write_all(json.as_bytes())?;
    f.sync_all()?;
    fs::rename(tmp, path)?;
    Ok(())
}
