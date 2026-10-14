import sys

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

model_select = """
        <div style="margin-bottom: 15px;">
          <label style="display:block; margin-bottom: 5px; font-size:12px; color:#94a3b8; text-align:center;">Chọn Mô Hình Trí Tuệ Nhân Tạo:</label>
          <select id="input-gemini-model" style="width: 100%; padding: 8px; background: rgba(0,0,0,0.6); color: #fbbf24; border: 1px solid #4a5568; border-radius: 4px; text-align: center; font-family: inherit;">
            <option value="gemini-1.5-flash">Gemma 4 (Tốc độ cao - Khuyên dùng)</option>
            <option value="gemini-1.5-pro">Gemma 4 Pro (Suy luận sâu)</option>
          </select>
        </div>
"""

if 'id="input-gemini-model"' not in html:
    html = html.replace('<div class="modal-actions">', model_select + '\n        <div class="modal-actions">')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Added model selector to API modal!")
