//! Sequential CDN reader for constrained devices. It intentionally has no Seek
//! implementation and keeps at most four 64 KiB chunks in memory.
use std::{io, sync::mpsc::{sync_channel, Receiver}};
use bytes::Bytes;
use futures_util::StreamExt;
use http_body_util::BodyExt;
use hyper::StatusCode;
use librespot_core::{Error, FileId, Session, cdn_url::CdnUrl};

const CHUNK: usize = 64 * 1024;
const QUEUE: usize = 4;

pub struct SequentialAudio {
    rx: Receiver<Result<Vec<u8>, String>>,
    current: Option<(Vec<u8>, usize)>,
    position: u64,
    pub file_size: usize,
}

impl SequentialAudio {
    pub async fn open(session: Session, file_id: FileId) -> Result<Self, Error> {
        let cdn = CdnUrl::new(file_id).resolve_audio(&session).await?;
        let urls = cdn.try_get_urls()?;
        let mut selected = None;
        for url in urls {
            let stream = session.spclient().stream_from_cdn(url, 0, CHUNK)?;
            let mut stream = stream;
            match tokio::time::timeout(std::time::Duration::from_secs(10), stream.next()).await {
                Ok(Some(Ok(response))) if response.status() == StatusCode::PARTIAL_CONTENT => {
                    let total = response.headers().get("content-range")
                        .and_then(|v| v.to_str().ok())
                        .and_then(|v| v.rsplit('/').next())
                        .and_then(|v| v.parse::<usize>().ok())
                        .ok_or_else(|| Error::unavailable("streaming CDN response lacks Content-Range"))?;
                    selected = Some((url.to_string(), response, total));
                    break;
                }
                Ok(Some(Ok(response))) => warn!("streaming CDN returned {}", response.status()),
                Ok(Some(Err(e))) => warn!("streaming CDN error: {e}"),
                _ => warn!("streaming CDN timeout or EOF"),
            }
        }
        let Some((url, first, total)) = selected else {
            return Err(Error::unavailable("streaming CDN URLs failed"));
        };
        let (tx, rx) = sync_channel::<Result<Vec<u8>, String>>(QUEUE);
        let session_for_task = session.clone();
        tokio::spawn(async move {
            let mut offset = 0usize;
            let mut response = Some(first);
            loop {
                let body = match response.take() {
                    Some(r) => r.into_body(),
                    None => {
                        if offset >= total { break; }
                        match session_for_task.spclient().stream_from_cdn(url.as_str(), offset, CHUNK) {
                            Ok(mut s) => match s.next().await {
                                Some(Ok(r)) if r.status() == StatusCode::PARTIAL_CONTENT => r.into_body(),
                                Some(Ok(r)) => { let _ = tx.send(Err(format!("streaming CDN status {}", r.status()))); break; }
                                Some(Err(e)) => { let _ = tx.send(Err(e.to_string())); break; }
                                None => { let _ = tx.send(Err("streaming CDN EOF".into())); break; }
                            },
                            Err(e) => { let _ = tx.send(Err(e.to_string())); break; }
                        }
                    }
                };
                let data: Bytes = match body.collect().await {
                    Ok(collected) => collected.to_bytes(),
                    Err(e) => { let _ = tx.send(Err(e.to_string())); break; }
                };
                if data.is_empty() { break; }
                offset += data.len();
                if tx.send(Ok(data.to_vec())).is_err() { break; }
            }
        });
        Ok(Self { rx, current: None, position: 0, file_size: total })
    }
}

impl io::Read for SequentialAudio {
    fn read(&mut self, out: &mut [u8]) -> io::Result<usize> {
        if out.is_empty() { return Ok(0); }
        let mut copied = 0;
        while copied < out.len() {
            if self.current.as_ref().map_or(true, |(_, pos)| *pos >= self.current.as_ref().unwrap().0.len()) {
                match self.rx.recv() {
                    Ok(Ok(data)) => self.current = Some((data, 0)),
                    Ok(Err(e)) => return Err(io::Error::new(io::ErrorKind::Other, e)),
                    Err(_) => break,
                }
            }
            let (data, pos) = self.current.as_mut().unwrap();
            let n = (out.len() - copied).min(data.len() - *pos);
            out[copied..copied+n].copy_from_slice(&data[*pos..*pos+n]);
            *pos += n; copied += n; self.position += n as u64;
        }
        Ok(copied)
    }
}

impl io::Seek for SequentialAudio {
    fn seek(&mut self, pos: io::SeekFrom) -> io::Result<u64> {
        let requested = match pos { io::SeekFrom::Current(0) => self.position, _ => return Err(io::Error::new(io::ErrorKind::Unsupported, "streaming-only mode does not support seek")) };
        Ok(requested)
    }
}
