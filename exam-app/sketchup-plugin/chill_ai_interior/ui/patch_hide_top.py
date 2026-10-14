import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

# Hide top-right utilities
if '.hud-top-right' in css:
    css = css.replace(
        '.hud-top-right {\n  display: flex;',
        '.hud-top-right {\n  display: none; /* Moved to command card */\n  /* display: flex; */'
    )
    css = css.replace(
        '.hud-top-right {\r\n  display: flex;',
        '.hud-top-right {\r\n  display: none; /* Moved to command card */\r\n  /* display: flex; */'
    )

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("game_hud.css patched to hide top right floaters!")
