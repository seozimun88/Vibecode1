import sys

with open('app.js', 'r', encoding='utf-8') as f:
    code = f.read()

# Fix initStatusIndicator
code = code.replace("pill.className", "if(pill) pill.className")
code = code.replace("text.textContent", "if(text) text.textContent")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(code)
print('Patched initStatusIndicator successfully!')
