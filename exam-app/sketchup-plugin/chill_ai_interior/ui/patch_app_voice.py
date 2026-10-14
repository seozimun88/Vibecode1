import re

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Add event listener for voice toggle in initChatEvents()
old_chat_events = r"const send = \(\) => \{"
new_chat_events = """const toggleVoice = document.getElementById('toggle-voice-ai');
      const voiceIcon = document.getElementById('voice-status-icon');
      if (toggleVoice) {
        toggleVoice.addEventListener('change', (e) => {
          const isVoiceOn = e.target.checked;
          if (voiceIcon) {
            voiceIcon.textContent = isVoiceOn ? '🔊' : '🔇';
          }
          if (this.avatar) {
            this.avatar.isVoiceEnabled = isVoiceOn;
            if (isVoiceOn && window.speechSynthesis) {
                // Cancel any existing speech
                window.speechSynthesis.cancel();
                // Optionally preload voices
                window.speechSynthesis.getVoices();
            }
          }
        });
      }

      const send = () => {"""

if "toggle-voice-ai" not in js:
    js = js.replace("const send = () => {", new_chat_events)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Updated app.js with voice toggle events!")
