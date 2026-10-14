import sys

with open('app.js', 'r', encoding='utf-8') as f:
    js = f.read()

hud_resizer_js = """
  initHUDResizer() {
    const hud = document.getElementById('game-bottom-hud');
    const resizer = document.getElementById('hud-resizer');
    if (!hud || !resizer) return;

    let isResizing = false;

    resizer.addEventListener('mousedown', (e) => {
      isResizing = true;
      document.body.style.cursor = 'ns-resize';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return;
      // Calculate new height: viewport height - mouse Y
      let newHeight = window.innerHeight - e.clientY;
      if (newHeight < 150) newHeight = 150;
      if (newHeight > window.innerHeight * 0.8) newHeight = window.innerHeight * 0.8;
      
      hud.style.height = newHeight + 'px';
      this.updateCommandGrid();
    });

    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false;
        document.body.style.cursor = '';
      }
    });

    // Pagination logic
    this.cmdCurrentPage = 0;
    const btnNext = document.getElementById('btn-cmd-next');
    const btnPrev = document.getElementById('btn-cmd-prev');
    
    btnNext?.addEventListener('click', () => {
      this.cmdCurrentPage++;
      this.updateCommandGrid();
    });
    btnPrev?.addEventListener('click', () => {
      this.cmdCurrentPage--;
      this.updateCommandGrid();
    });

    // Initial render
    setTimeout(() => this.updateCommandGrid(), 100);
    window.addEventListener('resize', () => this.updateCommandGrid());
  }

  updateCommandGrid() {
    const hud = document.getElementById('game-bottom-hud');
    const grid = document.getElementById('command-grid');
    if (!hud || !grid) return;

    const minimapHeight = 65;
    const padding = 20;
    const availableHeight = hud.clientHeight - minimapHeight - padding;
    
    // Each button is 48px + 6px gap = 54px
    let rows = Math.floor((availableHeight + 6) / 54);
    if (rows < 2) rows = 2; // Min 2 rows

    const slots = rows * 3;
    const realBtns = Array.from(document.querySelectorAll('.command-grid .real-btn'));
    const btnNext = document.getElementById('btn-cmd-next');
    const btnPrev = document.getElementById('btn-cmd-prev');

    // Hide all first
    realBtns.forEach(btn => btn.style.display = 'none');
    if (btnNext) btnNext.style.display = 'none';
    if (btnPrev) btnPrev.style.display = 'none';

    if (slots >= realBtns.length) {
      // Show all
      realBtns.forEach(btn => btn.style.display = 'flex');
      this.cmdCurrentPage = 0;
    } else {
      // Pagination needed
      const itemsPerPage = slots - 1; // Reserve 1 slot for Next/Prev
      const maxPage = Math.ceil(realBtns.length / itemsPerPage) - 1;
      
      if (this.cmdCurrentPage > maxPage) this.cmdCurrentPage = maxPage;
      if (this.cmdCurrentPage < 0) this.cmdCurrentPage = 0;

      const startIdx = this.cmdCurrentPage * itemsPerPage;
      const endIdx = startIdx + itemsPerPage;

      for (let i = startIdx; i < endIdx && i < realBtns.length; i++) {
        realBtns[i].style.display = 'flex';
      }

      if (this.cmdCurrentPage < maxPage && btnNext) {
        btnNext.style.display = 'flex';
      } else if (this.cmdCurrentPage > 0 && btnPrev) {
        btnPrev.style.display = 'flex';
      }
    }
  }
"""

if 'initHUDResizer()' not in js:
    js = js.replace('init() {', 'init() {\n    this.initHUDResizer();')
    # insert before initTabs()
    js = js.replace('initTabs() {', hud_resizer_js + '\n  initTabs() {')

# Hook up the new buttons to the existing modal triggers (for Page 2)
if 'btn-hud-save-load' not in js:
    hook_js = """
    document.getElementById('btn-hud-save-load')?.addEventListener('click', () => {
      document.getElementById('modal-projects').style.display = 'flex';
    });
    document.getElementById('btn-hud-api')?.addEventListener('click', () => {
      document.getElementById('modal-api').style.display = 'flex';
    });
    document.getElementById('btn-hud-cam')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.resetCamera();
    });
    document.getElementById('btn-hud-grid')?.addEventListener('click', () => {
      if(window.Furniture3DViewer && window.Furniture3DViewer.instance) window.Furniture3DViewer.instance.toggleGrid();
    });
    """
    js = js.replace('initModals() {', 'initModals() {\n' + hook_js)

with open('app.js', 'w', encoding='utf-8') as f:
    f.write(js)

print("app.js patched with resizer logic!")
