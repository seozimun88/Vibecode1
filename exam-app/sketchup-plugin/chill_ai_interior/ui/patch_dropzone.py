import sys

with open('app.js', 'r', encoding='utf-8') as f:
    code = f.read()

# Fix dropZone button click issue
code = code.replace(
    "if (e.target.tagName !== 'BUTTON') {", 
    "if (e.target.tagName !== 'BUTTON' || (dropZone && dropZone.id === 'btn-upload-trigger') || e.target.closest('#btn-upload-trigger')) {"
)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(code)
print('Patched dropZone click successfully!')
