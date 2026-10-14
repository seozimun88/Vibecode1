import sys

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

js = js.replace("models/gemini-1.5-flash:generateContent", "models/${window.app.geminiModel || 'gemini-1.5-flash'}:generateContent")

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("Updated avatar.js with geminiModel!")
