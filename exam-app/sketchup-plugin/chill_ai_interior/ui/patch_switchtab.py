import sys

with open('app.js', 'r', encoding='utf-8') as f:
    code = f.read()

# Make sure switchTab uses flex for tab-chat
code = code.replace(
    "p.style.display = p.id === tabId ? 'block' : 'none';",
    "p.style.display = p.id === tabId ? (p.id === 'tab-chat' ? 'flex' : 'block') : 'none';"
)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(code)

print("app.js patched for switchTab!")
