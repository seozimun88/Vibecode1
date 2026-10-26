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

    # Lệnh kích hoạt công cụ tương tác 3D: Khoan Bản Lề Chuẩn ABF
    cmd_hinge_tool = UI::Command.new("🚪 Khoan Bản Lề (Chuẩn ABF)") do
      HingeTool.activate_tool if defined?(HingeTool)
    end
    cmd_hinge_tool.tooltip = "🚪 Khoan Bản Lề Chuẩn ABF (Kích chọn Cánh Cửa -> Kích chọn Hông Tủ)"
    cmd_hinge_tool.status_bar_text = "Khoan bản lề chén Ø35mm: Kích chọn tấm cửa, sau đó kích chọn tấm tủ để hiện nét đứt và đục lỗ CNC"
    cmd_hinge_tool.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_hinge_tool.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh kích hoạt công cụ tương tác 3D: Tiết Diện Giao Nhau Chuẩn ABF
    cmd_intersect_tool = UI::Command.new("📐 Tiết Diện Giao Nhau (Chuẩn ABF)") do
      IntersectTool.activate_tool if defined?(IntersectTool)
    end
    cmd_intersect_tool.tooltip = "📐 Tiết Diện Giao Nhau Chuẩn ABF (Ngàm âm dương, rãnh hậu, rãnh cửa lùa)"
    cmd_intersect_tool.status_bar_text = "Tiết diện giao nhau: Kích chọn tấm ván 1, sau đó kích chọn tấm ván 2 để tạo rãnh phay CNC thoát mép 3.5mm"
    cmd_intersect_tool.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_intersect_tool.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh mở Bảng Chọn Góc Xoay Vân Chuẩn ABF
    cmd_grain_palette = UI::Command.new("🪵 Góc Xoay Vân (Chuẩn ABF)") do
      WindowManager.show_grain_palette if defined?(WindowManager)
    end
    cmd_grain_palette.tooltip = "🪵 Bảng Chọn Góc Xoay Vân Chuẩn ABF (45°, -45°, 30°, 60°, 90°, 0°)"
    cmd_grain_palette.status_bar_text = "Bảng chọn góc xoay vân nhanh: Kích chọn tấm ván và chọn góc xoay vân tức thì"
    cmd_grain_palette.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_grain_palette.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh mở Cửa Sổ Đổi Tên Chuẩn ABF
    cmd_rename_dialog = UI::Command.new("🏷️ Đổi Tên (Chuẩn ABF)") do
      WindowManager.show_rename_dialog if defined?(WindowManager)
    end
    cmd_rename_dialog.tooltip = "🏷️ Đổi Tên Tấm Ván & Cụm Module (Chuẩn ABF)"
    cmd_rename_dialog.status_bar_text = "Mở bảng đổi tên tấm ván và cụm module với từ điển phím bấm nhanh chuẩn ABF"
    cmd_rename_dialog.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_rename_dialog.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh mở Bảng Thống Kê & Dự Toán Chi Phí (Chuẩn ABF)
    cmd_report_dialog = UI::Command.new("📊 Bảng Thống Kê (Chuẩn ABF)") do
      WindowManager.show_report_dialog if defined?(WindowManager)
    end
    cmd_report_dialog.tooltip = "📊 Bảng Thống Kê Phụ Kiện & Cấu Kiện Ván (Chuẩn ABF)"
    cmd_report_dialog.status_bar_text = "Mở bảng thống kê chi tiết phụ kiện liên kết, rãnh ngàm, khổ ván và cấu kiện cắt CNC"
    cmd_report_dialog.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_report_dialog.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh kích hoạt công cụ tương tác 3D: Di Chuyển Chùm Điểm (Chuẩn ABF)
    cmd_stretch_tool = UI::Command.new("🎯 Di Chuyển Chùm Điểm (Chuẩn ABF)") do
      StretchTool.activate_tool if defined?(StretchTool)
    end
    cmd_stretch_tool.tooltip = "🎯 Di Chuyển Chùm Điểm (Kéo giãn hình học ván chuẩn ABF)"
    cmd_stretch_tool.status_bar_text = "Di chuyển chùm điểm: Quét chuột chọn đỉnh (xuyên thấu), bấm phím mũi tên chọn hướng, gõ khoảng cách rồi Enter"
    cmd_stretch_tool.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_stretch_tool.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh kích hoạt công cụ tương tác 3D: Chỉ Dán Cạnh (Chuẩn ABF)
    cmd_edge_banding_tool = UI::Command.new("🎨 Chỉ Dán Cạnh (Chuẩn ABF)") do
      EdgeBandingTool.activate_tool if defined?(EdgeBandingTool)
    end
    cmd_edge_banding_tool.tooltip = "🎨 Chỉ Dán Cạnh (Kích chọn tấm ván viền xanh, chọn cạnh dán chỉ)"
    cmd_edge_banding_tool.status_bar_text = "Chỉ dán cạnh ABF: Kích chọn tấm ván (nổi viền xanh), sau đó kích chọn cạnh cần dán chỉ"
    cmd_edge_banding_tool.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_edge_banding_tool.large_icon = File.join(icon_dir, 'icon_24.png')

    # Lệnh mở Bảng Cài Đặt Thông Số Chỉ Dán Cạnh (Chuẩn ABF)
    cmd_edge_banding_dialog = UI::Command.new("⚙️ Cài Đặt Dán Cạnh (Chuẩn ABF)") do
      WindowManager.show_edge_banding_dialog if defined?(WindowManager)
    end
    cmd_edge_banding_dialog.tooltip = "⚙️ Bảng Điều Chỉnh Thông Số Dán Chỉ Cạnh (Độ dày, màu sắc, đơn giá)"
    cmd_edge_banding_dialog.status_bar_text = "Mở bảng quản lý 12 loại chỉ dán cạnh, độ dày và đơn giá tính mét chuẩn ABF"
    cmd_edge_banding_dialog.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_edge_banding_dialog.large_icon = File.join(icon_dir, 'icon_24.png')




    
    # Lệnh mở Cửa Sổ In Tem Nhãn (Chuẩn ABF & Máy In Tem Xprinter / Gprinter)
    cmd_print_labels = UI::Command.new("🏷️ In Tem Nhãn (Chuẩn ABF)") do
      WindowManager.show_print_labels_dialog if defined?(WindowManager)
    end
    cmd_print_labels.tooltip = "🏷️ In Tem Nhãn Tấm Ván (Kết Nối Máy In Xprinter, Gprinter & Xuất PDF)"
    cmd_print_labels.status_bar_text = "In tem nhãn chi tiết tấm ván chuẩn ABF: Khổ 60x40mm, mã QR Code, sơ đồ dán cạnh và xuất PDF"
    cmd_print_labels.small_icon = File.join(icon_dir, 'icon_print_16.png')
    cmd_print_labels.large_icon = File.join(icon_dir, 'icon_print_24.png')

    # Lệnh mở Cửa Sổ Rã Khối / Sơ Đồ Lắp Ráp (Exploded View Chuẩn ABF)
    cmd_exploded_view = UI::Command.new("💥 Sơ Đồ Lắp Ráp (Exploded View)") do
      WindowManager.show_exploded_hud if defined?(WindowManager)
    end
    cmd_exploded_view.tooltip = "💥 Sơ Đồ Lắp Ráp / Exploded View (Bung Chi Tiết 3D Kèm Text Chú Thích Chuẩn ABF)"
    cmd_exploded_view.status_bar_text = "Rã khối chi tiết tấm ván thời gian thực theo 3 trục X, Y, Z và tạo bản vẽ lắp ráp"
    cmd_exploded_view.small_icon = File.join(icon_dir, 'icon_exploded_16.png')
    cmd_exploded_view.large_icon = File.join(icon_dir, 'icon_exploded_24.png')

    # Lệnh kích hoạt công cụ tương tác 3D: Trải Phẳng Bề Mặt (Chuẩn UniTool - Ảnh 1 & Ảnh 3)
    cmd_flatten_face = UI::Command.new("Flatten Face (Trải Phẳng Bề Mặt)") do
      FlattenTool.activate_tool if defined?(FlattenTool)
    end
    cmd_flatten_face.tooltip = "Flatten Face - Trải Phẳng Bề Mặt (Sẻ rãnh ván bo cong chuẩn CNC)"
    cmd_flatten_face.status_bar_text = "Trải phẳng ván bo cong: Kích chọn mặt cong để duỗi thẳng và tạo rãnh CNC kèm cữ dưỡng"
    cmd_flatten_face.small_icon = File.join(icon_dir, 'icon_flatten.png')
    cmd_flatten_face.large_icon = File.join(icon_dir, 'icon_flatten.png')

    # Lệnh mở Bảng Điều Chỉnh Ván Uốn Cong (Chuẩn UniTool - Ảnh 2)
    cmd_flatten_dialog = UI::Command.new("⚙️ Cài Đặt Ván Uốn Cong (UniTool)") do
      WindowManager.show_flatten_dialog if defined?(WindowManager)
    end
    cmd_flatten_dialog.tooltip = "⚙️ Bảng Điều Chỉnh Thông Số Ván Uốn Cong (D, L, P, S, Cữ dưỡng, Layer)"
    cmd_flatten_dialog.status_bar_text = "Thiết lập đường kính dao D, bề dày phôi P, bước rãnh S, cữ dưỡng và layer CNC"
    cmd_flatten_dialog.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd_flatten_dialog.large_icon = File.join(icon_dir, 'icon_24.png')

    # 1. Menu Plugins / Extensions
    menu = UI.menu("Plugins") || UI.menu("Extensions")
    submenu = menu.add_submenu("Chill AI Interior")
    submenu.add_item(cmd_open)
    submenu.add_item(cmd_flatten_face)
    submenu.add_item(cmd_flatten_dialog)
    submenu.add_item(cmd_stretch_tool)
    submenu.add_item(cmd_fitting_tool)
    submenu.add_item(cmd_hinge_tool)
    submenu.add_item(cmd_intersect_tool)
    submenu.add_item(cmd_grain_palette)
    submenu.add_item(cmd_rename_dialog)
    submenu.add_item(cmd_report_dialog)
    submenu.add_item(cmd_fitting_studio)
    submenu.add_item(cmd_export_dxf)
    submenu.add_item(cmd_print_labels)
    submenu.add_item(cmd_exploded_view)
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
    toolbar.add_item(cmd_flatten_face)
    toolbar.add_item(cmd_stretch_tool)
    toolbar.add_item(cmd_edge_banding_tool)
    toolbar.add_item(cmd_fitting_tool)
    toolbar.add_item(cmd_hinge_tool)
    toolbar.add_item(cmd_intersect_tool)
    toolbar.add_item(cmd_grain_palette)
    toolbar.add_item(cmd_rename_dialog)
    toolbar.add_item(cmd_report_dialog)
    toolbar.add_item(cmd_fitting_studio)
    toolbar.add_item(cmd_export_dxf)
    toolbar.add_item(cmd_print_labels)
    toolbar.add_item(cmd_exploded_view)
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
