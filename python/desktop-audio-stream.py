#!/usr/bin/env python3
"""
Ultra-Low-Latency Desktop Audio Streaming Server.
Captures desktop monitor audio using FFmpeg with low-latency flags and streams
directly to clients over HTTP with TCP_NODELAY and zero backlog buffering.
"""

import sys
import os
import time
import socket
import select
import threading
import subprocess
import signal

PORT = int(os.environ.get("AUDIO_STREAM_PORT", "8000"))
SAMPLE_RATE = 48000
MP3_BITRATE = "192k"
OPUS_BITRATE = "128k"

HTML_PLAYER = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Desktop Audio Stream</title>
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --primary: #38bdf8;
            --primary-hover: #0ea5e9;
            --text: #f8fafc;
            --text-muted: #94a3b8;
            --border: #334155;
            --live: #22c55e;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        body {
            background-color: var(--bg);
            color: var(--text);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .player-card {
            background-color: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 28px;
            width: 100%;
            max-width: 420px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
            text-align: center;
        }
        .header {
            margin-bottom: 24px;
        }
        .header h1 {
            font-size: 1.5rem;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
        }
        .live-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background-color: var(--live);
            display: inline-block;
            box-shadow: 0 0 10px var(--live);
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 0.6; }
            50% { opacity: 1; transform: scale(1.1); }
            100% { opacity: 0.6; }
        }
        .subtitle {
            color: var(--text-muted);
            font-size: 0.875rem;
        }
        .controls {
            display: flex;
            flex-direction: column;
            gap: 16px;
            margin: 20px 0;
        }
        .btn-play {
            background-color: var(--primary);
            color: #0f172a;
            border: none;
            padding: 14px 28px;
            border-radius: 9999px;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            width: 100%;
        }
        .btn-play:hover {
            background-color: var(--primary-hover);
            transform: translateY(-1px);
        }
        .volume-container {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-top: 8px;
        }
        .volume-slider {
            flex: 1;
            accent-color: var(--primary);
            height: 6px;
            border-radius: 3px;
        }
        .stats {
            background-color: rgba(15, 23, 42, 0.6);
            border-radius: 8px;
            padding: 12px;
            font-size: 0.8rem;
            color: var(--text-muted);
            display: flex;
            justify-content: space-around;
            margin-top: 20px;
        }
        .stats-item span {
            display: block;
            color: var(--text);
            font-weight: 600;
            font-size: 0.95rem;
            margin-top: 2px;
        }
        .links {
            margin-top: 20px;
            font-size: 0.85rem;
            color: var(--text-muted);
        }
        .links a {
            color: var(--primary);
            text-decoration: none;
        }
        .links a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="player-card">
        <div class="header">
            <h1><span class="live-dot"></span> Desktop Audio</h1>
            <p class="subtitle">Ultra-Low Latency Live Stream</p>
        </div>

        <audio id="audio" preload="none"></audio>

        <div class="controls">
            <button class="btn-play" id="playBtn" onclick="togglePlay()">
                <svg id="playIcon" width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                <span id="playText">Play Live Audio</span>
            </button>

            <div class="volume-container">
                <span style="font-size: 0.8rem; color: var(--text-muted);">Vol</span>
                <input type="range" class="volume-slider" min="0" max="1" step="0.05" value="1" oninput="setVolume(this.value)">
                <span id="volVal" style="font-size: 0.8rem; min-width: 32px; color: var(--text-muted);">100%</span>
            </div>
        </div>

        <div class="stats">
            <div class="stats-item">
                Latency
                <span id="latencyDisplay">&lt; 150 ms</span>
            </div>
            <div class="stats-item">
                Format
                <span>MP3 192k</span>
            </div>
            <div class="stats-item">
                Status
                <span id="statusDisplay" style="color: var(--live)">Ready</span>
            </div>
        </div>

        <div class="links">
            Direct streams: <a href="/stream.mp3">MP3</a> | <a href="/stream.opus">Opus</a>
            <div style="margin-top: 8px; font-size: 0.75rem;">
                VLC shortcut: <code>vlc --network-caching=50 http://100.122.211.37/stream.mp3</code>
            </div>
        </div>
    </div>

    <script>
        const audio = document.getElementById('audio');
        const playBtn = document.getElementById('playBtn');
        const playText = document.getElementById('playText');
        const playIcon = document.getElementById('playIcon');
        const statusDisplay = document.getElementById('statusDisplay');
        const latencyDisplay = document.getElementById('latencyDisplay');
        let isPlaying = false;

        function togglePlay() {
            if (!isPlaying) {
                // Connect with cache-busting timestamp to hit live edge instantly
                audio.src = '/stream.mp3?t=' + Date.now();
                audio.play().then(() => {
                    isPlaying = true;
                    playText.innerText = 'Mute / Pause';
                    statusDisplay.innerText = 'Live';
                    statusDisplay.style.color = 'var(--live)';
                }).catch(err => {
                    console.error("Playback error:", err);
                });
            } else {
                audio.pause();
                audio.src = '';
                isPlaying = false;
                playText.innerText = 'Play Live Audio';
                statusDisplay.innerText = 'Paused';
                statusDisplay.style.color = 'var(--text-muted)';
            }
        }

        function setVolume(val) {
            audio.volume = val;
            document.getElementById('volVal').innerText = Math.round(val * 100) + '%';
        }

        // Real-time live-edge synchronizer: Keeps browser player tightly clamped to the live edge
        setInterval(() => {
            if (isPlaying && audio.buffered.length > 0) {
                const liveEnd = audio.buffered.end(audio.buffered.length - 1);
                const drift = liveEnd - audio.currentTime;
                if (drift > 0.25) {
                    // Browser has buffered ahead; jump straight to current live edge
                    audio.currentTime = liveEnd - 0.05;
                    latencyDisplay.innerText = '~100 ms';
                } else {
                    latencyDisplay.innerText = Math.round(drift * 1000) + ' ms';
                }
            }
        }, 300);
    </script>
</body>
</html>"""


class StreamTranscoder:
    """Runs FFmpeg for a specific audio codec on demand and multicasts to subscribers."""
    def __init__(self, codec="mp3"):
        self.codec = codec
        self.clients = set()
        self.lock = threading.Lock()
        self.proc = None
        self.running = False
        self.last_client_time = time.time()
        self._thread = None

    def add_client(self, conn):
        with self.lock:
            self.clients.add(conn)
            self.last_client_time = time.time()
            if not self.running:
                self._start_ffmpeg()

    def remove_client(self, conn):
        with self.lock:
            self.clients.discard(conn)
            if not self.clients:
                self.last_client_time = time.time()

    def count(self):
        with self.lock:
            return len(self.clients)

    def _start_ffmpeg(self):
        if self.proc:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=0.5)
            except Exception:
                pass

        if self.codec == "opus":
            cmd = [
                "ffmpeg", "-nostats", "-loglevel", "quiet",
                "-fflags", "nobuffer", "-flags", "low_delay",
                "-f", "pulse", "-fragment_size", "480", "-i", "default.monitor",
                "-c:a", "libopus", "-b:a", OPUS_BITRATE,
                "-frame_duration", "10", "-application", "lowdelay",
                "-flush_packets", "1",
                "-f", "ogg", "pipe:1"
            ]
            self.chunk_size = 384
        else: # mp3
            cmd = [
                "ffmpeg", "-nostats", "-loglevel", "quiet",
                "-fflags", "nobuffer", "-flags", "low_delay",
                "-f", "pulse", "-fragment_size", "480", "-i", "default.monitor",
                "-c:a", "libmp3lame", "-b:a", MP3_BITRATE,
                "-flush_packets", "1",
                "-f", "mp3", "pipe:1"
            ]
            self.chunk_size = 576

        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.running = True
        self._thread = threading.Thread(target=self._broadcast_loop, daemon=True)
        self._thread.start()

    def _stop_ffmpeg(self):
        self.running = False
        if self.proc:
            try:
                self.proc.terminate()
            except Exception:
                pass
            self.proc = None

    def _broadcast_loop(self):
        while self.running and self.proc and self.proc.stdout:
            try:
                chunk = self.proc.stdout.read(self.chunk_size)
                if not chunk:
                    break
            except Exception:
                break

            with self.lock:
                if not self.clients:
                    # If no clients for more than 15s, stop FFmpeg to save CPU
                    if time.time() - self.last_client_time > 15:
                        self._stop_ffmpeg()
                        break
                    continue

                dead = []
                for client in self.clients:
                    try:
                        # Non-blocking check if socket is ready to write
                        _, wlist, _ = select.select([], [client], [], 0.005)
                        if wlist:
                            client.sendall(chunk)
                    except Exception:
                        dead.append(client)

                for d in dead:
                    self.clients.discard(d)
                    try:
                        d.close()
                    except Exception:
                        pass


mp3_transcoder = StreamTranscoder("mp3")
opus_transcoder = StreamTranscoder("opus")


def handle_client(conn, addr):
    try:
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        # Limit kernel socket buffer to ~8KB (prevent old backlog on latency spikes)
        conn.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 8192)

        # Read HTTP request header
        req_data = b""
        conn.settimeout(3.0)
        while b"\r\n\r\n" not in req_data and len(req_data) < 4096:
            chunk = conn.recv(1024)
            if not chunk:
                break
            req_data += chunk

        if not req_data:
            conn.close()
            return

        request_line = req_data.split(b"\r\n")[0].decode("utf-8", errors="ignore")
        parts = request_line.split()
        if len(parts) < 2:
            conn.close()
            return

        method, path = parts[0], parts[1]
        path_clean = path.split("?")[0]

        # Route requests
        if path_clean in ("/stream.opus", "/opus"):
            header = (
                "HTTP/1.0 200 OK\r\n"
                "Content-Type: audio/ogg\r\n"
                "Cache-Control: no-cache, no-store, must-revalidate\r\n"
                "Pragma: no-cache\r\n"
                "Expires: 0\r\n"
                "Connection: close\r\n"
                "Access-Control-Allow-Origin: *\r\n\r\n"
            )
            conn.sendall(header.encode("ascii"))
            conn.setblocking(False)
            opus_transcoder.add_client(conn)
            # The broadcast loop will manage and close conn on disconnect

        elif path_clean in ("/stream.mp3", "/stream", "/mp3"):
            header = (
                "HTTP/1.0 200 OK\r\n"
                "Content-Type: audio/mpeg\r\n"
                "Cache-Control: no-cache, no-store, must-revalidate\r\n"
                "Pragma: no-cache\r\n"
                "Expires: 0\r\n"
                "Connection: close\r\n"
                "Access-Control-Allow-Origin: *\r\n\r\n"
            )
            conn.sendall(header.encode("ascii"))
            conn.setblocking(False)
            mp3_transcoder.add_client(conn)
            # The broadcast loop will manage and close conn on disconnect

        elif path_clean in ("/", "/index.html", "/player"):
            body = HTML_PLAYER.encode("utf-8")
            header = (
                f"HTTP/1.0 200 OK\r\n"
                f"Content-Type: text/html; charset=utf-8\r\n"
                f"Content-Length: {len(body)}\r\n"
                f"Connection: close\r\n\r\n"
            )
            conn.sendall(header.encode("ascii") + body)
            conn.close()

        else:
            # 404
            conn.sendall(b"HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            conn.close()

    except Exception as e:
        try:
            conn.close()
        except Exception:
            pass


def main():
    # Setup dual-stack / IPv4 server socket
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", PORT))
    server.listen(25)
    print(f"Low-latency desktop audio server listening on http://0.0.0.0:{PORT}/")

    def shutdown(sig, frame):
        print("\nShutting down...")
        mp3_transcoder._stop_ffmpeg()
        opus_transcoder._stop_ffmpeg()
        server.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    while True:
        try:
            conn, addr = server.accept()
            t = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
            t.start()
        except Exception:
            break


if __name__ == "__main__":
    main()
