import sys

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

hook_js = """
    // Page 2 Command Grid Hooks
    document.getElementById('btn-hud-save-load')?.addEventListener('click', () => {
      const m = document.getElementById('modal-projects');
      if (m) m.style.display = 'flex';
    });
    document.getElementById('btn-hud-api')?.addEventListener('click', () => {
      const m = document.getElementById('modal-api-key');
      if (m) m.style.display = 'flex';
    });
    document.getElementById('btn-hud-cam')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.resetCamera();
    });
    document.getElementById('btn-hud-grid')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.toggleGrid();
    });
"""

if 'btn-hud-api' not in js:
    js = js.replace('  sendToSketchUp(actionName, data) {', hook_js + '\n  sendToSketchUp(actionName, data) {')

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js patched to activate Page 2 command buttons!")
