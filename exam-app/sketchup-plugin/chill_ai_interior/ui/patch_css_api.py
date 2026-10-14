import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

bad_css = """#btn-open-api-modal,
#btn-open-projects,
#btn-scan-camera {
  display: none !important;
}"""

if bad_css in css:
    css = css.replace(bad_css, '')
else:
    # Just to be safe, replace line by line
    css = css.replace('#btn-open-api-modal,\n#btn-open-projects,\n#btn-scan-camera {\n  display: none !important;\n}', '')
    css = css.replace('#btn-open-api-modal { display: none !important; }', '')

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("Restored btn-open-api-modal visibility!")
