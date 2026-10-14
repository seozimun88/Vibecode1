import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Add isVoiceEnabled to constructor
js = js.replace('this.currentEmotion = \'neutral\';', 'this.currentEmotion = \'neutral\';\n      this.isVoiceEnabled = false;')

# Add speakText method and call it in addMessage
speak_text_method = """    speakBubble(text) {
      if (this.speechBubble) {
        this.speechBubble.innerHTML = text;
      }
    }

    speakText(text) {
      if (!this.isVoiceEnabled || !window.speechSynthesis) return;
      
      window.speechSynthesis.cancel();
      
      // Remove HTML tags for clean speech
      const plainText = text.replace(/<[^>]+>/g, '').trim();
      if (!plainText) return;
      
      const utterance = new SpeechSynthesisUtterance(plainText);
      utterance.lang = 'vi-VN';
      utterance.pitch = 1.1; // Cuter voice for Lyly
      utterance.rate = 1.05;
      
      const voices = window.speechSynthesis.getVoices();
      const vnVoice = voices.find(v => v.lang.includes('vi') || v.lang.includes('VN'));
      if (vnVoice) {
          utterance.voice = vnVoice;
      }
      
      window.speechSynthesis.speak(utterance);
    }
"""

if "speakText(" not in js:
    js = js.replace("    speakBubble(text) {\n      if (this.speechBubble) {\n        this.speechBubble.innerHTML = text;\n      }\n    }", speak_text_method)

# Call speakText in addMessage when sender is bot
add_message_hook_old = """    if (sender === 'bot') {
      this.speakBubble(text.length > 120 ? text.substring(0, 115) + '...' : text);
    }"""

add_message_hook_new = """    if (sender === 'bot') {
      this.speakBubble(text.length > 120 ? text.substring(0, 115) + '...' : text);
      this.speakText(text);
    }"""

js = js.replace(add_message_hook_old, add_message_hook_new)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Added Text-To-Speech to avatar.js!")
