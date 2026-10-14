import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

speak_text_method = """
    speakBubble(text) {
      if (this.speechBubble) {
        this.speechBubble.innerHTML = text;
      }
    }

    speakText(text) {
      if (!this.isVoiceEnabled || !window.speechSynthesis) return;
      
      try {
          window.speechSynthesis.cancel();
          
          const plainText = text.replace(/<[^>]+>/g, '').trim();
          if (!plainText) return;
          
          const utterance = new SpeechSynthesisUtterance(plainText);
          utterance.lang = 'vi-VN';
          utterance.pitch = 1.1;
          utterance.rate = 1.05;
          
          const voices = window.speechSynthesis.getVoices();
          if (Array.isArray(voices) || (voices && voices.length > 0)) {
              let vnVoice = null;
              for(let i=0; i<voices.length; i++) {
                  if (voices[i].lang.includes('vi') || voices[i].lang.includes('VN')) {
                      vnVoice = voices[i];
                      break;
                  }
              }
              if (vnVoice) {
                  utterance.voice = vnVoice;
              }
          }
          
          window.speechSynthesis.speak(utterance);
      } catch (e) {
          console.error("Speech Synthesis Error:", e);
      }
    }
"""

# Replace the existing speakBubble method using a robust regex
js = re.sub(r'speakBubble\(text\)\s*\{\s*if\s*\(this\.speechBubble\)\s*\{\s*this\.speechBubble\.innerHTML\s*=\s*text;\s*\}\s*\}', speak_text_method.strip(), js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Properly injected speakText into avatar.js!")
