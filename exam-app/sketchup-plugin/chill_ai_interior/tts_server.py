# encoding: utf-8
import sys
import os

# Force Python UTF-8 mode on Windows
os.environ['PYTHONIOENCODING'] = 'utf-8'
os.environ['PYTHONUTF8'] = '1'
if sys.stdout is None:
    sys.stdout = open(os.devnull, 'w', encoding='utf-8')
if sys.stderr is None:
    sys.stderr = open(os.devnull, 'w', encoding='utf-8')

if hasattr(sys, 'reconfigure'):
    try:
        sys.reconfigure(encoding='utf-8')
    except Exception:
        pass

import time
import hashlib
import asyncio
import threading
import urllib.parse
import urllib.request
import traceback
import re
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import edge_tts
import io
import wave
import json
import sounddevice as sd
import numpy as np
import speech_recognition as sr

# --- STT (SPEECH-TO-TEXT) GOOGLE ENGINE RECORDER ---
stt_lock = threading.Lock()
stt_recording = False
stt_frames = []
stt_stream = None
stt_samplerate = 16000
stt_start_time = 0.0
stt_last_rms = 0.0
stt_has_spoken = False
stt_silence_time = 0.0
stt_interim_text = ""

def _stt_callback(indata, frames, time_info, status):
    global stt_last_rms, stt_has_spoken, stt_silence_time
    if stt_recording:
        stt_frames.append(indata.copy())
        try:
            rms = float(np.sqrt(np.mean(indata.astype(np.float32)**2)))
            stt_last_rms = rms
            # Tiếng nói người: RMS > 100
            if rms > 100.0:
                stt_has_spoken = True
                stt_silence_time = 0.0
            elif stt_has_spoken:
                # Ngừng tiếng (im lặng / tiếng ồn phòng < 75)
                if rms < 75.0:
                    stt_silence_time += float(frames) / float(stt_samplerate)
                else:
                    stt_silence_time = 0.0
        except Exception:
            pass

def _interim_worker():
    global stt_recording, stt_interim_text, stt_frames, stt_has_spoken
    r = sr.Recognizer()
    r.energy_threshold = 200
    last_samples_len = 0
    while stt_recording:
        time.sleep(0.4)
        if not stt_recording:
            break
        if not stt_has_spoken:
            continue
        with stt_lock:
            if not stt_frames:
                continue
            cur_len = sum(len(f) for f in stt_frames)
            # Run whenever we have at least 0.5s audio and gained 0.3s new audio
            if cur_len < int(stt_samplerate * 0.5) or (cur_len - last_samples_len) < int(stt_samplerate * 0.3):
                continue
            snapshot = np.concatenate(stt_frames, axis=0)
            last_samples_len = cur_len

        # Recognize partial snapshot in-memory
        try:
            wav_io = io.BytesIO()
            with wave.open(wav_io, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(stt_samplerate)
                wf.writeframes(snapshot.tobytes())
            wav_io.seek(0)
            with sr.AudioFile(wav_io) as source:
                audio_data = r.record(source)
            txt = r.recognize_google(audio_data, language="vi-VN")
            if txt and stt_recording:
                stt_interim_text = txt.strip()
                print(f"[STT Live Streaming]: '{stt_interim_text}'")
        except Exception:
            pass

def start_stt_recording():
    global stt_recording, stt_frames, stt_stream, stt_start_time, stt_last_rms, stt_has_spoken, stt_silence_time, stt_interim_text
    with stt_lock:
        stt_frames = []
        stt_recording = True
        stt_start_time = time.time()
        stt_last_rms = 0.0
        stt_has_spoken = False
        stt_silence_time = 0.0
        stt_interim_text = ""
        if stt_stream is None:
            try:
                stt_stream = sd.InputStream(samplerate=stt_samplerate, channels=1, dtype='int16', callback=_stt_callback)
                stt_stream.start()
                print("[STT Server] Microphone recording started...")
            except Exception as e:
                print(f"[STT Server Error] Cannot open mic: {e}")
                stt_stream = None

    threading.Thread(target=_interim_worker, daemon=True).start()

def get_stt_status():
    global stt_recording, stt_start_time, stt_last_rms, stt_has_spoken, stt_silence_time, stt_interim_text
    duration = time.time() - stt_start_time if stt_recording else 0.0
    silence_detected = bool(stt_has_spoken and stt_silence_time >= 0.95 and duration >= 0.8)
    return {
        "status": "recording" if stt_recording else "idle",
        "duration": round(duration, 2),
        "rms": round(stt_last_rms, 1),
        "has_spoken": stt_has_spoken,
        "interim_text": stt_interim_text,
        "silence_detected": silence_detected
    }

def stop_stt_recording():
    global stt_recording, stt_frames, stt_stream, stt_has_spoken, stt_interim_text
    with stt_lock:
        stt_recording = False
        if stt_stream is not None:
            try:
                stt_stream.stop()
                stt_stream.close()
            except Exception:
                pass
            stt_stream = None

        if not stt_frames:
            return {"status": "ok" if stt_interim_text else "no_speech", "text": stt_interim_text}

        full_audio = np.concatenate(stt_frames, axis=0)
        stt_frames = []

        if len(full_audio) < int(stt_samplerate * 0.3):
            return {"status": "ok" if stt_interim_text else "no_speech", "text": stt_interim_text}

        # Convert to in-memory WAV file
        wav_io = io.BytesIO()
        with wave.open(wav_io, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(stt_samplerate)
            wf.writeframes(full_audio.tobytes())
        wav_io.seek(0)

        # Recognize Vietnamese Speech with Google STT API (Free)
        r = sr.Recognizer()
        r.energy_threshold = 200
        r.dynamic_energy_threshold = True
        try:
            with sr.AudioFile(wav_io) as source:
                audio_data = r.record(source)
            text = r.recognize_google(audio_data, language="vi-VN")
            text = text.strip() if text else stt_interim_text
            print(f"[STT Server] Final Recognized: '{text}'")
            return {"status": "ok", "text": text}
        except sr.UnknownValueError:
            if stt_interim_text:
                return {"status": "ok", "text": stt_interim_text}
            return {"status": "no_speech", "text": ""}
        except Exception as e:
            if stt_interim_text:
                return {"status": "ok", "text": stt_interim_text}
            return {"status": "error", "message": str(e), "text": ""}



PORT = 57821

VOICES = {
    'hoaimy': 'vi-VN-HoaiMyNeural',
    'namminh': 'vi-VN-NamMinhNeural',
    'google': 'google',
}

CACHE_DIR = os.path.join(os.environ.get('TEMP', os.path.expanduser('~')), 'chill_ai_tts_cache')
os.makedirs(CACHE_DIR, exist_ok=True)

# Purge any old Google-contaminated MP3s from cache on startup
def clean_contaminated_cache():
    try:
        for fname in os.listdir(CACHE_DIR):
            if not fname.endswith('.mp3'):
                continue
            fpath = os.path.join(CACHE_DIR, fname)
            try:
                with open(fpath, 'rb') as f:
                    hdr = f.read(4)
                # Google TTS MP3 headers start with \xff\xf3\x84\xc4 or \xff\xf3\xa4\xc4
                if len(hdr) >= 4 and hdr[0] == 0xff and hdr[1] == 0xf3 and hdr[2] in (0x84, 0xa4, 0xe4):
                    os.remove(fpath)
            except Exception:
                pass
    except Exception:
        pass

clean_contaminated_cache()

bg_loop = asyncio.new_event_loop()
def loop_runner():
    asyncio.set_event_loop(bg_loop)
    bg_loop.run_forever()
bg_thread = threading.Thread(target=loop_runner, daemon=True)
bg_thread.start()

# Pending synthesis futures dictionary to deduplicate concurrent requests
pending_futures = {}
pending_lock = threading.Lock()

def clean_text_for_tts(text):
    t = text.replace("Lyly", "Li Li").replace("lyly", "li li")
    t = t.replace("AI", "A I").replace("2D", "hai đê").replace("3D", "ba đê")
    t = t.replace("CNC", "C N C").replace("MDF", "M D F")
    t = t.replace("•", "").replace("*", "").replace("#", "").replace("`", "")
    t = t.replace("✨", "").replace("❤️", "").replace("👉", "").replace("⏱️", "").replace("🕒", "").replace("📐", "")
    t = t.replace("📖", "").replace("🎨", "").replace("🪵", "").replace("⚙️", "").replace("🔒", "")
    t = t.replace("(", ", ").replace(")", ", ")
    # Convert time 21:40:03 -> 21 giờ 40 phút 03 giây
    t = re.sub(r'(\d{1,2}):(\d{2}):(\d{2})', r'\1 giờ \2 phút \3 giây', t)
    t = re.sub(r'(\d{1,2}):(\d{2})', r'\1 giờ \2 phút', t)
    # Convert date 10/10/2026 -> ngày 10 tháng 10 năm 2026
    t = re.sub(r'(\d{1,2})/(\d{1,2})/(\d{4})', r'ngày \1 tháng \2 năm \3', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t

async def synthesize_edge(text, voice_id):
    clean = clean_text_for_tts(text)
    comm = edge_tts.Communicate(clean, voice_id)
    chunks = []
    async for chunk in comm.stream():
        if chunk["type"] == "audio":
            chunks.append(chunk["data"])
    audio = b"".join(chunks)
    if not audio:
        raise Exception("Empty audio stream from Edge TTS")
    return audio

def fetch_google_tts(text):
    clean = clean_text_for_tts(text)
    url = f"https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=vi&q={urllib.parse.quote(clean)}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    with urllib.request.urlopen(req, timeout=2.5) as res:
        return res.read()

def synthesize_and_save(text, voice_key, cache_file):
    if voice_key == 'google':
        audio = fetch_google_tts(text)
    else:
        voice_id = VOICES.get(voice_key, 'vi-VN-HoaiMyNeural')
        fut = asyncio.run_coroutine_threadsafe(synthesize_edge(text, voice_id), bg_loop)
        audio = fut.result(timeout=5.0)

    if audio and len(audio) > 500:
        with open(cache_file, 'wb') as f:
            f.write(audio)
    return audio

def precache_worker():
    """Background precache worker ensures instant response for common phrases"""
    previews = [
        ('hoaimy', 'Chào Chỉ huy! Mình là Hoài My, giọng đọc trẻ trung đây ạ!'),
        ('namminh', 'Chào Chỉ huy! Tôi là Nam Minh, trợ lý thiết kế kỹ thuật đây.'),
        ('google', 'Chào Chỉ huy! Tôi là giọng đọc cổ điển đây ạ.'),
        ('hoaimy', 'Xin chào! Mình là Lyly, trợ lý ảo 2D của bạn.'),
        ('namminh', 'Xin chào! Mình là Lyly, trợ lý ảo 2D của bạn.'),
        ('google', 'Xin chào! Mình là Lyly, trợ lý ảo 2D của bạn.'),
        ('hoaimy', 'Dạ chào Chỉ huy! Lyly đã sẵn sàng hỗ trợ bạn rồi ạ.'),
        ('namminh', 'Dạ chào Chỉ huy! Lyly đã sẵn sàng hỗ trợ bạn rồi ạ.'),
        ('google', 'Dạ chào Chỉ huy! Lyly đã sẵn sàng hỗ trợ bạn rồi ạ.'),
        ('hoaimy', 'Dạ cảm ơn Chỉ huy rất nhiều! Bất kỳ khi nào Chỉ huy cần tư vấn kích thước đồ gỗ hay bóc tách CNC, Lyly luôn sẵn sàng đồng hành nhé!'),
        ('namminh', 'Dạ cảm ơn Chỉ huy rất nhiều! Bất kỳ khi nào Chỉ huy cần tư vấn kích thước đồ gỗ hay bóc tách CNC, Lyly luôn sẵn sàng đồng hành nhé!'),
        ('google', 'Dạ cảm ơn Chỉ huy rất nhiều! Bất kỳ khi nào Chỉ huy cần tư vấn kích thước đồ gỗ hay bóc tách CNC, Lyly luôn sẵn sàng đồng hành nhé!'),
    ]
    for v_key, text in previews:
        cache_key = hashlib.md5(f"{v_key}:{text}".encode('utf-8')).hexdigest()
        cache_file = os.path.join(CACHE_DIR, f"{cache_key}.mp3")
        if not os.path.exists(cache_file) or os.path.getsize(cache_file) < 2000:
            try:
                synthesize_and_save(text, v_key, cache_file)
            except Exception:
                pass
            time.sleep(0.3)

class TTSHandler(BaseHTTPRequestHandler):
    def address_string(self):
        return self.client_address[0]

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == '/stt_start':
            start_stt_recording()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status":"recording"}')
            return

        if parsed.path == '/stt_status':
            status_data = get_stt_status()
            resp_bytes = json.dumps(status_data, ensure_ascii=False).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(resp_bytes)
            return

        if parsed.path == '/stt_stop':
            result = stop_stt_recording()
            resp_bytes = json.dumps(result, ensure_ascii=False).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(resp_bytes)
            return
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == '/ping':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'PONG')
            return

        # Fire-and-forget prefetch endpoint: warms cache in background
        if parsed.path == '/prefetch':
            query = urllib.parse.parse_qs(parsed.query)
            voice_key = query.get('voice', ['hoaimy'])[0].lower()
            text = query.get('text', [''])[0].strip()
            if text:
                cache_key = hashlib.md5(f"{voice_key}:{text}".encode('utf-8')).hexdigest()
                cache_file = os.path.join(CACHE_DIR, f"{cache_key}.mp3")
                if not os.path.exists(cache_file):
                    threading.Thread(target=synthesize_and_save, args=(text, voice_key, cache_file), daemon=True).start()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'OK')
            return

        if parsed.path == '/tts':
            if stt_recording:
                # Ngắt ngay lập tức yêu cầu đọc tiếng nếu micro đang thu âm để chống lặp gương vô cực!
                self.send_response(204)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                return

            query = urllib.parse.parse_qs(parsed.query)
            voice_key = query.get('voice', ['hoaimy'])[0].lower()
            text = query.get('text', [''])[0].strip()

            if not text:
                self.send_response(400)
                self.end_headers()
                return

            cache_key = hashlib.md5(f"{voice_key}:{text}".encode('utf-8')).hexdigest()
            cache_file = os.path.join(CACHE_DIR, f"{cache_key}.mp3")

            # 1. Instant Cache Hit (< 1ms reflex)
            if os.path.exists(cache_file):
                try:
                    with open(cache_file, 'rb') as f:
                        cached_audio = f.read()
                    if cached_audio and len(cached_audio) > 500:
                        self.send_response(200)
                        self.send_header('Content-Type', 'audio/mpeg')
                        self.send_header('Content-Length', str(len(cached_audio)))
                        self.send_header('X-ChillAI-Voice-Type', 'cached-' + ('google' if voice_key == 'google' else 'neural'))
                        self.send_header('Access-Control-Allow-Origin', '*')
                        self.end_headers()
                        self.wfile.write(cached_audio)
                        return
                except Exception:
                    pass

            # 2. Synthesize on demand
            audio_data = None
            voice_type = 'neural' if voice_key != 'google' else 'google'

            try:
                audio_data = synthesize_and_save(text, voice_key, cache_file)
            except Exception as e:
                # If neural failed on first try, retry once
                if voice_key != 'google':
                    try:
                        time.sleep(0.2)
                        audio_data = synthesize_and_save(text, voice_key, cache_file)
                    except Exception:
                        pass

            if audio_data and len(audio_data) > 500:
                self.send_response(200)
                self.send_header('Content-Type', 'audio/mpeg')
                self.send_header('Content-Length', str(len(audio_data)))
                self.send_header('X-ChillAI-Voice-Type', voice_type)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(audio_data)
                return
            else:
                # NEVER return Google audio for HoaiMy or NamMinh!
                self.send_response(503)
                self.send_header('Content-Type', 'text/plain')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(b'Voice synthesis unavailable')
                return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        pass

def log_crash(msg):
    try:
        crash_log = os.path.join(os.environ.get('TEMP', '.'), 'chill_ai_tts_crash.log')
        with open(crash_log, 'a', encoding='utf-8') as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except Exception:
        pass

class ReusableThreadingServer(ThreadingHTTPServer):
    allow_reuse_address = True

def run_server():
    threading.Thread(target=precache_worker, daemon=True).start()
    server = None
    while True:
        try:
            if server is None:
                server = ReusableThreadingServer(('127.0.0.1', PORT), TTSHandler)
                log_crash(f"Server listening on http://127.0.0.1:{PORT}")
            server.serve_forever()
        except Exception as e:
            log_crash(f"Server exception: {e}\n{traceback.format_exc()}")
            try:
                if server:
                    server.server_close()
            except Exception:
                pass
            server = None
            time.sleep(1)

if __name__ == '__main__':
    run_server()
