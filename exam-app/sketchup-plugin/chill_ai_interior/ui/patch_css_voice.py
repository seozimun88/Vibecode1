import re

with open('game_hud.css', 'r', encoding='utf-8') as f:
    css = f.read()

toggle_css = """
/* Voice Toggle Switch */
.switch {
  position: relative;
  display: inline-block;
  width: 34px;
  height: 18px;
}
.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}
.slider {
  position: absolute;
  cursor: pointer;
  top: 0; left: 0; right: 0; bottom: 0;
  background-color: #4a5568;
  transition: .4s;
}
.slider:before {
  position: absolute;
  content: "";
  height: 12px;
  width: 12px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: .4s;
}
input:checked + .slider {
  background-color: #fbbf24;
}
input:checked + .slider:before {
  transform: translateX(16px);
}
.slider.round {
  border-radius: 18px;
}
.slider.round:before {
  border-radius: 50%;
}
"""

if "Voice Toggle Switch" not in css:
    css += toggle_css

with open('game_hud.css', 'w', encoding='utf-8') as f:
    f.write(css)

print("Added Voice Toggle CSS!")
