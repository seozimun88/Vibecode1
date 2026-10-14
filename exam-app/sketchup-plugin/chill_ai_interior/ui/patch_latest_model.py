import re

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Change the values in the dropdown to -latest to guarantee they exist
html = html.replace('value="gemini-1.5-flash"', 'value="gemini-1.5-flash-latest"')
html = html.replace('value="gemini-1.5-pro"', 'value="gemini-1.5-pro-latest"')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

with open('app.js', 'r', encoding='utf-8') as f:
    app_js = f.read()

# Change the default in app.js
app_js = app_js.replace("'gemini-1.5-flash'", "'gemini-1.5-flash-latest'")
app_js = app_js.replace("'gemini-1.5-pro'", "'gemini-1.5-pro-latest'")

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(app_js)

with open('avatar.js', 'r', encoding='utf-8') as f:
    avatar_js = f.read()

# Change the default in avatar.js
avatar_js = avatar_js.replace("'gemini-1.5-flash'", "'gemini-1.5-flash-latest'")

with open('avatar.js', 'w', encoding='utf-8') as f:
    f.write(avatar_js)

print("Updated model strings to use -latest alias!")
