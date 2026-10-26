# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Window Manager (Chuyên Gia Cửa Sổ & Toạ Độ Viewport Qt 6)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# Nguyên tắc: Đơn nhiệm (SRP) - Toàn bộ tính toán toạ độ và cửa sổ chỉ nằm ở đây!
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  module WindowManager
    @dialog = nil
    @screen_avail_height = nil
    @screen_avail_width = nil

    def self.dialog
      @dialog
    end

    def self.set_screen_metrics(width, height)
      @screen_avail_width = width.to_i if width && width.to_i > 500
      @screen_avail_height = height.to_i if height && height.to_i > 500
    end

    # TỰ ĐỘNG TÍNH TOÁN TOẠ ĐỘ SNAP KHÍT 100% VÙNG 3D CỦA SKETCHUP
    def self.calculate_dock_geometry
      model = Sketchup.active_model
      view = model ? model.active_view : nil

      # Chiều cao & chiều rộng không gian 3D thực tế theo API gốc của SketchUp
      vp_h = (view && view.vpheight > 200) ? view.vpheight : 631
      vp_w = (view && view.vpwidth > 400) ? view.vpwidth : 1200

      dock_w = 320

      # Lấy thông số vùng làm việc Windows (Work Area - trừ Taskbar) qua Windows API Fiddle hoặc JS
      work_bottom = @screen_avail_height
      work_right = @screen_avail_width

      unless work_bottom
        begin
          require 'fiddle'
          user32 = Fiddle::Handle.new('user32')
          sys_param = Fiddle::Function.new(
            user32['SystemParametersInfoW'],
            [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
            Fiddle::TYPE_INT
          )
          rect = "\0" * 16
          if sys_param.call(48, 0, rect, 0) != 0 # SPI_GETWORKAREA = 48
            _l, _t, r, b = rect.unpack('l4')
            work_bottom = b
            work_right = r
          end
        rescue => _e
        end
      end

      # Tính toán toạ độ Top và Height để lọt thỏm 100% trong không gian 3D:
      # Không gian 3D bắt đầu ngay dưới thanh Toolbar (y=154) và kết thúc ngay trên Status Bar (y=785).
      if work_bottom && work_bottom > 500
        # Đáy 3D = work_bottom - 31px (Status Bar)
        vp_bottom = work_bottom - 31
        # Đỉnh 3D = vp_bottom - vp_h (chính xác điểm bắt đầu dưới đáy Toolbar)
        dock_top = [vp_bottom - vp_h, 30].max
        dock_h = [vp_h - 2, 420].max
        dock_left = (work_right && work_right > 800) ? (work_right - dock_w - 6) : 1210
      else
        # Fallback chuẩn hóa tuyệt đối theo số tầng Toolbar:
        # Máy anh Huy có 3 tầng Toolbar: Toolbar chiếm 154px, 3D cao 631px
        if vp_h <= 645
          dock_top = 154
          dock_h = [vp_h - 2, 420].max
          dock_left = 1210
        elsif vp_h <= 720
          # 2 tầng Toolbar (~110px)
          dock_top = 110
          dock_h = [vp_h - 2, 420].max
          dock_left = 1210
        else
          # 1 tầng Toolbar (~70px)
          dock_top = 70
          dock_h = [vp_h - 2, 420].max
          dock_left = 1210
        end
      end

      [dock_w, dock_h, dock_left, dock_top]
    end

    # ĐẶT LẠI VỊ TRÍ CỬA SỔ & SNAP VỪA KHÍT KHÔNG GIAN 3D
    def self.reset_dialog_position
      begin
        if @dialog && @dialog.visible?
          dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
          @dialog.set_size(dock_w, dock_h)
          @dialog.set_position(dock_left, dock_top)
          @dialog.bring_to_front
          puts "[Chill AI WindowManager] Snap lại vị trí cửa sổ hiện có: #{dock_w}x#{dock_h} tại top=#{dock_top}"
        else
          show_dialog(force_default_pos: true)
        end
      rescue => err
        puts "[Chill AI WindowManager Error] #{err.message}"
      end
    end

    # KHỞI TẠO VÀ HIỂN THỊ CỬA SỔ PLUGIN
    def self.show_dialog(force_default_pos: false)
      begin
        # Nạp tươi mới code vào RAM nếu cần
        ModuleLoader.reload_all rescue nil

        # Nếu force_default_pos, đóng dialog cũ để tạo mới hoàn toàn với toạ độ chuẩn
        if force_default_pos && @dialog
          begin
            @dialog.close rescue nil
          rescue => _e
          end
          @dialog = nil
        end

        # 1. Nếu dialog đang mở và hiển thị, snap lại kích thước vừa khít 3D
        if @dialog && @dialog.visible?
          dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
          @dialog.set_size(dock_w, dock_h)
          @dialog.set_position(dock_left, dock_top)
          @dialog.bring_to_front
          return @dialog
        end

        # 2. Thu dọn tham chiếu cũ nếu dialog đã đóng
        if @dialog
          begin
            @dialog.close rescue nil
          rescue => _e
          end
          @dialog = nil
        end

        root = ModuleLoader.plugin_root
        html_path = File.join(root, 'ui', 'index.html')
        unless File.exist?(html_path)
          UI.messagebox("Không tìm thấy tệp giao diện UI tại:\n#{html_path}")
          return nil
        end

        # Kích thước khay dock tự động đo đạc vừa khít với không gian vẽ 3D của SketchUp
        dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry

        dialog_options = {
          dialog_title: "Chill AI Interior - Trợ Lý Thiết Kế 3D & Sản Xuất CNC",
          scrollable: false,
          resizable: true,
          width: dock_w,
          height: dock_h,
          min_width: 280,
          min_height: 360,
          left: dock_left,
          top: dock_top
        }
        # TUYỆT ĐỐI KHÔNG DÙNG preferences_key ĐỂ TRÁNH BỊ WINDOWS REGISTRY GHI ĐÈ!

        @dialog = UI::HtmlDialog.new(dialog_options)

        # Cài đặt Quầy Lễ Tân (Bridge Router)
        BridgeRouter.setup_callbacks(@dialog) if defined?(BridgeRouter)

        @dialog.set_on_closed do
          SelectionManager.detach rescue nil if defined?(SelectionManager)
          @dialog = nil
        end

        @dialog.set_file(html_path)
        @dialog.show
        @dialog.set_size(dock_w, dock_h)
        @dialog.set_position(dock_left, dock_top)
        @dialog.bring_to_front

        # Gắn observer giám sát đối tượng 3 tầng vào SketchUp
        SelectionManager.attach(@dialog) rescue nil if defined?(SelectionManager)

        # Kích hoạt TTS Server ngầm
        UI.start_timer(0.4, false) do
          AudioPlayer.ensure_tts_server rescue nil if defined?(AudioPlayer)
        end

        @dialog
      rescue => err
        msg = "Lỗi khi mở giao diện Chill AI Interior:\n#{err.message}\n\nChi tiết:\n#{err.backtrace ? err.backtrace.first(4).join("\n") : ''}"
        puts "[Chill AI Fatal] #{msg}"
        UI.messagebox(msg)
        nil
      end
    end

    # CHUYỂN ĐỔI CHẾ ĐỘ GIAO DIỆN: KHAY ĐỨNG (320px) VS TOÀN CẢNH STUDIO (1180x750)
    def self.set_layout_mode(mode)
      return unless @dialog && @dialog.visible?
      dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
      if mode.to_s == 'studio'
        @dialog.set_size(1180, 750)
        @dialog.set_position(80, 50)
        puts "[Chill AI WindowManager]: Chuyển sang Studio Mode (1180x750)"
      else
        @dialog.set_size(320, dock_h)
        @dialog.set_position(dock_left, dock_top)
        puts "[Chill AI WindowManager]: Snap Khay Đứng (320x#{dock_h} tại top=#{dock_top})"
      end
    rescue => e
      puts "[Chill AI Resize Error]: #{e.message}"
    end

    # SNAP KHAY ĐỨNG TỨC THÌ
    def self.snap_to_viewport
      return unless @dialog && @dialog.visible?
      dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
      @dialog.set_size(320, dock_h)
      @dialog.set_position(dock_left, dock_top)
      puts "[Chill AI WindowManager]: Snap dock 320x#{dock_h} tại top=#{dock_top}"
    end

    # HIỂN THỊ CỬA SỔ CẤU HÌNH CAM CHỐT (FITTING STUDIO)
    def self.show_fitting_studio
      if @fitting_dialog && @fitting_dialog.visible?
        @fitting_dialog.bring_to_front
        return @fitting_dialog
      end

      html_path = File.join(File.dirname(__FILE__), '..', 'ui', 'fitting_studio.html')
      dialog = UI::HtmlDialog.new({
        dialog_title: "Chill AI - Bảng Cấu Hình Cam Chốt & Liên Kết Ngang (Fitting Studio)",
        preferences_key: "ChillAIInterior_FittingStudio_v2",
        scrollable: true,
        resizable: true,
        width: 1020,
        height: 720,
        left: 150,
        top: 80,
        min_width: 860,
        min_height: 580
      })

      BridgeRouter.register_fitting_studio_callbacks(dialog) if defined?(BridgeRouter)
      dialog.set_file(html_path)
      dialog.show
      @fitting_dialog = dialog
      @fitting_dialog
    rescue => e
      UI.messagebox("Lỗi khi mở Fitting Studio: #{e.message}")
      nil
    end

    def self.close_fitting_studio
      if @fitting_dialog
        @fitting_dialog.close rescue nil
        @fitting_dialog = nil
      end
    end

    # HIỂN THỊ BẢNG CHỌN GÓC XOAY VÂN NỔI (CHUẨN ABF GRAIN PALETTE)
    def self.show_grain_palette
      if @grain_dialog && @grain_dialog.visible?
        @grain_dialog.bring_to_front
        return @grain_dialog
      end

      root = ModuleLoader.plugin_root
      html_path = File.join(root, 'ui', 'grain_palette.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy tệp giao diện Grain Palette tại:\n#{html_path}")
        return nil
      end

      # Kích thước & toạ độ góc trên bên trái SketchUp (khớp 100% vị trí ABF theo ảnh của anh Huy)
      dialog_options = {
        dialog_title: "Góc Xoay Vân",
        preferences_key: "ChillAI_Grain_Palette_Pos_v1",
        scrollable: false,
        resizable: true,
        width: 108,
        height: 420,
        min_width: 95,
        min_height: 340,
        left: 25,
        top: 130,
        style: UI::HtmlDialog::STYLE_UTILITY
      }

      @grain_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_grain_palette_callbacks(@grain_dialog) if defined?(BridgeRouter)

      @grain_dialog.set_on_closed do
        @grain_dialog = nil
      end

      @grain_dialog.set_file(html_path)
      @grain_dialog.show
      @grain_dialog.bring_to_front
      @grain_dialog
    rescue => err
      puts "[Chill AI Grain Palette Error]: #{err.message}"
      UI.messagebox("Lỗi khi mở Bảng Góc Xoay Vân: #{err.message}")
      nil
    end

    def self.close_grain_palette
      if @grain_dialog
        @grain_dialog.close rescue nil
        @grain_dialog = nil
      end
    end

    # HIỂN THỊ CỬA SỔ ĐỔI TÊN CHUẨN ABF (RENAME DIALOG)
    def self.show_rename_dialog
      if @rename_dialog && @rename_dialog.visible?
        @rename_dialog.bring_to_front
        return @rename_dialog
      end

      root = ModuleLoader.plugin_root
      html_path = File.join(root, 'ui', 'rename_dialog.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy tệp giao diện Rename Dialog tại:
#{html_path}")
        return nil
      end

      dialog_options = {
        dialog_title: "Đổi tên",
        preferences_key: "ChillAI_Rename_Dialog_v1",
        scrollable: true,
        resizable: true,
        width: 820,
        height: 640,
        min_width: 720,
        min_height: 520,
        left: 200,
        top: 100
      }

      @rename_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_rename_dialog_callbacks(@rename_dialog) if defined?(BridgeRouter)

      @rename_dialog.set_on_closed do
        @rename_dialog = nil
      end

      @rename_dialog.set_file(html_path)
      @rename_dialog.show
      @rename_dialog.bring_to_front
      @rename_dialog
    rescue => err
      puts "[Chill AI Rename Dialog Error]: #{err.message}"
      UI.messagebox("Lỗi khi mở Cửa Sổ Đổi Tên: #{err.message}")
      nil
    end

    def self.close_rename_dialog
      if @rename_dialog
        @rename_dialog.close rescue nil
        @rename_dialog = nil
      end
    end
  
    # HIỂN THỊ CỬA SỔ THỐNG KÊ & DỰ TOÁN CHI PHÍ (CHUẨN ABF)
    def self.show_report_dialog
      if @report_dialog && @report_dialog.visible?
        @report_dialog.bring_to_front
        return @report_dialog
      end

      root = ModuleLoader.plugin_root
      html_path = File.join(root, 'ui', 'report_dialog.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy tệp giao diện Report Dialog tại:\n#{html_path}")
        return nil
      end

      dialog_options = {
        dialog_title: "Thống kê",
        preferences_key: "ChillAI_Report_Dialog_v1",
        scrollable: true,
        resizable: true,
        width: 960,
        height: 640,
        min_width: 820,
        min_height: 520,
        left: 180,
        top: 80
      }

      @report_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_report_dialog_callbacks(@report_dialog) if defined?(BridgeRouter)

      @report_dialog.set_on_closed do
        @report_dialog = nil
      end

      @report_dialog.set_file(html_path)
      @report_dialog.show
      @report_dialog.bring_to_front
      @report_dialog
    rescue => err
      puts "[Chill AI Report Dialog Error]: #{err.message}"
      UI.messagebox("Lỗi khi mở Bảng Thống Kê: #{err.message}")
      nil
    end

    def self.close_report_dialog
      if @report_dialog
        @report_dialog.close rescue nil
        @report_dialog = nil
      end
    end

    # ==========================================================================
    # CỬA SỔ FLOATING PALETTE: CHỌN NHANH LOẠI CHỈ DÁN CẠNH (CHUẨN ẢNH 2)
    # ==========================================================================
    def self.show_edge_banding_palette
      if @eb_palette && @eb_palette.visible?
        @eb_palette.bring_to_front
        return @eb_palette
      end

      html_path = File.join(plugin_root, 'ui', 'edge_banding_palette.html')
      unless File.exist?(html_path)
        puts "[Chill AI] Không tìm thấy file: #{html_path}"
        return nil
      end

      dialog_options = {
        dialog_title: "Chỉ Dán Cạnh (Chuẩn ABF)",
        preferences_key: "ChillAI_EdgeBandingPalette",
        scrollable: false,
        resizable: true,
        width: 250,
        height: 480,
        min_width: 210,
        min_height: 350,
        left: 20,
        top: 80
      }

      @eb_palette = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_edge_banding_callbacks(@eb_palette) if defined?(BridgeRouter)

      @eb_palette.set_on_closed do
        @eb_palette = nil
      end

      @eb_palette.set_file(html_path)
      @eb_palette.show
      @eb_palette.bring_to_front
      @eb_palette
    rescue => err
      puts "[Chill AI EdgeBanding Palette Error]: #{err.message}"
      nil
    end

    def self.close_edge_banding_palette
      if @eb_palette
        @eb_palette.close rescue nil
        @eb_palette = nil
      end
    end

    # ==========================================================================
    # CỬA SỔ BẢNG ĐIỀU CHỈNH THÔNG SỐ CHỈ DÁN CẠNH ĐẦY ĐỦ (CHUẨN ẢNH 1)
    # ==========================================================================
    def self.show_edge_banding_dialog
      if @eb_dialog && @eb_dialog.visible?
        @eb_dialog.bring_to_front
        return @eb_dialog
      end

      html_path = File.join(plugin_root, 'ui', 'edge_banding_dialog.html')
      unless File.exist?(html_path)
        puts "[Chill AI] Không tìm thấy file: #{html_path}"
        return nil
      end

      dialog_options = {
        dialog_title: "Bảng Điều Chỉnh Thông Số Dán Chỉ Cạnh (Chuẩn ABF)",
        preferences_key: "ChillAI_EdgeBandingDialog",
        scrollable: false,
        resizable: true,
        width: 780,
        height: 520,
        min_width: 650,
        min_height: 420,
        left: 180,
        top: 80
      }

      @eb_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_edge_banding_callbacks(@eb_dialog) if defined?(BridgeRouter)

      @eb_dialog.set_on_closed do
        @eb_dialog = nil
      end

      @eb_dialog.set_file(html_path)
      @eb_dialog.show
      @eb_dialog.bring_to_front
      @eb_dialog
    rescue => err
      puts "[Chill AI EdgeBanding Dialog Error]: #{err.message}"
      nil
    end

    def self.close_edge_banding_dialog
      if @eb_dialog
        @eb_dialog.close rescue nil
        @eb_dialog = nil
      end
    end

    # ==========================================================================
    # CỬA SỔ IN TEM NHÃN CHUẨN ABF (KẾT NỐI MÁY IN TEM XPRINTER / GPRINTER & PDF)
    # ==========================================================================
    @print_labels_dialog = nil

    def self.print_labels_dialog
      @print_labels_dialog
    end

    def self.show_print_labels_dialog
      if @print_labels_dialog && @print_labels_dialog.visible?
        @print_labels_dialog.bring_to_front
        return @print_labels_dialog
      end

      root = ModuleLoader.plugin_root
      html_path = File.join(root, 'ui', 'print_labels.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy tệp giao diện In Tem Nhãn tại:\n#{html_path}")
        return nil
      end

      dialog_options = {
        dialog_title: "In Tem Nhãn - Chill AI Interior",
        preferences_key: "ChillAI_PrintLabelsDialog_v1",
        scrollable: false,
        resizable: true,
        width: 980,
        height: 680,
        min_width: 820,
        min_height: 550,
        left: 140,
        top: 60
      }

      @print_labels_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_print_label_callbacks(@print_labels_dialog) if defined?(BridgeRouter)

      @print_labels_dialog.set_on_closed do
        @print_labels_dialog = nil
      end

      @print_labels_dialog.set_file(html_path)
      @print_labels_dialog.show
      @print_labels_dialog.bring_to_front
      @print_labels_dialog
    rescue => err
      puts "[Chill AI Print Labels Dialog Error]: #{err.message}"
      UI.messagebox("Lỗi khi mở Cửa SỔ In Tem Nhãn: #{err.message}")
      nil
    end

    def self.close_print_labels_dialog
      if @print_labels_dialog
        @print_labels_dialog.close rescue nil
        @print_labels_dialog = nil
      end
    end

    # ==========================================================================
    # CỬA SỔ BUNG NỔ MÔ HÌNH / SƠ ĐỒ LẮP RÁP 3D (EXPLODED VIEW CHUẨN ABF)
    # ==========================================================================
    @exploded_hud = nil

    def self.exploded_hud
      @exploded_hud
    end

    def self.show_exploded_hud
      if @exploded_hud && @exploded_hud.visible?
        @exploded_hud.bring_to_front
        return @exploded_hud
      end

      root = ModuleLoader.plugin_root
      html_path = File.join(root, 'ui', 'exploded_view_hud.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy giao diện Exploded View tại:\n#{html_path}")
        return nil
      end

      work_r = @screen_avail_width || 1366
      work_b = @screen_avail_height || 768
      hud_w = 260
      hud_h = 245
      hud_left = [work_r - hud_w - 30, 200].max
      hud_top  = [work_b - hud_h - 60, 100].max

      dialog_options = {
        dialog_title: "Exploded View - Chill AI",
        preferences_key: "ChillAI_ExplodedHUD_v1",
        scrollable: false,
        resizable: true,
        width: hud_w,
        height: hud_h,
        min_width: 220,
        min_height: 220,
        left: hud_left,
        top: hud_top
      }

      @exploded_hud = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_exploded_hud_callbacks(@exploded_hud) if defined?(BridgeRouter)

      @exploded_hud.set_on_closed do
        ExplodedViewEngine.cleanup_texts rescue nil if defined?(ExplodedViewEngine)
        @exploded_hud = nil
      end

      @exploded_hud.set_file(html_path)
      @exploded_hud.show
      @exploded_hud.bring_to_front
      @exploded_hud
    rescue => err
      puts "[Chill AI Exploded HUD Error]: #{err.message}"
      UI.messagebox("Lỗi khi mở Exploded View: #{err.message}")
      nil
    end

    def self.close_exploded_hud
      if @exploded_hud
        @exploded_hud.close rescue nil
        @exploded_hud = nil
      end
    end

    # ==========================================================================
    # CỬA SỔ BẢNG ĐIỀU CHỈNH TRẢI PHẲNG VÁN UỐN CONG (CHUẨN UNITOOL & ABF - ẢNH 2)
    # ==========================================================================
    def self.show_flatten_dialog
      if @flatten_dialog && @flatten_dialog.visible?
        @flatten_dialog.bring_to_front
        return @flatten_dialog
      end

      html_path = File.join(plugin_root, 'ui', 'flatten_dialog.html')
      unless File.exist?(html_path)
        puts "[Chill AI] Không tìm thấy file: #{html_path}"
        return nil
      end

      dialog_options = {
        dialog_title: "Chill AI - Bảng Điều Chỉnh Ván Uốn Cong (Chuẩn UniTool)",
        preferences_key: "ChillAI_FlattenDialog_v1",
        scrollable: false,
        resizable: true,
        width: 540,
        height: 530,
        min_width: 480,
        min_height: 460,
        left: 220,
        top: 100
      }

      @flatten_dialog = UI::HtmlDialog.new(dialog_options)
      BridgeRouter.register_flatten_dialog_callbacks(@flatten_dialog) if defined?(BridgeRouter)

      @flatten_dialog.set_on_closed do
        @flatten_dialog = nil
      end

      @flatten_dialog.set_file(html_path)
      @flatten_dialog.show
      @flatten_dialog.bring_to_front
      @flatten_dialog
    rescue => err
      puts "[Chill AI Flatten Dialog Error]: #{err.message}"
      nil
    end

    def self.close_flatten_dialog
      if @flatten_dialog
        @flatten_dialog.close rescue nil
        @flatten_dialog = nil
      end
    end

end
end
