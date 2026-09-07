//! Bounded, single-client Ogg HTTP bridge. No decoder and no audio files.
use std::io::{self, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::os::fd::AsRawFd;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::time::{Duration, Instant};

const MAX_PAGE: usize = 27 + 255 + 255 * 255;
const MAX_HEADERS: usize = 65536;

unsafe extern "C" {
    fn setsockopt(fd: i32, level: i32, option: i32, value: *const i32, length: u32) -> i32;
}

fn page(r: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
    let mut h = [0u8; 27];
    if r.read(&mut h[..1])? == 0 { return Ok(None); }
    r.read_exact(&mut h[1..])?;
    if &h[..4] != b"OggS" || h[4] != 0 {
        return Err(io::Error::other("invalid Ogg capture/version"));
    }
    let mut p = Vec::with_capacity(MAX_PAGE);
    p.extend_from_slice(&h);
    p.resize(27 + h[26] as usize, 0);
    r.read_exact(&mut p[27..])?;
    let body: usize = p[27..].iter().map(|&n| n as usize).sum();
    let start = p.len();
    p.resize(start + body, 0);
    r.read_exact(&mut p[start..])?;
    Ok(Some(p))
}

#[derive(Default)]
struct Headers {
    serial: Option<u32>,
    bytes: Vec<u8>,
    packets: usize,
    prefix: Vec<u8>,
    rate: u32,
}

impl Headers {
    fn observe(&mut self, p: &[u8]) -> io::Result<()> {
        let serial = u32::from_le_bytes(p[14..18].try_into().unwrap());
        if p[5] & 2 != 0 {
            *self = Self { serial: Some(serial), bytes: Vec::with_capacity(MAX_HEADERS), ..Self::default() };
            eprintln!("[BRIDGE] new logical stream serial={serial}");
        }
        if self.serial != Some(serial) {
            return Err(io::Error::other("page without matching BOS"));
        }
        if self.packets == 3 { return Ok(()); }
        if self.bytes.len() + p.len() > MAX_HEADERS {
            return Err(io::Error::other("Vorbis headers exceed 65536-byte limit"));
        }
        let n = p[26] as usize;
        let mut offset = 27 + n;
        for &segment in &p[27..27+n] {
            if self.packets == 3 {
                return Err(io::Error::other("audio shares setup header page; unsupported producer framing"));
            }
            let take = (16 - self.prefix.len()).min(segment as usize);
            self.prefix.extend_from_slice(&p[offset..offset+take]);
            offset += segment as usize;
            if segment < 255 {
                let expected = [1, 3, 5][self.packets];
                if self.prefix.len() < 7 || self.prefix[0] != expected || &self.prefix[1..7] != b"vorbis" {
                    return Err(io::Error::other("invalid Vorbis header order/signature"));
                }
                if self.packets == 0 {
                    if self.prefix.len() < 16 { return Err(io::Error::other("short identification header")); }
                    self.rate = u32::from_le_bytes(self.prefix[12..16].try_into().unwrap());
                    if self.rate == 0 || self.rate > 192000 { return Err(io::Error::other("invalid sample rate")); }
                }
                self.packets += 1;
                self.prefix.clear();
            }
        }
        self.bytes.extend_from_slice(p);
        if self.packets == 3 {
            eprintln!("[BRIDGE] cached Vorbis headers bytes={}", self.bytes.len());
        }
        Ok(())
    }
}

fn accept_http(mut s: TcpStream) -> io::Result<TcpStream> {
    let send_buffer: i32 = 16384;
    // Linux doubles SO_SNDBUF for bookkeeping: a 32768-byte socket limit.
    if unsafe { setsockopt(s.as_raw_fd(), 1, 7, &send_buffer, 4) } != 0 {
        return Err(io::Error::last_os_error());
    }
    s.set_read_timeout(Some(Duration::from_secs(2)))?;
    s.set_write_timeout(Some(Duration::from_secs(2)))?;
    let mut request = Vec::with_capacity(4096);
    while request.len() < 4096 {
        let mut b = [0u8; 1];
        s.read_exact(&mut b)?;
        request.push(b[0]);
        // Stock StandaloneRadio uses LF, while ordinary clients use CRLF.
        if request.ends_with(b"\r\n\r\n") || request.ends_with(b"\n\n") { break; }
    }
    let first = request.split(|&b| b == b'\n').next().unwrap_or(&[]);
    if request.len() == 4096 || !(first == b"GET /spotify.ogg HTTP/1.0\r" || first == b"GET /spotify.ogg HTTP/1.0" || first == b"GET /spotify.ogg HTTP/1.1\r") {
        s.write_all(b"HTTP/1.0 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")?;
        return Err(io::Error::other("unsupported HTTP request"));
    }
    s.write_all(b"HTTP/1.0 200 OK\r\nContent-Type: audio/ogg\r\nConnection: close\r\n\r\n")?;
    eprintln!("[BRIDGE] client connected; sent HTTP 200 audio/ogg");
    Ok(s)
}

fn main() -> io::Result<()> {
    let port = std::env::args().nth(1).unwrap_or_else(|| "17880".into());
    let paced = !std::env::args().any(|a| a == "--unpaced");
    let listener = TcpListener::bind(format!("127.0.0.1:{port}"))?;
    listener.set_nonblocking(true)?;
    eprintln!("[BRIDGE] listening 127.0.0.1:{port}; stdin producer; page={MAX_PAGE} header={MAX_HEADERS} queue=1");
    let (tx, rx) = mpsc::sync_channel(1);
    std::thread::Builder::new().stack_size(128 * 1024).spawn(move || {
        let mut input = io::stdin().lock();
        loop {
            let item = page(&mut input);
            let done = !matches!(item, Ok(Some(_)));
            if tx.send(item).is_err() || done { break; }
        }
    })?;
    let mut headers = Headers::default();
    let mut client: Option<TcpStream> = None;
    let mut pending: Option<Vec<u8>> = None;
    let mut pending_header = false;
    let mut offset = 0;
    let mut forwarded = 0u64;
    let mut last_log = Instant::now();
    let mut timeline: Option<(Instant, u64)> = None;
    loop {
        if client.is_none() {
            match listener.accept() {
                Ok((socket, _)) => match accept_http(socket) {
                    Ok(mut socket) => {
                        if socket.write_all(&headers.bytes).is_ok() {
                            eprintln!("[BRIDGE] replayed header bytes={}", headers.bytes.len());
                            socket.set_write_timeout(Some(Duration::from_millis(100)))?;
                            client = Some(socket);
                            timeline = None;
                        }
                    }
                    Err(e) => eprintln!("[BRIDGE] HTTP rejected: {e}"),
                },
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => (),
                Err(e) => return Err(e),
            }
        }
        // Hold the next audio page until a client arrives. This preserves a
        // complete start for a late first client, with bounded backpressure.
        if pending.is_some() && client.is_none() {
            std::thread::sleep(Duration::from_millis(100));
            continue;
        }
        if pending.is_none() {
            match rx.recv_timeout(Duration::from_millis(100)) {
                Ok(Ok(Some(p))) => {
                    let is_header = p[5] & 2 != 0 || headers.packets < 3;
                    if p[5] & 2 != 0 { timeline = None; }
                    headers.observe(&p)?;
                    if client.is_some() || !is_header {
                        pending = Some(p);
                        pending_header = is_header;
                        offset = 0;
                    }
                }
                Ok(Ok(None)) | Err(RecvTimeoutError::Disconnected) => {
                    eprintln!("[BRIDGE] producer EOF; forwarded={forwarded}");
                    return Ok(());
                }
                Ok(Err(e)) => return Err(e),
                Err(RecvTimeoutError::Timeout) => continue,
            }
        }
        if let (Some(p), Some(s)) = (pending.as_ref(), client.as_mut()) {
            if paced && !pending_header && offset == 0 {
                let gp = u64::from_le_bytes(p[6..14].try_into().unwrap());
                if gp != u64::MAX {
                    let (epoch, base) = *timeline.get_or_insert((Instant::now(), gp));
                    let due_ms = gp.saturating_sub(base).saturating_mul(1000) / headers.rate as u64;
                    // One second of lead, plus the first page, covers decoder
                    // startup without filling the stock multi-megabyte buffer.
                    let due = Duration::from_millis(due_ms.saturating_sub(1000));
                    if let Some(wait) = due.checked_sub(epoch.elapsed()) {
                        std::thread::sleep(wait.min(Duration::from_millis(100)));
                        continue;
                    }
                }
            }
            match s.write(&p[offset..]) {
                Ok(n) if n > 0 => {
                    offset += n;
                    forwarded += n as u64;
                    if offset == p.len() { pending = None; offset = 0; }
                }
                Err(e) if matches!(e.kind(), io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut | io::ErrorKind::Interrupted) => (),
                result => {
                    eprintln!("[BRIDGE] client disconnected: {result:?}; retaining one pending page");
                    client = None;
                    offset = 0;
                    // This page is already in the replay cache. Do not send it twice.
                    if pending_header { pending = None; }
                }
            }
        }
        if last_log.elapsed() >= Duration::from_secs(10) {
            eprintln!("[BRIDGE] forwarded={forwarded}");
            last_log = Instant::now();
        }
    }
}
