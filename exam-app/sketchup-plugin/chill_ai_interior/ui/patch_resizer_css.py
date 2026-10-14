import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

# Add position: relative to game-bottom-hud
if 'position: relative;' not in css.split('.game-bottom-hud {')[1].split('}')[0]:
    css = css.replace('.game-bottom-hud {\n  height: 200px;', '.game-bottom-hud {\n  position: relative;\n  height: 200px;')

# Enhance resizer styles
old_resizer = """/* Resizer */
.hud-resizer {
  position: absolute;
  top: -4px;
  left: 0;
  width: 100%;
  height: 8px;
  cursor: ns-resize;
  z-index: 1000;
  background: transparent;
}
.hud-resizer:hover {
  background: rgba(255, 215, 0, 0.3);
}"""

new_resizer = """/* Resizer */
.hud-resizer {
  position: absolute;
  top: -6px;
  left: 0;
  width: 100%;
  height: 12px;
  cursor: ns-resize;
  z-index: 1000;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
}
.hud-resizer::after {
  content: '';
  width: 100px;
  height: 2px;
  background: transparent;
  border-radius: 2px;
  transition: background 0.2s;
}
.hud-resizer:hover::after {
  background: var(--hud-highlight);
}
"""

css = css.replace(old_resizer, new_resizer)

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("game_hud.css patched for resizer!")
