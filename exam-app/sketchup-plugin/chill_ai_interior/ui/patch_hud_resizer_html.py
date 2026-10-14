import sys

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add hud-resizer
if '<div id="hud-resizer"' not in content:
    content = content.replace(
        '<footer class="game-bottom-hud">',
        '<footer class="game-bottom-hud" id="game-bottom-hud">\n       <div id="hud-resizer" class="hud-resizer" title="Kéo để thay đổi kích thước"></div>'
    )

# 2. Update command-grid
old_grid_start = content.find('<div class="command-grid">')
old_grid_end = content.find('</div>\n       </div>\n    </footer>')

new_grid = """<div class="command-grid" id="command-grid">
             <!-- Page 1 Skills -->
             <button class="cmd-btn real-btn" id="btn-upload-trigger" title="Chọn Ảnh">
               <div class="cmd-icon">📸</div>
               <div class="cmd-txt">Tải Ảnh</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-build-3d" title="Dựng 3D Tĩnh">
               <div class="cmd-icon">🔨</div>
               <div class="cmd-txt">Xây 3D</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-generate-dc" title="Tạo DC (Có thể đổi kích thước)">
               <div class="cmd-icon">🪄</div>
               <div class="cmd-txt">Tạo DC</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-send-dc-to-su" title="Gửi DC vào SketchUp">
               <div class="cmd-icon">📤</div>
               <div class="cmd-txt">Xuất SU</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-save-gcode" title="Lưu File GCode CNC">
               <div class="cmd-icon">💾</div>
               <div class="cmd-txt">Lưu CNC</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-send-cnc" title="Gửi Xưởng CNC">
               <div class="cmd-icon">🏭</div>
               <div class="cmd-txt">Sản Xuất</div>
             </button>
             
             <!-- Page 2 Skills (Moved from top floating buttons) -->
             <button class="cmd-btn real-btn" id="btn-hud-save-load" title="Quản lý dự án">
               <div class="cmd-icon">📁</div>
               <div class="cmd-txt">Dự Án</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-hud-api" title="Cấu hình API">
               <div class="cmd-icon">⚙️</div>
               <div class="cmd-txt">API Key</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-hud-cam" title="Reset Camera">
               <div class="cmd-icon">🔄</div>
               <div class="cmd-txt">Reset Cam</div>
             </button>
             <button class="cmd-btn real-btn" id="btn-hud-grid" title="Bật/Tắt Lưới">
               <div class="cmd-icon">🕸️</div>
               <div class="cmd-txt">Lưới 3D</div>
             </button>

             <!-- Pagination Controls -->
             <button class="cmd-btn sys-btn" id="btn-cmd-next" title="Trang Tiếp Theo">
               <div class="cmd-icon" style="color:var(--hud-highlight);">⏭️</div>
               <div class="cmd-txt">Trang Sau</div>
             </button>
             <button class="cmd-btn sys-btn" id="btn-cmd-prev" title="Trang Trước">
               <div class="cmd-icon" style="color:var(--hud-highlight);">⏮️</div>
               <div class="cmd-txt">Trở Lại</div>
             </button>
          """

if old_grid_start != -1 and old_grid_end != -1:
    content = content[:old_grid_start] + new_grid + content[old_grid_end:]

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("index.html patched with resizer and new grid!")
