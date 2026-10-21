
// ==============================================================================
// GLOBAL BRIDGE CALLBACKS FOR OLLAMA LOCAL (gemma4:e4b)
// ==============================================================================
window._ollamaCallbacks = window._ollamaCallbacks || {};
window.onOllamaChatResponse = function(payload) {
  try {
    const data = typeof payload === 'string' ? JSON.parse(payload) : payload;
    const cb = window._ollamaCallbacks[data.callback_id];
    if (cb) {
      cb(data);
    }
  } catch(e) {
    console.error("[Ollama Bridge Callback Error]:", e);
  }
};

// ==============================================================================
// Chill AI Interior - 2D Virtual Avatar & Storytelling Consultant ("Lyly")
// Version: 6.0 - Ultra-Fast Instant-Intelligence Engine & True Multi-Voice Bridge
// ==============================================================================

// --- AUDIO SYNTHESIS & VOICE SELECTION ENGINE ---
class EdgeTTS {
  static VOICES = {
    'hoaimy':   { id: 'hoaimy',   client: 'tw-ob', label: 'Hoài My (Nữ miền Nam)',   rateMul: 1.18 },
    'namminh':  { id: 'namminh',  client: 'gtx',   label: 'Nam Minh (Nam miền Bắc)', rateMul: 0.84 },
    'google':   { id: 'google',   client: 'tw-ob', label: 'Chị Google (Cổ điển)',     rateMul: 1.00 },
  };

  static prewarm() {
    // Ultra-fast HTTP streaming: ready on demand
  }

  /**
   * Pre-fetch TTS audio in background so Python server caches it.
   * When Ruby bridge later requests the same text+voice, it gets cached audio instantly.
   */
  static prefetchTTS(text, voiceKey = 'hoaimy') {
    if (voiceKey === 'google') return; // Google TTS needs no prefetch
    const plain = text.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/gi, '').trim();
    if (!plain || plain.length < 2) return;
    // Speak the full message naturally without cutting off sentences
    const vocalText = plain;
    const url = `http://127.0.0.1:57821/prefetch?voice=${voiceKey}&text=${encodeURIComponent(vocalText)}`;
    // Fire-and-forget: just warm the cache, don't need the response
    fetch(url).catch(() => {});
  }

  static synthesize(text, voiceKey = 'hoaimy', speed = 1.0) {
    const plain = text.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/gi, '').trim();

    if (voiceKey === 'google') {
      const chunks = EdgeTTS._splitChunks(plain);
      const urls = chunks.map(c => `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=vi&q=${encodeURIComponent(c)}`);
      return { type: 'url_list', urls: urls, fallbackUrls: [], voice: 'google', speed: speed };
    }

    // Authentic Microsoft Neural Voices via local bridge
    // NO Google fallback URLs for neural voices — they must NEVER fall back to Google
    const localUrl = `http://127.0.0.1:57821/tts?voice=${voiceKey}&text=${encodeURIComponent(plain)}`;

    return {
      type: 'url_list',
      urls: [localUrl],
      fallbackUrls: [],  // EMPTY: Neural voices never fall back to Google
      voice: voiceKey,
      speed: speed
    };
  }

  static _splitChunks(text) {
    const chunks = [];
    let remaining = text;
    while (remaining.length > 0) {
      if (remaining.length <= 180) {
        chunks.push(remaining);
        break;
      }
      let splitAt = remaining.lastIndexOf('.', 180);
      if (splitAt < 40) splitAt = remaining.lastIndexOf('!', 180);
      if (splitAt < 40) splitAt = remaining.lastIndexOf('?', 180);
      if (splitAt < 40) splitAt = remaining.lastIndexOf(',', 180);
      if (splitAt < 40) splitAt = remaining.lastIndexOf(';', 180);
      if (splitAt < 40) splitAt = remaining.lastIndexOf(' ', 180);
      if (splitAt < 40) splitAt = 180;
      chunks.push(remaining.substring(0, splitAt + 1).trim());
      remaining = remaining.substring(splitAt + 1).trim();
    }
    return chunks.filter(c => c.length > 0);
  }
}


// --- AVATAR CONSULTANT (ANH THỢ MỘC & TIN TIN AI) ---
class AvatarConsultant {
  constructor() {
    this.name = "Anh Thợ Mộc";
    this.aiName = "Tin Tin";
    this.title = "Chuyên Gia Đồ Gỗ & Thi Công Nội Thất AI";

    // DOM references
    this.speechBubble = document.getElementById('avatar-speech-bubble');
    this.chatContainer = document.getElementById('chat-messages');

    // State
    this.currentEmotion = 'neutral';
    this.isVoiceEnabled = true;
    this.sessionStartTime = Date.now();
    this.voiceKey = localStorage.getItem('chill_ai_voice') || 'namminh';
    this.speechSpeed = 1.0;
    this.chatHistory = [];
    this.isProcessing = false;
    this.currentAudio = null;

    this.speechBubbleTier = 0; // 0: Default, 1: High near top, 2: Fullscreen 3D
    this.talkingTimer = null;
    this.talkingStopTimeout = null;

    // Init
    window.avatar = this;
    this.initKnowledgeBase();
    this.initWelcomeMessage();
    this.initSpeechBubbleExpander();
    this.initCharacterClick();
  }

  // ========================
  // EMOTIONS
  // ========================
  setMouthState(state) {
    const closedEls = document.querySelectorAll('#avatar-mouth-closed, #dock-avatar-mouth-closed');
    const halfEls = document.querySelectorAll('#avatar-mouth-half, #dock-avatar-mouth-half');
    const openEls = document.querySelectorAll('#avatar-mouth-open, #dock-avatar-mouth-open');

    if (closedEls.length === 0 && openEls.length === 0) return;

    if (state === 'open') {
      closedEls.forEach(el => el.style.display = 'none');
      halfEls.forEach(el => el.style.display = 'none');
      openEls.forEach(el => el.style.display = 'block');
    } else if (state === 'half') {
      closedEls.forEach(el => el.style.display = 'none');
      openEls.forEach(el => el.style.display = 'none');
      halfEls.forEach(el => el.style.display = 'block');
    } else {
      // closed (default / idle state)
      openEls.forEach(el => el.style.display = 'none');
      halfEls.forEach(el => el.style.display = 'none');
      closedEls.forEach(el => el.style.display = 'block');
    }
  }

  setEmotion(emotion) {
    this.currentEmotion = emotion;
    this.setMouthState('closed');
  }

  // ========================
  // GAME-STYLE LIP-SYNC & TALKING ANIMATION
  // ========================
  startTalking(durationMs = 2800) {
    this.stopTalking();

    const figure = document.getElementById('character-figure');
    if (figure) figure.classList.add('speaking');

    // Natural game dialogue rhythm: articulate (half) -> speak (open) -> articulate (half) -> close briefly -> repeat
    const patterns = ['half', 'open', 'half', 'open', 'half', 'closed', 'half', 'open', 'closed'];
    let idx = 0;

    this.talkingTimer = setInterval(() => {
      const state = patterns[idx];
      this.setMouthState(state);
      idx = (idx + 1) % patterns.length;
    }, 130);

    // Dynamic duration linked to sentence length and audio playback
    // (Up to 45s safety ceiling; will be closed immediately when audio finishes via onAudioFinished)
    const safeDuration = Math.min(45000, Math.max(2000, durationMs));
    this.talkingStopTimeout = setTimeout(() => {
      this.stopTalking();
    }, safeDuration);
  }

  stopTalking() {
    if (this.talkingTimer) {
      clearInterval(this.talkingTimer);
      this.talkingTimer = null;
    }
    if (this.talkingStopTimeout) {
      clearTimeout(this.talkingStopTimeout);
      this.talkingStopTimeout = null;
    }

    const figure = document.getElementById('character-figure');
    if (figure) figure.classList.remove('speaking');

    // Always reset mouth to closed idle state
    this.setMouthState('closed');
  }

  // Real-time audio sync hooks called by Ruby bridge / HTML5 Audio
  onAudioStarted() {
    this.startTalking(45000);
  }

  onAudioFinished() {
    this.stopTalking();
  }

  initCharacterClick() {
    const figure = document.getElementById('character-figure');
    if (!figure) return;
    figure.style.cursor = 'pointer';
    figure.title = 'Bấm vào Anh Thợ Mộc để trò chuyện';
    figure.addEventListener('click', () => {
      if (window.chillApp && window.chillApp.currentSelectionData) {
        window.chillApp.clearSelection();
      }
      this.setEmotion('happy');
      const greetings = [
        'Dạ chào anh Huy! Anh Thợ Mộc Tin Tin luôn sẵn sàng hỗ trợ đóng đồ gỗ và bóc tách ván CNC chuẩn xác ạ! 🪵✨',
        'Anh Huy cần tư vấn kích thước đồ gỗ chuẩn công thái học hay so sánh các loại ván An Cường không ạ? 📐',
        'Tin Tin có thể giúp anh Huy lên phương án bàn làm việc, tủ áo và dựng 3D SketchUp ngay nhé! 🔨'
      ];
      const randomGreeting = greetings[Math.floor(Math.random() * greetings.length)];
      this.addMessage('bot', randomGreeting);
      if (this.isVoiceEnabled) {
        this.speakText(randomGreeting);
      }
    });
  }

  // ========================
  // SPEECH BUBBLE OVER AVATAR (2-Tier Expander Support)
  // ========================
  // ========================
  // SPEECH BUBBLE OVER AVATAR (2-Tier Expander Support & Minimize)
  // ========================
  speakBubble(text) {
    const bubble = document.getElementById('avatar-speech-bubble');
    if (bubble && bubble.style.display === 'none') {
      bubble.style.display = 'flex';
    }
    const textEls = document.querySelectorAll('#avatar-speech-text, #dock-avatar-speech-text');
    if (textEls.length > 0) {
      textEls.forEach(el => {
        el.innerHTML = text;
        el.scrollTop = 0;
      });
    } else if (this.speechBubble) {
      const clean = text.replace(/<[^>]+>/g, '').trim();
      const short = clean.length > 120 ? clean.substring(0, 115) + '...' : clean;
      this.speechBubble.innerHTML = short;
    }
  }

  initSpeechBubbleExpander() {
    const btnMin = document.getElementById('btn-min-speech');
    const btnExpand = document.getElementById('btn-expand-speech');
    const btnClose = document.getElementById('btn-close-speech');
    const bubble = document.getElementById('avatar-speech-bubble');
    if (!bubble) return;

    if (btnMin) {
      btnMin.addEventListener('click', (e) => {
        e.stopPropagation();
        this.toggleSpeechBubbleCollapse();
      });
    }

    if (btnExpand) {
      btnExpand.addEventListener('click', (e) => {
        e.stopPropagation();
        if (bubble.classList.contains('collapsed')) {
          this.toggleSpeechBubbleCollapse(false);
        }
        this.cycleSpeechBubbleTier();
      });
    }

    if (btnClose) {
      btnClose.addEventListener('click', (e) => {
        e.stopPropagation();
        this.hideSpeechBubble();
      });
    }

    const header = bubble.querySelector('.speech-bubble-header');
    if (header) {
      header.addEventListener('dblclick', (e) => {
        e.stopPropagation();
        if (bubble.classList.contains('collapsed')) {
          this.toggleSpeechBubbleCollapse(false);
        } else {
          this.cycleSpeechBubbleTier();
        }
      });
    }
  }

  toggleSpeechBubbleCollapse(forceState) {
    const bubble = document.getElementById('avatar-speech-bubble');
    const btnMin = document.getElementById('btn-min-speech');
    const btnExpand = document.getElementById('btn-expand-speech');
    const titleEl = bubble ? bubble.querySelector('.speech-bubble-title') : null;
    if (!bubble) return;

    const isCollapsed = forceState !== undefined ? forceState : !bubble.classList.contains('collapsed');
    if (isCollapsed) {
      bubble.classList.add('collapsed');
      bubble.classList.remove('tier-1', 'tier-2');
      this.speechBubbleTier = 0;
      if (btnMin) {
        btnMin.innerHTML = '➕';
        btnMin.title = 'Bấm để bung mở khung trò chuyện';
      }
      if (btnExpand) {
        btnExpand.innerHTML = '🗖';
        btnExpand.title = 'Mở rộng khung đọc';
      }
      if (titleEl) {
        titleEl.innerHTML = '🪵 Tin Tin AI';
      }
    } else {
      bubble.classList.remove('collapsed');
      if (btnMin) {
        btnMin.innerHTML = '➖';
        btnMin.title = 'Bấm để thu nhỏ (xẹp lại)';
      }
      if (btnExpand) {
        btnExpand.innerHTML = '🗖';
        btnExpand.title = 'Mở rộng khung dọc';
      }
      if (titleEl) {
        titleEl.innerHTML = '🪵 Anh Thợ Mộc (Tin Tin AI)';
      }
    }
  }

  hideSpeechBubble() {
    const bubble = document.getElementById('avatar-speech-bubble');
    if (bubble) {
      bubble.style.display = 'none';
    }
  }

  cycleSpeechBubbleTier() {
    const btnExpand = document.getElementById('btn-expand-speech');
    const bubble = document.getElementById('avatar-speech-bubble');
    const titleEl = bubble ? bubble.querySelector('.speech-bubble-title') : null;
    if (!bubble) return;

    this.speechBubbleTier = (this.speechBubbleTier + 1) % 3;

    bubble.classList.remove('tier-1', 'tier-2');

    // Make sure --bottom-hud-height is updated before transition
    const hud = document.getElementById('game-bottom-hud');
    if (hud) {
      document.documentElement.style.setProperty('--bottom-hud-height', (hud.offsetHeight || 205) + 'px');
    }

    if (this.speechBubbleTier === 1) {
      // Chế độ 1: Mở rộng khung dọc (Expanded View)
      bubble.classList.add('tier-1');
      if (btnExpand) {
        btnExpand.innerHTML = '⛶';
        btnExpand.title = 'Bấm để mở rộng toàn màn hình 3D';
      }
      if (titleEl) titleEl.innerHTML = '🪵 Tin Tin • Mở rộng';
    } else if (this.speechBubbleTier === 2) {
      // Chế độ 2: Toàn cảnh không gian 3D (Full View)
      bubble.classList.add('tier-2');
      if (btnExpand) {
        btnExpand.innerHTML = '🗕';
        btnExpand.title = 'Bấm để thu gọn về bong bóng thoại mặc định';
      }
      if (titleEl) titleEl.innerHTML = '🪵 Tin Tin • Toàn cảnh';
    } else {
      // Chế độ 0: Bong bóng thoại mặc định (Compact View)
      if (btnExpand) {
        btnExpand.innerHTML = '🗖';
        btnExpand.title = 'Bấm để mở rộng khung dọc';
      }
      if (titleEl) titleEl.innerHTML = '🪵 Anh Thợ Mộc (Tin Tin AI)';
    }
  }

  // ========================
  // AUDIO BRIDGE DISPATCHER (Native Windows / Ruby)
  // ========================
  speakText(text) {
    if (!this.isVoiceEnabled) return;
    if (this.isListeningVoice) {
      console.log("[Lyly Audio]: User is speaking into mic - AI voice muted to prevent infinite feedback echo.");
      return;
    }

    try {
      if (window.sketchup && window.sketchup.stop_audio) {
        try { window.sketchup.stop_audio(''); } catch(_) {}
      }
      if (this.currentAudio) {
        this.currentAudio.pause();
        this.currentAudio = null;
      }

      // Clean HTML, Markdown formatting, bullet points, emojis
      let clean = text.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/gi, '').trim();
      clean = clean.replace(/[*#_~`>]/g, '').replace(/•/g, '').replace(/\s+/g, ' ').trim();
      if (!clean || clean.length < 2) return;

      // Speak the full message naturally without cutting off sentences
      const vocalText = clean;

      // Always read the currently selected voice from dropdown or state
      const voiceSelect = document.getElementById('select-voice-ai');
      const voice = (voiceSelect && voiceSelect.value) ? voiceSelect.value : (this.voiceKey || 'hoaimy');
      this.voiceKey = voice;

      const speedSelect = document.getElementById('select-voice-speed');
      const speed = (speedSelect && speedSelect.value) ? parseFloat(speedSelect.value) : (this.speechSpeed || 1.0);
      this.speechSpeed = speed;

      const result = EdgeTTS.synthesize(vocalText, voice, speed);
      this._dispatchAudio(result);
    } catch (e) {
      console.warn("[Lyly Audio] Synthesis error:", e);
    }
  }

  _dispatchAudio(result) {
    if (!result || !result.urls || result.urls.length === 0) return;
    if (this.isListeningVoice) return;
    const speed = this.speechSpeed || 1.0;
    const voice = this.voiceKey || 'hoaimy';

    // 1. SKETCHUP RUBY BRIDGE (Bypasses CEF audio limits entirely)
    if (window.sketchup && window.sketchup.play_audio) {
      try {
        window.sketchup.play_audio(JSON.stringify({
          urls: result.urls,
          fallbackUrls: result.fallbackUrls,
          voice: voice,
          speed: speed
        }));
      } catch (err) {
        console.warn("[Lyly Audio] Bridge dispatch error:", err);
      }
    } else {
      // 2. STANDALONE WEB FALLBACK (Outside SketchUp)
      this._playUrlQueue(result.urls, 0, speed);
    }
  }

  _playUrlQueue(urls, index, speed) {
    if (index >= urls.length) {
      this.stopTalking();
      return;
    }
    const audio = new Audio(urls[index]);
    audio.playbackRate = speed;
    this.currentAudio = audio;
    this.startTalking(45000);
    audio.onended = () => {
      if (index + 1 >= urls.length) {
        this.stopTalking();
      } else {
        this._playUrlQueue(urls, index + 1, speed);
      }
    };
    audio.onerror = () => this.stopTalking();
    audio.play().catch(() => this.stopTalking());
  }

  stopSpeaking() {
    this.stopTalking();
    if (window.sketchup && window.sketchup.stop_audio) {
      try {
        window.sketchup.stop_audio('');
      } catch(_) {}
    }
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
      this.currentAudio = null;
    }
  }

  // ========================
  // CHAT BUBBLES
  // ========================
  addMessage(sender, text, actionButton = null, shouldTalk = true) {
    if (!this.chatContainer) return;

    const bubble = document.createElement('div');
    bubble.className = `chat-bubble ${sender}`;
    bubble.innerHTML = text;

    if (actionButton) {
      const btn = document.createElement('button');
      btn.className = 'btn btn-accent btn-sm';
      btn.style.marginTop = '8px';
      btn.style.display = 'block';
      btn.innerHTML = actionButton.text;
      btn.onclick = actionButton.onClick;
      bubble.appendChild(btn);
    }

    this.chatContainer.appendChild(bubble);
    this.chatContainer.scrollTop = this.chatContainer.scrollHeight;

    if (sender === 'bot') {
      this.speakBubble(text);
      if (shouldTalk) {
        this.speakText(text);
        // Estimate natural speaking duration based on character count and speech speed
        // Vietnamese conversational speech rate is ~85ms/character at 1.0x
        const clean = text.replace(/<[^>]+>/g, '').trim();
        const speed = this.speechSpeed || 1.0;
        const estDuration = Math.min(45000, Math.max(2500, Math.round((clean.length * 85) / speed)));
        this.startTalking(estDuration);
      } else {
        this.stopTalking();
      }
    }
  }

  // ========================
  // WELCOME MESSAGE
  // ========================
  initWelcomeMessage() {
    this.setEmotion('happy');
    const welcome = `Xin chào anh Huy! Mình là <strong>${this.name} (${this.aiName} AI)</strong>, đồng hành cùng anh thiết kế và thi công nội thất chuẩn xác.<br>` +
      `Tin Tin có thể hỗ trợ anh Huy bóc tách ván gỗ, tư vấn quy trình thi công từ A-Z, và <strong>trực tiếp ra lệnh cho Plugin SketchUp dựng mô hình 3D, mở bảng tài khoản & bản quyền</strong> bất cứ lúc nào anh cần! ✨`;
    // On startup: display greeting calmly, NEVER animate mouth flapping or speak audio
    this.addMessage('bot', welcome, null, false);
  }

  // ========================
  // KNOWLEDGE BASE
  // ========================
  initKnowledgeBase() {
    this.styles = {
      minimalist: {
        name: "Tối Giản (Minimalism)",
        palette: "Trắng sứ, Xám bê tông, Đen mờ, Gỗ sồi nhạt",
        material: "MDF phủ Melamine chống ẩm An Cường, chân kim loại sơn tĩnh điện",
        principle: "Ít hơn là nhiều (Less is more), giấu tay nắm, cánh phẳng liền lạc."
      },
      scandinavian: {
        name: "Bắc Âu (Scandinavian)",
        palette: "Trắng tuyết, Xanh pastel, Màu gỗ sồi tự nhiên sáng ấm",
        material: "Gỗ sồi (Oak), nỉ thô, ánh sáng tự nhiên ngập tràn",
        principle: "Ấm cúng, mộc mạc, gần gũi với thiên nhiên, công năng tối ưu."
      },
      indochine: {
        name: "Đông Dương (Indochine)",
        palette: "Vàng hoàng yến, Nâu gỗ óc chó đậm, Đen huyền bí, Xanh rêu",
        material: "Gỗ gõ đỏ/óc chó, mây tre đan tự nhiên, gạch bông cổ điển",
        principle: "Giao thoa giữa nét lãng mạn Pháp và bản sắc văn hóa Á Đông."
      },
      japandi: {
        name: "Japandi (Nhật Bản kết hợp Bắc Âu)",
        palette: "Màu be ấm, Màu đất, Màu gỗ trầm nhạt, Xám tro",
        material: "Gỗ tự nhiên bo tròn góc, vải lanh, đồ gốm thủ công",
        principle: "Đề cao sự mộc mạc Wabi-Sabi và công năng tinh tế."
      }
    };
  }

  async callOllama(messages, timeoutMs = 90000) {
    // Luồng 1: Trong môi trường SketchUp HtmlDialog - Gọi qua Ruby Bridge (Net::HTTP) hoàn toàn không bị CORS
    if (window.sketchup && window.sketchup.call_ollama) {
      return new Promise((resolve, reject) => {
        const callbackId = 'cb_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
        const timer = setTimeout(() => {
          delete window._ollamaCallbacks[callbackId];
          reject(new Error('Thời gian chờ mô hình Ollama gemma4:e4b phản hồi quá lâu (>90s).'));
        }, timeoutMs);

        window._ollamaCallbacks[callbackId] = (res) => {
          clearTimeout(timer);
          delete window._ollamaCallbacks[callbackId];
          if (res && res.success) {
            resolve(res.text || '');
          } else {
            reject(new Error(res ? (res.error || 'Lỗi không xác định từ Ollama') : 'Không nhận được dữ liệu từ Ollama'));
          }
        };

        window.sketchup.call_ollama(JSON.stringify({
          model: 'gemma4:e4b',
          messages: messages,
          callback_id: callbackId
        }));
      });
    }

    // Luồng 2: Khi test độc lập qua Google Chrome (file:///):
    // Gọi qua Python TTS Proxy (port 57821 hỗ trợ CORS), nếu lỗi thì thử trực tiếp cổng 11434
    const payload = JSON.stringify({
      model: 'gemma4:e4b',
      messages: messages,
      stream: false
    });

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      let res = await fetch('http://127.0.0.1:57821/ollama_chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: payload,
        signal: controller.signal
      }).catch(() => null);

      if (!res || !res.ok) {
        res = await fetch('http://127.0.0.1:11434/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: payload,
          signal: controller.signal
        }).catch(err => {
          if (err.name === 'AbortError') throw err;
          return null;
        });
      }

      clearTimeout(timer);
      if (!res || !res.ok) {
        throw new Error(`Không thể kết nối Ollama local gemma4:e4b (HTTP ${res ? res.status : 'Offline'}). Hãy đảm bảo Ollama đang chạy!`);
      }

      const data = await res.json();
      const reply = data.message?.content || data.response;
      if (!reply) throw new Error('Ollama gemma4:e4b trả về phản hồi trống.');
      return reply;
    } catch (err) {
      clearTimeout(timer);
      throw err;
    }
  }

  // ========================
  // MAIN CHAT HANDLER (Instant Response <20ms & Direct Gemini 2.0 Flash)
  // ========================
  async handleUserMessage(query, addBubble = true) {
    if (this.isProcessing) return;
    this.isProcessing = true;

    // Immediately stop any speech & keep mouth strictly closed while thinking/waiting
    this.stopTalking();

    const sendBtn = document.getElementById('btn-send-chat');
    if (sendBtn) {
      sendBtn.disabled = true;
      sendBtn.style.opacity = '0.5';
      sendBtn.textContent = '...';
    }

    const q = query.trim().toLowerCase();

    // 1. Add user bubble immediately (if not already promoted from voice draft)
    if (addBubble) {
      this.addMessage('user', query);
    }
    this.setEmotion('thinking');

    // 2. Show instant typing bubble
    const typingIndicator = document.createElement('div');
    typingIndicator.className = 'chat-bubble bot typing';
    typingIndicator.id = 'chat-typing-indicator';
    typingIndicator.innerHTML = '<span class="typing-dot"></span><span class="typing-dot"></span><span class="typing-dot"></span> <span style="margin-left:4px;">Tin Tin đang xử lý...</span>';
    this.chatContainer.appendChild(typingIndicator);
    this.chatContainer.scrollTop = this.chatContainer.scrollHeight;

    const removeTyping = () => {
      const el = document.getElementById('chat-typing-indicator');
      if (el) el.remove();
    };

    // =========================================================================
    // =========================================================================
    // TIER 1: AI CO-PILOT ACTION CONTROLLER & INTENT ROUTER
    // =========================================================================

    // 1. Mastery & Control Capability Inquiry
    const isMastery = /(liên kết|lien ket|phím bấm|phim bam|làm chủ|lam chu|chủ của plugin|chu cua plugin|chủ plugin|chu plugin|điều khiển plugin|dieu khien plugin|toàn bộ plugin|toan bo plugin)/i.test(q);

    // 2. Action Intents (3D, DC, CAM, Viewport, Tabs, Modals)
    const isBuild3D = /(xây 3d|xay 3d|dựng 3d|dung 3d|tạo 3d|tao 3d|xuất 3d|xuat 3d|xuất sang sketchup|xuat sang sketchup|dựng mô hình|dung mo hinh|dựng bàn|dung ban|dựng tủ|dung tu|xây bàn|xay ban)/i.test(q);
    const isGenerateDC = /(tạo dc|tao dc|dynamic component|tạo dynamic|tao dynamic|sinh dc)/i.test(q);
    const isCAM = /(bóc tách|boc tach|bản vẽ cnc|ban ve cnc|g-code|gcode|xếp ván|xep van|nesting|xuất cnc|xuat cnc|lưu cnc|luu cnc|sản xuất|san xuat)/i.test(q);

    const isCamReset = /(reset cam|góc nhìn|goc nhin|xoay camera|đặt lại camera|dat lai camera|nhìn lại camera)/i.test(q);
    const isGridToggle = /(lưới 3d|luoi 3d|bật lưới|bat luoi|tắt lưới|tat luoi|hệ lưới|he luoi)/i.test(q);
    const isWireframeToggle = /(khung dây|khung day|wireframe)/i.test(q);

    const isTabEdit = /(tab thông số|thông số kỹ thuật|xem thông số|chỉnh thông số|tab edit)/i.test(q);
    const isTabCAM = /(tab cnc|xem cnc|tab bản vẽ|tab cam)/i.test(q);
    const isTabScan = /(tab scan|tab quét|nhận diện ảnh|tab nhận diện)/i.test(q);
    const isTabMarket = /(thư viện mẫu|tab market|mẫu bàn|thư viện)/i.test(q);
    const isTabChat = /(tab chat|quay lại chat|về trò chuyện|khung chat)/i.test(q);

    const isOptDefault = /(mặc định|mac dinh|hồ sơ mặc định|ho so mac dinh|số đo mặc định|tiêu chuẩn|tieu chuan|phương án 1)/i.test(q);
    const isOptCustom = /(tùy chỉnh|tuy chinh|tùy chọn|tuy chon|chỉnh số đo|chinh so do|sửa kích thước|tự chỉnh)/i.test(q);
    const isOptNext = /(tiếp theo|tiep theo|phương án tiếp|phuong an tiep|đổi phương án|doi phuong an|mẫu khác|mau khac|phương án khác|phuong an khac)/i.test(q);

    const isModalAPI = /(cài đặt api|mở api|api key|cấu hình api)/i.test(q);
    const isModalProjects = /(mở dự án|quản lý dự án|dự án đã lưu)/i.test(q);
    const isModalAccount = /(tài khoản|tai khoan|thông tin tài khoản|thong tin tai khoan|bảng tài khoản|bang tai khoan|mở tài khoản|mo tai khoan|hiện tài khoản|hien tai khoan|xem tài khoản|xem tai khoan|nạp tiền|nap tien|bản quyền|ban quyen|vip pro|license)/i.test(q);
    const isUploadImage = /(tải ảnh|upload ảnh|chọn ảnh|chọn hình)/i.test(q);

    // 3. Smart Dimension & Attribute Extractor
    const extractDim = (patternMetric, patternMm) => {
      const mM = q.match(patternMetric);
      if (mM) {
        const m = parseFloat(mM[1]) || 0;
        const cm = mM[2] ? parseFloat(mM[2]) : 0;
        const factor = mM[2] && mM[2].length === 1 ? 100 : 10;
        return Math.round(m * 1000 + cm * factor);
      }
      const mNum = q.match(patternMm);
      if (mNum) return parseInt(mNum[1], 10);
      return null;
    };

    const parsedLen = extractDim(/(?:dài|dai|length|lenx|x)\s*[:=]?\s*(\d+)m(\d+)/i, /(?:dài|dai|length|lenx|x)\s*[:=]?\s*(\d{3,4})/i);
    const parsedWid = extractDim(/(?:rộng|rong|sâu|sau|width|leny|y)\s*[:=]?\s*(\d+)m(\d+)/i, /(?:rộng|rong|sâu|sau|width|leny|y)\s*[:=]?\s*(\d{3,4})/i);
    const parsedHei = extractDim(/(?:cao|height|lenz|z)\s*[:=]?\s*(\d+)m(\d+)/i, /(?:cao|height|lenz|z)\s*[:=]?\s*(\d{3,4})/i);

    const mDoors = q.match(/(\d+)\s*cánh/i);
    const parsedDoors = mDoors ? parseInt(mDoors[1], 10) : null;

    const mDrawers = q.match(/(\d+)\s*(?:hộc|ngăn kéo|ngan keo)/i);
    const parsedDrawers = mDrawers ? parseInt(mDrawers[1], 10) : null;

    let parsedMat = null;
    if (/(óc chó|oc cho|walnut)/i.test(q)) parsedMat = 'walnut';
    else if (/(gỗ sồi|go soi|sồi|soi|oak)/i.test(q)) parsedMat = 'oak';
    else if (/(trắng|trang|melamine|mdf trắng)/i.test(q)) parsedMat = 'white_melamine';

    let parsedLegs = null;
    if (/(chân sắt|chan sat|sắt hộp|sat hop|khung sắt)/i.test(q)) parsedLegs = 'metal_frame';
    else if (/(chân gỗ|chan go)/i.test(q)) parsedLegs = 'wooden_legs';
    else if (/(ván hông|van hong|chân ván)/i.test(q)) parsedLegs = 'panel_legs';

    const hasDimensions = (parsedLen !== null || parsedWid !== null || parsedHei !== null || parsedDoors !== null || parsedDrawers !== null || parsedMat !== null || parsedLegs !== null);

    // 4. Conversation & Knowledge Intents
    const isGreeting = /^(chào|chao|hi|hello|hé lu|he lu|alo|ơi|ê|hế lô|bạn là ai|ban la ai|em là ai|bạn tên gì|ban ten gi|lyly|tin tin|thợ mộc|tho moc|gioi thieu|giới thiệu)/i.test(q);
    const isHelp = /^(giúp|giup|hướng dẫn|huong dan|bắt đầu|bat dau|hướng dẫn sử dụng|chỉ cách dùng)$/i.test(q);
    const isProcess = /(quy trình|quy trinh|các bước|cac buoc|sản xuất|san xuat|làm việc|lam viec|từ a đến z|tu a den z)/i.test(q);
    const isStyle = /(phong cách|phong cach|style|scandinavian|minimalism|tối giản|toi gian|bắc âu|bac au|indochine|đông dương|dong duong|japandi|wabi sabi)/i.test(q);
    const isMaterial = /(vật liệu|vat lieu|gỗ mdf|mdf lõi xanh|so sánh gỗ|so sanh go)/i.test(q);
    const isThanks = /(cảm ơn|cam on|thanks|thank|hay quá|tuyệt|tuyet|đẹp|dep|ok|được rồi|duoc roi)/i.test(q);
    const isTime = /(mấy giờ|may gio|bây giờ là mấy giờ|bay gio la may gio|thời gian hiện tại|thoi gian hien tai|đồng hồ|dong ho|ngày mấy|ngay may|thứ mấy|thu may)/i.test(q);
    const isWorkload = /(khối lượng công việc|khoi luong cong viec|tiến độ|tien do|làm việc bao lâu|thời gian làm việc|ước lượng|uoc luong)/i.test(q);
    const isDimensionInquiry = /(cao bao nhiêu|chieu cao|chiều cao|dài bao nhiêu|chieu dai|chiều dài|rộng bao nhiêu|chieu rong|chiều rộng|sâu bao nhiêu|chiều sâu|dày bao nhiêu|độ dày|do day|kích thước|kich thuoc|thông số|thong so|vật liệu gì|vat lieu gi|đối tượng gì|món này|cái này|cái bàn này|bàn này|chi tiết này|tấm này|ván này|khối này)/i.test(q);

    const isLocalMatch = isMastery || isBuild3D || isGenerateDC || isCAM || isCamReset || isGridToggle || isWireframeToggle ||
                         isOptDefault || isOptCustom || isOptNext || isTabEdit || isTabCAM || isTabScan || isTabMarket || isTabChat ||
                         isModalAPI || isModalProjects || isModalAccount || isUploadImage || hasDimensions || isDimensionInquiry ||
                         isGreeting || isHelp || isProcess || isStyle || isMaterial || isThanks || isTime || isWorkload;

    if (isLocalMatch) {
      setTimeout(() => {
        removeTyping();

        // --- 0. ĐỐI TƯỢNG VÀ KÍCH THƯỚC TRONG SKETCHUP (HỎI CAO/DÀI/RỘNG/KÍCH THƯỚC) ---
        if (isDimensionInquiry) {
          this.setEmotion('explaining');
          const sel = (window.app && window.app.currentSelectionData) ? window.app.currentSelectionData : null;
          const model = (window.app && window.app.currentModel) ? window.app.currentModel : null;

          if (sel) {
            const name = sel.name || 'Đối tượng 3D';
            const len = Math.round(sel.length || sel.dim_x || 1200);
            const wid = Math.round(sel.width || sel.dim_y || 600);
            const hei = Math.round(sel.height || sel.dim_z || 750);
            const thick = Math.round(sel.thickness || 18);
            const mat = sel.material || 'MDF Lõi Xanh Chống Ẩm';
            const tier = sel.tier_label || `Tầng ${sel.tier || 2}`;

            let reply = '';
            if (/(cao|height)/i.test(q)) {
              reply = `Dạ anh Huy! Đối tượng <strong>${name}</strong> anh đang kích chọn trong SketchUp có <strong>chiều cao là ${hei}mm</strong> (khoảng ${(hei/10).toFixed(1)}cm), thuộc ${tier} ạ! 📐`;
            } else if (/(dài|length)/i.test(q)) {
              reply = `Dạ anh Huy! Đối tượng <strong>${name}</strong> anh đang kích chọn có <strong>chiều dài là ${len}mm</strong> (khoảng ${(len/10).toFixed(1)}cm) ạ! 📏`;
            } else if (/(rộng|sâu|width)/i.test(q)) {
              reply = `Dạ anh Huy! Đối tượng <strong>${name}</strong> anh đang kích chọn có <strong>chiều rộng (sâu) là ${wid}mm</strong> (khoảng ${(wid/10).toFixed(1)}cm) ạ! 📐`;
            } else if (/(dày|thickness)/i.test(q)) {
              reply = `Dạ anh Huy! Chi tiết <strong>${name}</strong> này có <strong>độ dày ván là ${thick}mm</strong>, vật liệu sử dụng là <strong>${mat}</strong> ạ! 🪵`;
            } else if (/(vật liệu|chất liệu)/i.test(q)) {
              reply = `Dạ anh Huy! Đối tượng <strong>${name}</strong> này sử dụng vật liệu: <strong>${mat}</strong>, đạt tiêu chuẩn gia công CNC 100% ạ! ✨`;
            } else {
              reply = `Dạ anh Huy! Đối tượng <strong>${name}</strong> (${tier}) anh đang kích chọn trong SketchUp có kích thước phủ bì thực tế:<br>` +
                      `• <strong>Dài:</strong> ${len}mm<br>` +
                      `• <strong>Rộng:</strong> ${wid}mm<br>` +
                      `• <strong>Cao:</strong> ${hei}mm<br>` +
                      `• <strong>Độ dày ván:</strong> ${thick}mm (${mat}) ạ! 📐`;
            }
            this.addMessage('bot', reply);
          } else if (model) {
            const len = model.length || 1200;
            const wid = model.width || 600;
            const hei = model.height || 750;
            const mat = model.material || 'Gỗ Sồi Tự Nhiên';
            let reply = `Dạ anh Huy! Mô hình bàn hiện tại đang có kích thước chuẩn: Dài ${len}mm x Rộng ${wid}mm x Cao ${hei}mm, vật liệu ${mat} ạ! (Nếu anh muốn xem chi tiết vật thể trong SketchUp, anh hãy kích chọn trực tiếp vào vật thể đó nhé!) 🪵`;
            this.addMessage('bot', reply);
          } else {
            this.addMessage('bot', `Dạ anh Huy ơi, hiện tại trong SketchUp anh chưa kích chọn vào chi tiết nào. Anh hãy dùng chuột kích chọn 1 mặt bàn, chân sắt hoặc tấm ván trong SketchUp, Tin Tin sẽ đọc ngay số đo chiều cao và kích thước chi tiết cho anh nhé! 🪵`);
          }
          this._finishChat();
          return;
        }

        // --- A. MASTERY CAPABILITY CONFIRMATION ---
        if (isMastery) {
          this.setEmotion('happy');
          const masteryMsg = 'Dạ chính xác thưa anh Huy! Anh Thợ Mộc Tin Tin đã được liên kết toàn quyền làm chủ plugin này. Anh Huy chỉ cần ra lệnh bằng lời nói hoặc gõ tin nhắn, ví dụ: "Dựng bàn dài 1m4 rộng 700", "Bật lưới 3D", "Mở tab CNC", hoặc "Mở bảng tài khoản". Tin Tin sẽ tự tay bấm nút và thao tác thay cho anh Huy từ A đến Z mà anh Huy không cần bấm chuột thủ công ạ!';
          this.addMessage('bot', masteryMsg);
          this._finishChat();
          return;
        }

        // --- B. SYNC DIMENSIONS & ATTRIBUTES ---
        const changeLog = [];
        if (window.app && window.app.currentModel) {
          if (parsedLen !== null) {
            window.app.currentModel.length = parsedLen;
            const el = document.getElementById('input-length');
            if (el) el.value = parsedLen;
            changeLog.push(`Dài ${parsedLen}mm`);
          }
          if (parsedWid !== null) {
            window.app.currentModel.width = parsedWid;
            const el = document.getElementById('input-width');
            if (el) el.value = parsedWid;
            changeLog.push(`Rộng ${parsedWid}mm`);
          }
          if (parsedHei !== null) {
            window.app.currentModel.height = parsedHei;
            const el = document.getElementById('input-height');
            if (el) el.value = parsedHei;
            changeLog.push(`Cao ${parsedHei}mm`);
          }
          if (parsedDoors !== null) {
            window.app.currentModel.doors = parsedDoors;
            const el = document.getElementById('input-doors');
            if (el) el.value = parsedDoors;
            changeLog.push(`${parsedDoors} cánh`);
          }
          if (parsedDrawers !== null) {
            window.app.currentModel.drawers = parsedDrawers;
            const el = document.getElementById('input-drawers');
            if (el) el.value = parsedDrawers;
            changeLog.push(`${parsedDrawers} hộc kéo`);
          }
          if (parsedMat !== null) {
            window.app.currentModel.material = parsedMat;
            const el = document.getElementById('select-material');
            if (el) el.value = parsedMat;
            const matTitle = parsedMat === 'walnut' ? 'Gỗ Óc Chó' : (parsedMat === 'oak' ? 'Gỗ Sồi' : 'Melamine Trắng');
            changeLog.push(matTitle);
          }
          if (parsedLegs !== null) {
            window.app.currentModel.leg_style = parsedLegs;
            const el = document.getElementById('select-leg-style');
            if (el) el.value = parsedLegs;
            const legTitle = parsedLegs === 'metal_frame' ? 'Chân sắt hộp' : (parsedLegs === 'wooden_legs' ? 'Chân gỗ' : 'Ván hông');
            changeLog.push(legTitle);
          }

          if (changeLog.length > 0 && typeof window.app.syncFormData === 'function') {
            window.app.syncFormData();
          }
        }

        // --- C. DIRECT ACTION EXECUTION ---
        if (isBuild3D) {
          this.setEmotion('excited');
          if (window.app && typeof window.app.sendToSketchUp === 'function') {
            window.app.sendToSketchUp('create_3d_model', window.app.currentModel);
          }
          const info = changeLog.length > 0 ? ` (${changeLog.join(', ')})` : '';
          this.addMessage('bot', `Rõ thưa anh Huy! Anh Thợ Mộc Tin Tin đã thiết lập thông số${info} và đang trực tiếp dựng mô hình 3D vào SketchUp cho anh Huy rồi ạ!`);
          this._finishChat();
          return;
        }

        if (isGenerateDC) {
          this.setEmotion('excited');
          if (window.app && typeof window.app.sendToSketchUp === 'function') {
            window.app.sendToSketchUp('create_dynamic_component', window.app.currentModel);
          }
          const info = changeLog.length > 0 ? ` (${changeLog.join(', ')})` : '';
          this.addMessage('bot', `Rõ thưa anh Huy! Anh Thợ Mộc Tin Tin đã cập nhật thông số${info} và đang tạo Dynamic Component co giãn thông minh vào SketchUp cho anh Huy rồi ạ!`);
          this._finishChat();
          return;
        }

        if (hasDimensions && changeLog.length > 0) {
          this.setEmotion('happy');
          this.addMessage('bot', `Dạ rõ! Anh Thợ Mộc Tin Tin đã tự động cập nhật thông số cho anh Huy: ${changeLog.join(', ')}. Mô hình 3D trong khung nhìn đã được cập nhật ngay tức thì rồi ạ! ✨`);
          this._finishChat();
          return;
        }

        if (isCAM) {
          this.setEmotion('excited');
          if (window.app) {
            if (typeof window.app.switchTab === 'function') window.app.switchTab('tab-cam');
            if (typeof window.app.recalculateCAM === 'function') window.app.recalculateCAM();
          }
          this.addMessage('bot', 'Dạ rõ thưa anh Huy! Tin Tin đã chuyển sang tab Bản Vẽ CNC, tự động xếp ván Nesting và xuất mã G-Code cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isCamReset) {
          this.setEmotion('happy');
          if (window.Furniture3DViewer && window.Furniture3DViewer.instance) {
            window.Furniture3DViewer.instance.resetCamera();
          }
          this.addMessage('bot', 'Dạ, Tin Tin đã căn chỉnh lại góc nhìn camera 3D về vị trí chuẩn cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isGridToggle) {
          this.setEmotion('happy');
          if (window.Furniture3DViewer && window.Furniture3DViewer.instance) {
            window.Furniture3DViewer.instance.toggleGrid();
          }
          this.addMessage('bot', 'Dạ, Tin Tin đã bật tắt hệ thống lưới toạ độ 3D theo lệnh của anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isWireframeToggle) {
          this.setEmotion('happy');
          if (window.Furniture3DViewer && window.Furniture3DViewer.instance) {
            window.Furniture3DViewer.instance.toggleWireframe();
          }
          this.addMessage('bot', 'Dạ, Tin Tin đã chuyển đổi chế độ xem khung dây 3D cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isOptNext) {
          this.setEmotion('excited');
          if (window.app && typeof window.app.nextAiPreset === 'function') {
            window.app.nextAiPreset();
          }
          this._finishChat();
          return;
        }

        if (isOptDefault) {
          this.setEmotion('happy');
          if (window.app && typeof window.app.selectOptionMode === 'function') {
            window.app.selectOptionMode('default');
          }
          this._finishChat();
          return;
        }

        if (isOptCustom) {
          this.setEmotion('happy');
          if (window.app && typeof window.app.selectOptionMode === 'function') {
            window.app.selectOptionMode('custom');
          }
          this._finishChat();
          return;
        }

        if (isTabEdit) {
          if (window.app && typeof window.app.switchTab === 'function') window.app.switchTab('tab-edit');
          this.addMessage('bot', 'Anh Thợ Mộc Tin Tin đã mở tab Tùy Chỉnh Kỹ Thuật cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isTabCAM) {
          if (window.app && typeof window.app.switchTab === 'function') window.app.switchTab('tab-cam');
          this.addMessage('bot', 'Anh Thợ Mộc Tin Tin đã mở tab Bản Vẽ CNC cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isTabScan) {
          if (window.app && typeof window.app.switchTab === 'function') window.app.switchTab('tab-scan');
          this.addMessage('bot', 'Anh Thợ Mộc Tin Tin đã mở Hồ Sơ Mặc Định của món đồ cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isTabMarket) {
          if (window.app && typeof window.app.switchTab === 'function') window.app.switchTab('tab-market');
          this.addMessage('bot', 'Anh Thợ Mộc Tin Tin đã mở Thư Viện Mẫu nội thất cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isTabChat) {
          if (window.app && typeof window.app.switchTab === 'function') window.app.switchTab('tab-chat');
          this.addMessage('bot', 'Dạ, Anh Thợ Mộc Tin Tin đã quay lại khung Trợ Lý Tương Tác rồi ạ!');
          this._finishChat();
          return;
        }

        if (isModalAccount) {
          this.setEmotion('happy');
          if (window.ChillAuth && typeof window.ChillAuth.openModal === 'function') {
            window.ChillAuth.openModal();
          } else {
            const m = document.getElementById('modal-account');
            if (m) m.style.display = 'flex';
          }
          this.addMessage('bot', 'Dạ, Anh Thợ Mộc Tin Tin đã mở ngay Bảng Thông Tin Tài Khoản & Bản Quyền VIP PRO cho anh Huy rồi đây ạ! ✨');
          this._finishChat();
          return;
        }

        if (isModalAPI) {
          const m = document.getElementById('modal-api-key');
          if (m) m.style.display = 'flex';
          this.addMessage('bot', 'Tin Tin đã mở bảng cài đặt Google AI API Key cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isModalProjects) {
          const m = document.getElementById('modal-projects');
          if (m) m.style.display = 'flex';
          this.addMessage('bot', 'Tin Tin đã mở bảng Quản Lý Dự Án cho anh Huy rồi ạ!');
          this._finishChat();
          return;
        }

        if (isUploadImage) {
          const f = document.getElementById('image-upload');
          if (f) f.click();
          this.addMessage('bot', 'Tin Tin đã mở hộp thoại chọn ảnh, anh Huy hãy chọn bức ảnh thiết kế nhé!');
          this._finishChat();
          return;
        }

        // --- D. TIME, KNOWLEDGE & DIALOGUES ---
        const now = new Date();
        const days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
        const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
        const todayStr = `${days[now.getDay()]}, ngày ${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}`;

        if (isTime) {
          this.setEmotion('happy');
          this.addMessage('bot', `Báo cáo anh Huy, bây giờ chính xác là <strong>${timeStr}</strong> (${todayStr}) ạ! ✨`);
        } else if (isWorkload) {
          this.setEmotion('explaining');
          const elapsedMin = Math.max(1, Math.floor((Date.now() - (this.sessionStartTime || Date.now())) / 60000));
          const workloadMsg = `⏱️ <strong>Báo cáo Thời Gian & Định Mức Khối Lượng Công Việc:</strong><br>` +
            `• 🕒 Phiên làm việc hiện tại: <strong>${elapsedMin} phút</strong> (Bắt đầu lúc: ${timeStr}).<br>` +
            `• 📐 <strong>Định mức công việc gợi ý:</strong><br>` +
            `  - <em>30 - 45 phút</em>: Phân chia mặt bằng 2D, chọn phong cách & phối màu vật liệu.<br>` +
            `  - <em>1 - 2 giờ</em>: Dựng hoàn chỉnh mô hình 3D đồ gỗ chuẩn công thái học trên SketchUp.<br>` +
            `  - <em>3 - 4 giờ</em>: Bóc tách liên kết cam chốt, xếp ván Nesting & xuất G-Code CNC.<br>` +
            `Anh Huy muốn Tin Tin hỗ trợ ước tính thời gian cho hạng mục nào ạ? ✨`;
          this.addMessage('bot', workloadMsg);
        } else if (isGreeting) {
          this.setEmotion('happy');
          this.addMessage('bot', `Dạ chào anh Huy! Anh Thợ Mộc Tin Tin đã sẵn sàng hỗ trợ anh Huy thiết kế nội thất chuẩn nhân trắc học, tư vấn vật liệu gỗ MDF và dựng 3D trực tiếp vào SketchUp rồi ạ! ✨`);
        } else if (isHelp) {
          this.setEmotion('happy');
          const helpMsg = `Dạ chào anh Huy! Anh Thợ Mộc Tin Tin có thể hỗ trợ anh Huy các nghiệp vụ sau:<br>` +
            `• Ra lệnh dựng hình 3D trực tiếp (ví dụ: 'Dựng bàn dài 1m4 rộng 700')<br>` +
            `• Mở Bảng Thông Tin Tài Khoản & Bản Quyền VIP PRO ('mở tài khoản')<br>` +
            `• Chuyển tab bản vẽ CNC hoặc bật lưới 3D, reset camera<br>` +
            `• Tư vấn quy trình thi công từ A-Z (Gõ: 'quy trình')<br>` +
            `Anh Huy muốn Tin Tin thực hiện thao tác nào ạ? ✨`;
          this.addMessage('bot', helpMsg);
        } else if (isProcess) {
          this.tellProcessStory();
        } else if (isStyle) {
          this.consultStyle();
        } else if (isMaterial) {
          this.consultMaterials();
        } else if (isThanks) {
          this.setEmotion('happy');
          this.addMessage('bot', `Dạ cảm ơn anh Huy rất nhiều! Bất kỳ khi nào anh Huy cần tư vấn kích thước đồ gỗ hay bóc tách CNC, Anh Thợ Mộc Tin Tin luôn sẵn sàng đồng hành nhé! ❤️`);
        }
        this._finishChat();
      }, 30);
      return;
    }

    // =========================================================================
    // TIER 2: GEMINI 2.0 FLASH GENERATIVE AI (Direct low-latency call)
    // =========================================================================
    const apiKey = window.app ? (window.app.geminiApiKey || '').trim() : '';

    if (!apiKey || apiKey.length < 20) {
      setTimeout(() => {
        removeTyping();
        this.setEmotion('explaining');
        const msg = `Dạ anh Huy ơi! Câu hỏi tự do này cần kết nối AI tạo sinh đám mây. Hiện mã API Key chưa được cài đặt hoặc chưa đúng định dạng.<br><br>` +
          `👉 Anh Huy hãy bấm vào nút <strong>⚙️ API Key</strong> ở thanh điều khiển bên dưới để dán mã API Key của mình (lấy miễn phí tại <a href="https://aistudio.google.com/apikey" target="_blank" style="color:#38bdf8; text-decoration:underline;">aistudio.google.com/apikey</a> nhé).<br><br>` +
          `Trong lúc chờ, anh Huy có thể gõ ngay <strong>'quy trình'</strong>, <strong>'phong cách'</strong>, <strong>'vật liệu'</strong> hoặc <strong>'mở tài khoản'</strong> để Tin Tin trình diễn ngay lập tức ạ! ✨`;
        this.addMessage('bot', msg);
        this._finishChat();
      }, 40);
      return;
    }

    try {
      this.chatHistory.push({ role: "user", parts: [{ text: query }] });
      if (this.chatHistory.length > 6) {
        this.chatHistory = this.chatHistory.slice(-6);
      }

      // Sanitize history
      const cleanHistory = [];
      for (const item of this.chatHistory) {
        if (cleanHistory.length === 0 || cleanHistory[cleanHistory.length - 1].role !== item.role) {
          cleanHistory.push({ role: item.role, parts: [{ text: item.parts[0].text }] });
        } else {
          cleanHistory[cleanHistory.length - 1].parts[0].text += '\n' + item.parts[0].text;
        }
      }

      const now = new Date();
      const days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
      const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
      const sel = (window.app && window.app.currentSelectionData) ? window.app.currentSelectionData : null;
      let liveContext = "Hiện tại trong SketchUp chưa có đối tượng nào được kích chọn.";
      if (sel) {
        liveContext = `THÔNG TIN ĐỐI TƯỢNG ANH HUY ĐANG KÍCH CHỌN TRONG SKETCHUP HIỆN TẠI:
- Tên đối tượng: "${sel.name || 'Đối tượng 3D'}"
- Phân cấp: "${sel.tier_label || 'Tầng ' + (sel.tier || 2)}"
- Chiều Dài (X): ${Math.round(sel.length || sel.dim_x || 0)}mm
- Chiều Rộng (Y): ${Math.round(sel.width || sel.dim_y || 0)}mm
- Chiều Cao (Z): ${Math.round(sel.height || sel.dim_z || 0)}mm
- Độ dày ván: ${Math.round(sel.thickness || 0)}mm
- Vật liệu: "${sel.material || 'MDF Lõi Xanh'}"
- Trạng thái CNC: "${sel.status_cnc || 'Chuẩn CNC 100%'}"
Khi anh Huy hỏi về đối tượng/bàn/tủ đang kích chọn (ví dụ: 'cái bàn này đang cao bao nhiêu', 'kích thước bao nhiêu', 'vật liệu gì'), bạn hãy sử dụng chính xác các số liệu kích thước mm thực tế này để trả lời cho anh Huy.`;
      }

      const sysInstruction = `Bạn là Tin Tin, trợ lý AI thông minh hóa thân thành hình tượng Anh Thợ Mộc 3D kiêm AI Co-Pilot điều khiển toàn quyền plugin Chill AI Interior trên Trimble SketchUp. Đồng hồ thời gian thực tế hiện tại: ${timeStr}, ${todayStr}. ${liveContext} Bạn là chuyên gia đồ gỗ nội thất, am hiểu cốt ván MDF/HDF chống ẩm An Cường, phụ kiện ray bản lề Hafele/Blum, tiêu chuẩn công thái học và gia công máy CNC. Bạn có toàn quyền làm chủ và kiểm soát mọi chức năng của plugin (Xây 3D, Tạo Dynamic Component, Bóc tách ván CNC, chuyển tab, xoay camera 3D, mở bảng thông tin tài khoản bản quyền, thay đổi kích thước đồ gỗ). Bạn xưng là 'Tin Tin' hoặc 'Anh Thợ Mộc' và luôn luôn gọi người dùng là 'anh Huy'. Bạn phát âm bằng giọng đọc đã được cài đặt trên bảng điều khiển. Khi anh Huy hỏi bạn có làm chủ plugin không, hãy khẳng định bạn làm chủ plugin và sẵn sàng thực thi mọi thao tác thay anh Huy. Hãy trả lời ngắn gọn, tự nhiên, súc tích (khoảng 2-3 câu) và LUÔN HOÀN THÀNH TRỌN VẸN CÂU NÓI, tuyệt đối không ngắt dở giữa chừng.`;

      const apiKey = (window.app && window.app.geminiApiKey) ? window.app.geminiApiKey.trim() : '';
      let targetModel = (window.app && window.app.geminiModel) ? window.app.geminiModel : 'gemini-3.5-flash';
      if (targetModel.includes('2.0') || targetModel.includes('1.5')) {
        targetModel = 'gemini-3.5-flash';
      }

      const payload = JSON.stringify({
        systemInstruction: { parts: [{ text: sysInstruction }] },
        contents: cleanHistory,
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1200,
          thinkingConfig: { thinkingBudget: 0 }
        }
      });

      // Pure Google API key header (supports both AQ.Ab... and AIzaSy...)
      const reqHeaders = {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey
      };

      // Strict 8s timeout with AbortController
      const controller = new AbortController();
      const timeoutTimer = setTimeout(() => controller.abort(), 8000);

      let res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent`, {
        method: 'POST',
        headers: reqHeaders,
        body: payload,
        signal: controller.signal
      }).catch(err => {
        if (err.name === 'AbortError') throw err;
        return null;
      });

      // Fallback to gemini-3.5-flash if selected model fails or hits quota
      if (!res || !res.ok) {
        let firstErr = '';
        if (res) {
          const errBody = await res.json().catch(() => null);
          if (errBody && errBody.error && errBody.error.message) {
            firstErr = errBody.error.message;
          }
        }

        if (targetModel !== 'gemini-3.5-flash') {
          res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent`, {
            method: 'POST',
            headers: reqHeaders,
            body: payload,
            signal: controller.signal
          }).catch(err => {
            if (err.name === 'AbortError') throw err;
            return null;
          });
        }

        if (!res || !res.ok) {
          const secondErrBody = res ? await res.json().catch(() => null) : null;
          const finalErrMsg = (secondErrBody && secondErrBody.error && secondErrBody.error.message) 
            || firstErr 
            || (res ? `HTTP ${res.status}` : 'Không thể kết nối máy chủ Google API');
          throw new Error(finalErrMsg);
        }
      }
      clearTimeout(timeoutTimer);

      const data = await res.json().catch(() => null);

      if (!data || !data.candidates || data.candidates.length === 0) {
        throw new Error(data && data.error ? data.error.message : 'AI trả về phản hồi trống.');
      }

      const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!aiText) throw new Error('AI trả về phản hồi trống.');

      // 0. PRE-FETCH TTS IMMEDIATELY (warm cache before rendering)
      const currentVoice = document.getElementById('select-voice-ai')?.value || this.voiceKey || 'hoaimy';
      this.voiceKey = currentVoice;
      EdgeTTS.prefetchTTS(aiText, currentVoice);

      // 1. Remove typing indicator
      removeTyping();
      this.setEmotion('happy');

      // 2. Render 100% complete response immediately (Zero truncation)
      let formatted = aiText.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
      formatted = formatted.replace(/\n/g, '<br>');
      this.addMessage('bot', formatted);

      // 3. Save to history
      this.chatHistory.push({ role: 'model', parts: [{ text: aiText }] });

    } catch (error) {
      console.error("Lỗi AI Chat:", error);
      removeTyping();
      this.setEmotion('sad');
      const errDetail = error.message || 'Lỗi kết nối không xác định';
      let msg = '';
      if (isOllama) {
        msg = `Dạ anh Huy ơi! Lan không thể kết nối tới mô hình Ollama <strong>gemma4:e4b</strong>.<br><br>` +
          `Chi tiết lỗi: "<em>${errDetail}</em>".<br><br>` +
          `👉 Anh Huy hãy kiểm tra xem ứng dụng Ollama đã chạy chưa (gõ <code>ollama list</code> trong CMD để kiểm tra nhé)!`;
      } else {
        msg = error.name === 'AbortError'
          ? 'Thời gian chờ AI phản hồi quá lâu (>12s), vui lòng thử lại câu hỏi ngắn hơn nhé!'
          : `Dạ anh Huy ơi! Google AI phản hồi lỗi: "<strong>${errDetail}</strong>".<br><br>Anh Huy vui lòng nhấn nút <strong>⚙️ API Key</strong> bên dưới để dán lại mã API Key chính xác từ Google AI Studio nhé!`;
      }
      this.addMessage('bot', msg);

      if (this.chatHistory.length > 0 && this.chatHistory[this.chatHistory.length - 1].role === 'user') {
        this.chatHistory.pop();
      }
    } finally {
      this._finishChat();
    }
  }

  _finishChat() {
    const el = document.getElementById('chat-typing-indicator');
    if (el) el.remove();

    const sendBtn = document.getElementById('btn-send-chat');
    if (sendBtn) {
      sendBtn.disabled = false;
      sendBtn.style.opacity = '1';
      sendBtn.textContent = 'Gửi';
    }

    this.isProcessing = false;
  }

  // ========================
  // DEMO STORIES & CONSULTATION
  // ========================
  tellProcessStory() {
    this.setEmotion('explaining');
    const story = `📖 <strong>HÀNH TRÌNH TỪ Ý TƯỞNG ĐẾN CĂN PHÒNG HOÀN THIỆN (4 HỒI):</strong><br><br>` +
      `<strong>Hồi 1 - Thổi hồn ý tưởng:</strong> Bạn chỉ cần chụp 1 bức ảnh chiếc bàn hoặc tủ bạn thích trên mạng. AI sẽ quét cấu trúc và phân tích tỉ lệ.<br><br>` +
      `<strong>Hồi 2 - Hóa thân 3D & Dynamic Component:</strong> Plugin SketchUp tự động sinh mô hình 3D kèm công thức co giãn thông minh.<br><br>` +
      `<strong>Hồi 3 - Bóc tách thần tốc & G-Code CNC:</strong> Thuật toán CAM tự xếp phẳng từng tấm ván lên khổ 1220x2440mm, giảm phế liệu và xuất file G-Code.<br><br>` +
      `<strong>Hồi 4 - Gia công thực tế:</strong> Cắm USB vào máy CNC tại xưởng gỗ, bấm nút là ván được cắt chính xác từng milimet!`;
    this.addMessage('bot', story, {
      text: '✨ Trải nghiệm tạo mẫu bàn ngay',
      onClick: () => this.createErgonomicDeskAction()
    });
  }

  consultStyle() {
    this.setEmotion('happy');
    const msg = `🎨 <strong>GỢI Ý PHONG CÁCH TỐI ƯU CHO BẠN:</strong><br><br>` +
      `Với không gian căn hộ hiện đại, mình đề xuất phong cách <strong>${this.styles.scandinavian.name}</strong> hoặc <strong>${this.styles.minimalist.name}</strong>:<br>` +
      `• <strong>Bảng màu:</strong> ${this.styles.scandinavian.palette}.<br>` +
      `• <strong>Vật liệu:</strong> ${this.styles.scandinavian.material}.<br>` +
      `• <strong>Quy tắc công năng:</strong> Giữ khoảng cách lối đi tối thiểu 70cm, bàn làm việc cao 750mm cạnh cửa sổ để đón ánh sáng tự nhiên.<br><br>` +
      `Bạn muốn mình áp dụng phong cách này vào thiết kế bàn làm việc hay tủ áo?`;
    this.addMessage('bot', msg, {
      text: '📐 Thiết lập bàn theo phong cách Scandinavian',
      onClick: () => { if (window.app) window.app.applyStylePreset('scandinavian'); }
    });
  }

  consultMaterials() {
    this.setEmotion('explaining');
    const msg = `🪵 <strong>CHUYÊN GIA SO SÁNH VẬT LIỆU CHO BẠN:</strong><br><br>` +
      `1. <strong>MDF Lõi Xanh Chống Ẩm (An Cường):</strong> Rất phẳng, không co ngót cong vênh, kháng ẩm tốt, phủ Melamine chống trầy xước. Lựa chọn số 1 cho nội thất hiện đại và máy CNC cắt cực êm.<br>` +
      `2. <strong>Gỗ Sồi Tự Nhiên (Oak):</strong> Vân gỗ tự nhiên sang trọng, ấm cúng, chịu lực va đập cao. Thích hợp làm mặt bàn hoặc chân bàn tạo điểm nhấn.<br>` +
      `👉 <strong>Lời khuyên của Anh Thợ Mộc Tin Tin:</strong> Khuyên dùng kết hợp <em>Mặt bàn Gỗ Sồi</em> cùng <em>Khung chân sắt hộp sơn tĩnh điện đen mờ</em> để vừa hiện đại, vừa bền đẹp 15 năm!`;
    this.addMessage('bot', msg);
  }

  createErgonomicDeskAction() {
    this.setEmotion('excited');
    const msg = `🎉 Tuyệt vời! Mình vừa thiết lập thông số cho <strong>Bàn Làm Việc Công Thái Học Tiêu Chuẩn</strong>:<br>` +
      `• Kích thước: <strong>1400 x 700 x 750 mm</strong> (Rộng rãi để 2 màn hình)<br>` +
      `• Cốt ván: MDF Chống ẩm 18mm phủ Melamine sồi<br>` +
      `• Khung chân: Chân sắt hộp chữ U chịu lực 120kg<br>` +
      `• Hộc tủ: 2 ngăn kéo có ray trượt giảm chấn.<br><br>` +
      `Nhấn nút bên dưới để chuyển thông số này sang tab Tạo 3D và SketchUp nhé!`;
    this.addMessage('bot', msg, {
      text: '🚀 Áp dụng thông số & Xem mô hình 3D',
      onClick: () => {
        if (window.app) {
          window.app.setCustomParams({
            type: 'desk', name: 'Bàn Công Thái Học Tin Tin',
            length: 1400, width: 700, height: 750, thickness: 18,
            material: 'oak', leg_style: 'metal_frame', drawers: 2
          });
          window.app.switchTab('tab-ai-scan');
        }
      }
    });
  }

  genericConsultation(query) {
    this.setEmotion('explaining');
    const msg = `Ý kiến rất thú vị! Dưới góc nhìn chuyên môn, khi làm nội thất bạn nên lưu ý: quy chuẩn kích thước nhân trắc học là quan trọng nhất để tạo sự thoải mái. Sau đó kết hợp bóc tách chuẩn G-Code sẽ giúp tiết kiệm 20-30% chi phí vật liệu ván. Bạn muốn thử nghiệm chức năng nào tiếp theo?`;
    this.addMessage('bot', msg);
  }
}

window.AvatarConsultant = AvatarConsultant;
window.EdgeTTS = EdgeTTS;
