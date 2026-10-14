import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

# 1. game-bottom-hud height
css = css.replace('height: 240px;', 'height: 195px;')

# 2. portrait frame
css = css.replace('width: 140px;\n  height: 160px;', 'width: 115px;\n  height: 135px;')
css = css.replace('width: 140px;\r\n  height: 160px;', 'width: 115px;\r\n  height: 135px;') # windows CRLF fallback

# 3. avatar-speech-bubble bottom and margin
# We replace bottom: calc(100% - 20px); with bottom: 100%; margin-bottom: 15px;
css = css.replace('bottom: calc(100% - 20px);', 'bottom: 100%;\n  margin-bottom: 15px;')

# 4. hud-command-panel minimap and btns
css = css.replace('height: 90px;\n  background: #000;', 'height: 65px;\n  background: #000;')
css = css.replace('height: 90px;\r\n  background: #000;', 'height: 65px;\r\n  background: #000;')
css = css.replace('height: 55px;\n  display: flex;', 'height: 48px;\n  display: flex;')
css = css.replace('height: 55px;\r\n  display: flex;', 'height: 48px;\r\n  display: flex;')

# Adjust icon sizes in buttons slightly
css = css.replace('font-size: 18px; margin-bottom: 2px;', 'font-size: 14px; margin-bottom: 2px;')

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("CSS patched successfully!")
