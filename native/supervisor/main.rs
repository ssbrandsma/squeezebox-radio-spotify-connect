//! Small librespot supervisor with a stable, local status file for the Lua applet.
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

fn write_status(path: &str, state: &str, extra: Option<(&str, &str)>) {
    let mut json = format!(r#"{{"state":"{}""#, state);
    if let Some((key, value)) = extra {
        let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
        json.push_str(&format!(r#","{}":"{}""#, key, escaped));
    }
    json.push_str("}\n");
    if let Ok(mut f) = OpenOptions::new().create(true).write(true).truncate(true).open(path) {
        let _ = f.write_all(json.as_bytes());
        #[cfg(unix)] { use std::os::unix::fs::PermissionsExt; let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600)); }
    }
}

fn main() -> std::io::Result<()> {
    let mut it = env::args().skip(1);
    let status = it.next().filter(|x| x == "--status").and_then(|_| it.next()).ok_or_else(|| std::io::Error::other("--status PATH required"))?;
    if it.next().as_deref() != Some("--") { return Err(std::io::Error::other("-- separates supervisor and librespot arguments")); }
    let args: Vec<String> = it.collect();
    if args.is_empty() { return Err(std::io::Error::other("librespot command required")); }
    write_status(&status, "starting", None);
    let mut child = Command::new(&args[0]).args(&args[1..]).stdout(Stdio::piped()).stderr(Stdio::piped()).spawn()?;
    let out = child.stdout.take().unwrap();
    let err = child.stderr.take().unwrap();
    let status_out = status.clone();
    let t1 = std::thread::spawn(move || {
        for line in BufReader::new(out).lines().flatten() { println!("{}", line); }
    });
    let t2 = std::thread::spawn(move || {
        for line in BufReader::new(err).lines().flatten() {
            eprintln!("{}", line);
            if let Some(pos) = line.find("Browse to: ") {
                let url = line[pos + 11..].trim();
                write_status(&status_out, "pairing", Some(("url", url)));
            } else if line.contains("Authenticated as") {
                write_status(&status_out, "connected", None);
            } else if line.contains("ERROR") || line.contains("error") {
                write_status(&status_out, "error", Some(("message", line.trim())));
            }
        }
    });
    let result = child.wait()?;
    let _ = t1.join(); let _ = t2.join();
    if !result.success() { write_status(&status, "error", Some(("message", &format!("librespot exited: {}", result)))); }
    Ok(())
}
