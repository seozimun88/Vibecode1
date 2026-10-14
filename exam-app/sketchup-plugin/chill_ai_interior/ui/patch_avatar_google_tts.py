import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

google_tts_method = """
    speakText(text) {
      if (!this.isVoiceEnabled) return;
      
      try {
          // Remove HTML tags for clean speech
          const plainText = text.replace(/<[^>]+>/g, '').trim();
          if (!plainText) return;
          
          if (window.currentGoogleAudio) {
              window.currentGoogleAudio.pause();
          }
          
          // Split into sentences (Google TTS limits length to ~200 chars per request)
          const sentences = plainText.match(/[^.!?]+[.!?]+/g) || [plainText];
          let currentIndex = 0;
          
          const playNext = () => {
              if (currentIndex >= sentences.length) return;
              
              let chunk = sentences[currentIndex].trim();
              if (!chunk) {
                  currentIndex++;
                  playNext();
                  return;
              }
              
              if (chunk.length > 200) {
                  chunk = chunk.substring(0, 195) + "...";
              }
              
              const url = `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=vi&q=${encodeURIComponent(chunk)}`;
              const audio = new Audio(url);
              window.currentGoogleAudio = audio;
              
              audio.onended = () => {
                  currentIndex++;
                  playNext();
              };
              
              audio.onerror = (e) => {
                  console.error("Audio error:", e);
                  currentIndex++;
                  playNext();
              };
              
              audio.play().catch(e => {
                  console.error("Audio play error:", e);
              });
          };
          
          playNext();
          
      } catch (e) {
          console.error("Speech Synthesis Error:", e);
      }
    }
"""

# Replace the existing speakText method
js = re.sub(r'speakText\(text\)\s*\{[\s\S]*?\}\s*catch\s*\(e\)\s*\{\s*console\.error\("Speech Synthesis Error:",\s*e\);\s*\}\s*\}', google_tts_method.strip(), js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Properly replaced speakText with Google Translate Audio TTS (with stop logic)!")
