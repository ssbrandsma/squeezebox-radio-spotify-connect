//! PoC guard: never create/truncate a regular ramfs file at the FIFO path.
use std::{fs::{File, OpenOptions}, io, os::unix::fs::FileTypeExt, path::Path};

pub fn open_required_fifo(path: &Path) -> io::Result<File> {
    if !path.symlink_metadata()?.file_type().is_fifo() {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "Phase 5 output must be an existing FIFO"));
    }
    let file = OpenOptions::new().write(true).open(path)?;
    if !file.metadata()?.file_type().is_fifo() {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "Phase 5 output changed type while opening"));
    }
    Ok(file)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_regular_file_without_truncation_and_missing_path_without_creation() {
        let path = std::env::temp_dir().join(format!("squeezify-fifo-guard-{}",std::process::id()));
        let mut create = OpenOptions::new().write(true).create_new(true).open(&path).unwrap();
        std::io::Write::write_all(&mut create,b"retain me").unwrap();
        assert_eq!(open_required_fifo(&path).unwrap_err().kind(),io::ErrorKind::InvalidInput);
        assert_eq!(std::fs::read(&path).unwrap(),b"retain me");
        std::fs::remove_file(&path).unwrap();
        assert_eq!(open_required_fifo(&path).unwrap_err().kind(),io::ErrorKind::NotFound);
        assert!(!path.exists());
    }
    #[test]
    fn opens_a_real_fifo_and_transfers_bytes() {
        use std::io::{Read,Write};
        let path=std::env::temp_dir().join(format!("squeezify-fifo-positive-{}",std::process::id()));
        assert!(std::process::Command::new("mkfifo").arg(&path).status().unwrap().success());
        let reader_path=path.clone();
        let reader=std::thread::spawn(move || { let mut bytes=Vec::new(); File::open(reader_path).unwrap().read_to_end(&mut bytes).unwrap(); bytes });
        let mut writer=open_required_fifo(&path).unwrap();
        writer.write_all(b"OggS test").unwrap(); drop(writer);
        assert_eq!(reader.join().unwrap(),b"OggS test");
        std::fs::remove_file(path).unwrap();
    }
}
