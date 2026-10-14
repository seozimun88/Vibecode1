import re

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

toggle_html = """                 <div style="display:flex; justify-content: flex-end; align-items: center; margin-bottom: 5px; gap: 5px; color: #94a3b8; font-size: 11px;">
                   <span>Giọng nói Lyly:</span>
                   <span id="voice-status-icon" style="font-size: 14px;">🔇</span>
                   <label class="switch" title="Bật/Tắt Giọng Nói">
                     <input type="checkbox" id="toggle-voice-ai">
                     <span class="slider round"></span>
                   </label>
                 </div>
                 <div class="chat-input-row" style="display:flex; gap: 5px; margin-top: auto;">"""

old_input_row = r'<div class="chat-input-row" style="display:flex; gap: 5px; margin-top: auto;">'

if "toggle-voice-ai" not in html:
    html = html.replace('<div class="chat-input-row" style="display:flex; gap: 5px; margin-top: auto;">', toggle_html)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Added Voice Toggle UI to index.html!")
