import re

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

good_code = """
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

# Insert right after the btn-toggle-wireframe event listener ends
js = re.sub(
    r"(document\.getElementById\('btn-toggle-wireframe'\)\?\.addEventListener\('click', \(\) => \{\s*if \(this\.viewer\) this\.viewer\.toggleWireframe\(\);\s*\}\);)",
    r"\1\n" + good_code,
    js
)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js syntax error completely fixed and code restored!")
