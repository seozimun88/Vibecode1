import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

edge_tts_class = """
class EdgeTTS {
    static async synthesize(text, voice = 'vi-VN-HoaiMyNeural') {
        return new Promise((resolve, reject) => {
            const ws = new WebSocket('wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4');
            let audioChunks = [];
            
            const uuid = () => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
                const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
            
            ws.onopen = () => {
                const date = new Date().toString();
                const configMsg = `X-Timestamp:${date}\\r\\nContent-Type:application/json; charset=utf-8\\r\\nPath:speech.config\\r\\n\\r\\n{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}`;
                ws.send(configMsg);
                
                const ssml = `<ssml version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="vi-VN"><voice name="${voice}"><prosody pitch="+0Hz" rate="0%">${text}</prosody></voice></ssml>`;
                const ssmlMsg = `X-RequestId:${uuid()}\\r\\nContent-Type:application/ssml+xml\\r\\nX-Timestamp:${date}\\r\\nPath:ssml\\r\\n\\r\\n${ssml}`;
                ws.send(ssmlMsg);
            };
            
            ws.onmessage = async (event) => {
                if (typeof event.data === 'string') {
                    if (event.data.includes('Path:turn.end')) {
                        ws.close();
                        const blob = new Blob(audioChunks, { type: 'audio/mp3' });
                        resolve(URL.createObjectURL(blob));
                    }
                } else if (event.data instanceof Blob) {
                    const buffer = await event.data.arrayBuffer();
                    const view = new Uint8Array(buffer);
                    // Find the sequence 0x0D 0x0A 0x0D 0x0A (\r\n\r\n) which separates headers from binary audio
                    let headerEnd = -1;
                    for (let i = 0; i < view.length - 3; i++) {
                        if (view[i] === 13 && view[i+1] === 10 && view[i+2] === 13 && view[i+3] === 10) {
                            headerEnd = i + 4;
                            break;
                        }
                    }
                    if (headerEnd !== -1) {
                        audioChunks.push(buffer.slice(headerEnd));
                    }
                }
            };
            
            ws.onerror = (e) => reject(e);
        });
    }
}
"""

edge_speak_method = """
    async speakText(text) {
      if (!this.isVoiceEnabled) return;
      
      try {
          const plainText = text.replace(/<[^>]+>/g, '').trim();
          if (!plainText) return;
          
          if (window.currentGoogleAudio) {
              window.currentGoogleAudio.pause();
          }
          
          // Use Edge TTS (Hoài My - Nữ Miền Nam)
          const audioUrl = await EdgeTTS.synthesize(plainText, 'vi-VN-HoaiMyNeural');
          const audio = new Audio(audioUrl);
          window.currentGoogleAudio = audio;
          audio.play().catch(e => console.error("Audio play error:", e));
          
      } catch (e) {
          console.error("Speech Synthesis Error:", e);
      }
    }
"""

# Insert the EdgeTTS class at the top of the file if not already there
if "class EdgeTTS" not in js:
    js = edge_tts_class + "\n" + js

# Replace speakText with the new EdgeTTS logic
js = re.sub(r'speakText\(text\)\s*\{[\s\S]*?\}\s*catch\s*\(e\)\s*\{\s*console\.error\("Speech Synthesis Error:",\s*e\);\s*\}\s*\}', edge_speak_method.strip(), js)

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Properly replaced speakText with Microsoft Edge TTS!")
