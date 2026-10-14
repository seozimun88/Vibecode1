import sys

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

resizer_css = """
/* Resizer */
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
}

.cmd-btn.sys-btn {
  border-color: var(--hud-highlight);
  background: linear-gradient(180deg, #475569, #1e293b);
}
"""

if '.hud-resizer' not in css:
    css += resizer_css

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("game_hud.css patched with resizer styles!")
