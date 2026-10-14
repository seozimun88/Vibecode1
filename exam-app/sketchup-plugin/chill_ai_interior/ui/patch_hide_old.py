import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

hide_css = """
/* Hide old top bar buttons because they are migrated to the bottom right Command Card */
#btn-open-api-modal,
#btn-open-projects,
#btn-scan-camera {
  display: none !important;
}
"""

if 'btn-open-api-modal' not in css:
    css += hide_css

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("game_hud.css patched to hide old buttons!")
