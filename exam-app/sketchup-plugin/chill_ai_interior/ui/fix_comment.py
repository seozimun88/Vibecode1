import re

with open('avatar.js', 'r', encoding='utf-8') as f:
    js = f.read()

# Fix the broken comment
js = js.replace(") which separates headers from binary audio", " which separates headers from binary audio")

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(js)
