import sys

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Replace the broken literal newline in regex with a proper escaped newline
js = js.replace('formattedText = formattedText.replace(/\n  /g, \'<br>\');', 'formattedText = formattedText.replace(/\\n/g, \'<br>\');')
js = js.replace('formattedText = formattedText.replace(/\n/g, \'<br>\');', 'formattedText = formattedText.replace(/\\n/g, \'<br>\');')
js = js.replace('formattedText = formattedText.replace(/\r\n/g, \'<br>\');', 'formattedText = formattedText.replace(/\\n/g, \'<br>\');')

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("avatar.js syntax error fixed!")
