import sys

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

helper_html = """
        <div style="text-align: center; margin-bottom: 15px;">
           <button onclick="window.open('https://aistudio.google.com/app/apikey', '_blank')" style="background: transparent; border: 1px solid #fbbf24; color: #fbbf24; padding: 6px 12px; cursor: pointer; border-radius: 4px; font-family: inherit; font-weight: bold; transition: 0.2s;" onmouseover="this.style.background='#fbbf24'; this.style.color='#0f172a'" onmouseout="this.style.background='transparent'; this.style.color='#fbbf24'">👉 Bấm vào đây để lấy API Key Miễn Phí</button>
           <div style="font-size: 11px; color: #64748b; margin-top: 5px;">(Yêu cầu đăng nhập tài khoản Google)</div>
        </div>
"""

old_h3 = '<h3>⚙️ Cấu Hình API (Nhà Chính)</h3>'

if 'aistudio.google.com' not in html:
    html = html.replace(old_h3, old_h3 + '\n' + helper_html)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("index.html patched with Get API Key button!")
