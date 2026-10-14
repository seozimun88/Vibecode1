import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

# Reduce width of hud-portrait from 200px to 145px
css = css.replace('width: 200px;', 'width: 145px;')

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("Narrowed HUD Portrait successfully!")
