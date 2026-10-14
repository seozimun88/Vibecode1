import sys

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

old_input = '<input type="password" id="input-gemini-key" placeholder="AIzaSy...">'
new_input = '<input type="text" id="input-gemini-key" placeholder="Dán mã API Key (AIzaSy...) vào đây" style="width: 100%; text-align: center; margin-bottom: 15px; font-family: monospace;">'

html = html.replace(old_input, new_input)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("index.html patched for API input type!")
