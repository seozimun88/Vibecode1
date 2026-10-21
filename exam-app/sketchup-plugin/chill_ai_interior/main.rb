# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Main Plugin Entrypoint (Kiến Trúc Mới Lego 4 Tầng)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# Nhiệm vụ: Đăng ký Menu, Toolbar và giao quyền điều phối cho các Lego Services
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  PLUGIN_ROOT = File.expand_path(File.dirname(__FILE__)).freeze unless defined?(PLUGIN_ROOT)

  # Nạp Bộ Nạp Tự Động Quét Thư Mục
  require_relative 'module_loader'
  ModuleLoader.load_all

  # ============================================================================
  # CÁC HÀM CỔNG CHÍNH TIỆN ÍCH (DELEGATION FACADE)
  # ============================================================================
  def self.dialog
    WindowManager.dialog if defined?(WindowManager)
  end

  def self.show_dialog(force_default_pos: false)
    WindowManager.show_dialog(force_default_pos: force_default_pos) if defined?(WindowManager)
  end

  def self.reset_dialog_position
    WindowManager.reset_dialog_position if defined?(WindowManager)
  end

  def self.reload_modules
    ModuleLoader.reload_all if defined?(ModuleLoader)
  end

  # ============================================================================
  # KHỞI TẠO TOOLBAR & MENU TRONG SKETCHUP
  # ============================================================================
  unless file_loaded?(__FILE__)
    icon_dir = File.join(PLUGIN_ROOT, 'ui', 'assets')

    # Lệnh mở giao diện chính
    cmd_open = UI::Command.new("Chill AI Interior") { show_dialog }
    cmd_open.tooltip = "Mở Bảng Điều Khiển Chill AI Interior (Lego 4 Tầng)"
    cmd_open.status_bar_text = "Trợ lý thiết kế 3D, Dynamic Component & xuất G-Code CNC tự động bằng AI"
    cmd_open.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_open.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh xuất DXF 2D Nesting nhanh
    cmd_export_dxf = UI::Command.new('Xuất DXF 2D (Nesting)') do
      if defined?(CamGCodeExporter)
        result = CamGCodeExporter.export_selected_dxf
        if result && result['status'] == 'success'
          UI.messagebox("Đã xuất DXF 2D thành công:\n#{result['path']}\n\n#{result['total_parts']} chi tiết / #{result['total_sheets']} khổ ván.\nMở file này trong Aspire bằng Import Vectors.")
        end
      end
    end
    cmd_export_dxf.tooltip = 'Xuất DXF 2D từ model đang chọn cho Vectric Aspire'
    cmd_export_dxf.status_bar_text = 'Chọn model/tấm ván, sau đó xuất sơ đồ Nesting DXF 2D cho Aspire'
    cmd_export_dxf.small_icon = File.join(icon_dir, 'icon_dxf_16.png')
    cmd_export_dxf.large_icon = File.join(icon_dir, 'icon_dxf_24.png')

    # Lệnh mở Fitting Studio
    cmd_fitting_studio = UI::Command.new("⚙️ Bảng Cam Chốt (Fitting Studio)") do
      WindowManager.show_fitting_studio if defined?(WindowManager)
    end
    cmd_fitting_studio.tooltip = "Mở Bảng Cấu Hình Cam Chốt & Liên Kết Ngang Đa Năng"
    cmd_fitting_studio.status_bar_text = "Thiết lập thông số D, d, n, L, C và gán Layer CNC chuẩn System 32"
    cmd_fitting_studio.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_fitting_studio.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh kích hoạt công cụ tương tác 3D: Vị Trí Liên Kết Ngang
    cmd_fitting_tool = UI::Command.new("Vị Trí Liên Kết Ngang (Click 3D)") do
      FittingTool.activate_tool if defined?(FittingTool)
    end
    cmd_fitting_tool.tooltip = "Vị Trí Liên Kết Ngang (Click đúp vào tấm ván để đục lỗ)"
    cmd_fitting_tool.status_bar_text = "Kích hoạt chế độ liên kết ngang: Kích đúp chuột trái vào tấm ván để tạo liên kết"
    cmd_fitting_tool.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_fitting_tool.large_icon = File.join(icon_dir, 'icon_24.png')

    # 1. Menu Plugins / Extensions
    menu = UI.menu("Plugins") || UI.menu("Extensions")
    submenu = menu.add_submenu("Chill AI Interior")
    submenu.add_item(cmd_open)
    submenu.add_item(cmd_fitting_tool)
    submenu.add_item(cmd_fitting_studio)
    submenu.add_item(cmd_export_dxf)
    submenu.add_separator
    submenu.add_item("🔄 Đặt Lại Vị Trí Cửa Sổ (Snap Viewport 3D)") do
      reset_dialog_position
    end
    submenu.add_item("🔄 Tải Lại Plugin (Force Hot-Reload)") do
      reload_modules
      if dialog && dialog.visible?
        dialog.execute_script("location.reload();")
      else
        show_dialog
      end
    end

    # 2. Toolbar
    toolbar = UI::Toolbar.new("Chill AI Interior")
    toolbar.add_item(cmd_open)
    toolbar.add_item(cmd_fitting_tool)
    toolbar.add_item(cmd_fitting_studio)
    toolbar.add_item(cmd_export_dxf)
    toolbar.show

    # 3. Kích hoạt dịch vụ ngầm khi khởi động
    UI.start_timer(0.4, false) do
      AudioPlayer.ensure_tts_server rescue nil if defined?(AudioPlayer)
    end
    UI.start_timer(0.8, false) do
      show_dialog rescue nil
    end

    file_loaded(__FILE__)
  end
end
