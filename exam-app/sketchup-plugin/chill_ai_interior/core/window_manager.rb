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
        if @dialog
          begin
            @dialog.close rescue nil
          rescue => _e
          end
          @dialog = nil
        end
        UI.start_timer(0.12, false) do
          dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
          show_dialog(force_default_pos: true)
          puts "[Chill AI WindowManager] Đã snap vừa khít vùng 3D: #{dock_w}x#{dock_h} tại top=#{dock_top}"
        end
      rescue => err
        UI.messagebox("Lỗi khi đặt lại vị trí cửa sổ: #{err.message}")
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
      if mode.to_s == 'dock_tray'
        dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
        @dialog.set_size(dock_w, dock_h)
        @dialog.set_position(dock_left, dock_top)
        puts "[Chill AI WindowManager]: Snap Khay Đứng (#{dock_w}x#{dock_h} tại top=#{dock_top})"
      else
        @dialog.set_size(1180, 750)
        @dialog.set_position(80, 50)
        puts "[Chill AI WindowManager]: Chuyển sang Studio Mode (1180x750)"
      end
    rescue => e
      puts "[Chill AI Resize Error]: #{e.message}"
    end

    # SNAP KHAY ĐỨNG TỨC THÌ
    def self.snap_to_viewport
      return unless @dialog && @dialog.visible?
      dock_w, dock_h, dock_left, dock_top = calculate_dock_geometry
      @dialog.set_size(dock_w, dock_h)
      @dialog.set_position(dock_left, dock_top)
      puts "[Chill AI WindowManager]: Snap dock #{dock_w}x#{dock_h} tại top=#{dock_top}"
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
  end
end
