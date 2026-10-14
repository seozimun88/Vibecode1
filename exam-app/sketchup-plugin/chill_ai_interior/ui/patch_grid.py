import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

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
             <button class="cmd-btn sys-btn" id="btn-cmd-next" title="Trang Tiếp Theo" style="display:none;">
               <div class="cmd-icon" style="color:var(--hud-highlight);">⏭️</div>
               <div class="cmd-txt">Trang Sau</div>
             </button>
             <button class="cmd-btn sys-btn" id="btn-cmd-prev" title="Trang Trước" style="display:none;">
               <div class="cmd-icon" style="color:var(--hud-highlight);">⏮️</div>
               <div class="cmd-txt">Trở Lại</div>
             </button>
          </div>"""

# Replace everything from <div class="command-grid"> to the end of the div
content = re.sub(r'<div class="command-grid">.*?</div>\s*</div>\s*</footer>', new_grid + '\n       </div>\n    </footer>', content, flags=re.DOTALL)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Robust HTML grid replacement done!")
