//! Bounded loopback HTTP/1.0 Ogg handoff. It never decodes or stores tracks.
use std::io::{self, Read, Write};
use std::net::{TcpListener, TcpStream, ToSocketAddrs};
use std::thread;

fn source_body(source: &str) -> io::Result<TcpStream> {
    let url = source.strip_prefix("http://").ok_or_else(|| io::Error::other("only http:// sources are supported"))?;
    let (authority, path) = url.split_once('/').unwrap_or((url, ""));
    let (host, port) = authority.split_once(':').unwrap_or((authority, "80"));
    let addr = (host, port.parse::<u16>().map_err(|_| io::Error::other("invalid port"))?)
        .to_socket_addrs()?.next().ok_or_else(|| io::Error::other("source DNS failed"))?;
    let mut upstream = TcpStream::connect(addr)?;
    let request = format!("GET /{} HTTP/1.0\r\nHost: {}\r\nUser-Agent: SBSpotifyConnect/0.1\r\nConnection: close\r\n\r\n", path, authority);
    upstream.write_all(request.as_bytes())?;
    let mut response = Vec::with_capacity(4096);
    let mut byte = [0u8; 1];
    while response.len() < 4096 {
        upstream.read_exact(&mut byte)?;
        response.push(byte[0]);
        if response.ends_with(b"\r\n\r\n") { break; }
    }
    if !response.starts_with(b"HTTP/1.") || !response.windows(3).any(|w| w == b"200") {
        return Err(io::Error::other("source did not return HTTP 200"));
    }
    Ok(upstream)
}

fn client(mut s: TcpStream, source: String) -> io::Result<()> {
    let mut req = [0u8; 1024];
    let n = s.read(&mut req)?;
    let first = req[..n].split(|b| *b == b'\n').next().unwrap_or(&[]);
    if !first.starts_with(b"GET /test.ogg HTTP/") { return Ok(()); }
    s.write_all(b"HTTP/1.0 200 OK\r\nContent-Type: audio/ogg\r\nConnection: close\r\n\r\n")?;
    let mut input = source_body(&source)?;
    let mut buf = [0u8; 65536];
    loop { let n = input.read(&mut buf)?; if n == 0 { break; } s.write_all(&buf[..n])?; }
    Ok(())
}

fn main() -> io::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let source = args.windows(2).find(|a| a[0] == "--source").map(|a| a[1].clone())
        .or_else(|| std::env::var("TEST_OGG_URL").ok())
        .unwrap_or_else(|| "http://live.chbnradio.org:8000/chbn.ogg".to_string());
    let listener = TcpListener::bind("127.0.0.1:17880")?;
    for stream in listener.incoming() {
        let stream = stream?;
        let url = source.clone();
        thread::spawn(move || { let _ = client(stream, url); });
    }
    Ok(())
}
