import sys

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Fix modal-api ID
js = js.replace("document.getElementById('modal-api').style.display = 'flex';", "document.getElementById('modal-api-key').style.display = 'flex';")

# Fix speakBubble which no longer exists
js = js.replace("this.avatar.speakBubble(", "this.avatar.addMessage('bot', ")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js patched for API modal and speakBubble!")
