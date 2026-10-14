import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

css = css.replace('height: 195px;', 'height: 200px;')

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("HUD height adjusted to 200px to fit everything comfortably!")
