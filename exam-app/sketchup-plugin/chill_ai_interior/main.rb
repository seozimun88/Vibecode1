# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Main Plugin Entrypoint
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  require_relative 'model_generator'
  require_relative 'dynamic_component'
  require_relative 'cam_gcode'
  require_relative 'audio_player'
  require_relative 'selection_observer'
  require_relative 'structural_engine'

  @dialog = nil

  def self.dialog
    @dialog
  end

  # Force reload toàn bộ các module con mỗi khi mở dialog để không cần restart SketchUp
  def self.reload_modules
    dir = File.dirname(__FILE__)
    ['selection_observer.rb', 'model_generator.rb', 'dynamic_component.rb', 'cam_gcode.rb', 'audio_player.rb', 'structural_engine.rb'].each do |f|
      fpath = File.join(dir, f)
      load fpath if File.exist?(fpath)
    end
    puts "[Chill AI] Đã nạp lại toàn bộ module Ruby mới nhất!"
  end

  def self.show_dialog
    reload_modules

    if @dialog
      begin
        @dialog.close
      rescue => e
      end
      @dialog = nil
    end

    html_path = File.join(File.dirname(__FILE__), 'ui', 'index.html')
    unless File.exist?(html_path)
      UI.messagebox("Không tìm thấy tệp giao diện UI tại: #{html_path}")
      return
    end

    AudioPlayer.ensure_tts_server

    # Kích thước mặc định vừa khít sát mép trên thanh status bar màu trắng của SketchUp
    dock_w = 320
    dock_h = 875
    dock_top = 58
    dock_left = 1208

    @dialog = UI::HtmlDialog.new(
      dialog_title: "Chill AI Interior - Trợ Lý Thiết Kế 3D & Sản Xuất CNC",
      scrollable: false,
      resizable: true,
      width: dock_w,
      height: dock_h,
      min_width: 280,
      min_height: 360,
      left: dock_left,
      top: dock_top
    )

    setup_callbacks(@dialog)

    @dialog.set_on_closed do
      SelectionManager.detach
    end

    @dialog.set_file(html_path)
    @dialog.show

    # Định vị và ép chuẩn kích thước mặc định như ảnh khoanh đỏ của anh Huy
    [0.05, 0.15, 0.4].each do |sec|
      UI.start_timer(sec, false) do
        begin
          if @dialog
            @dialog.set_size(dock_w, dock_h)
            @dialog.set_position(dock_left, dock_top)
          end
        rescue => e
        end
      end
    end

    # Gắn observer giám sát đối tượng 3 tầng vào SketchUp
    SelectionManager.attach(@dialog)
  end

  def self.setup_callbacks(dialog)
    # 1. Nhận lệnh dựng mô hình 3D từ UI (Image Scan hoặc Custom Form)
    dialog.add_action_callback("create_3d_model") do |_action_context, *args|
      begin
        json_params = args.first
        params = json_params.is_a?(String) ? JSON.parse(json_params) : json_params
        instance = ModelGenerator.generate(params)
        
        if instance
          dialog.execute_script("if(window.onSketchUpModelCreated) window.onSketchUpModelCreated(#{instance.entityID.to_json});")
          SelectionManager.handle_selection(Sketchup.active_model.selection, dialog)
          Sketchup.status_text = "Chill AI: Đã tạo mô hình 3D thành công!"
        end
      rescue => e
        UI.messagebox("Lỗi khi tạo mô hình 3D: #{e.message}")
        puts e.backtrace
      end
    end

    # 2. Nhận lệnh sinh hàm Dynamic Component
    dialog.add_action_callback("create_dynamic_component") do |_action_context, *args|
      begin
        json_params = args.first
        params = json_params.is_a?(String) ? JSON.parse(json_params) : json_params
        instance = DynamicComponentBuilder.build_and_attach(params)
        
        if instance
          dialog.execute_script("if(window.onDynamicComponentCreated) window.onDynamicComponentCreated(#{instance.entityID.to_json});")
          Sketchup.status_text = "Chill AI: Đã sinh Dynamic Component thành công!"
        end
      rescue => e
        UI.messagebox("Lỗi khi sinh Dynamic Component: #{e.message}")
      end
    end

    # 3. Nhận lệnh bóc tách tấm và xuất file G-Code
    dialog.add_action_callback("export_gcode") do |_action_context, *args|
      begin
        json_params = args.first
        params = json_params.is_a?(String) ? JSON.parse(json_params) : json_params
        result = CamGCodeExporter.process(params)
        dialog.execute_script("if(window.onGCodeGenerated) window.onGCodeGenerated(#{result.to_json});")
      rescue => e
        UI.messagebox("Lỗi xuất G-Code: #{e.message}")
      end
    end

    # 4. Lưu file G-Code trực tiếp vào máy tính / USB
    dialog.add_action_callback("save_gcode_file") do |_action_context, *args|
      begin
        payload = args.first
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        content = data['content'] || ''
        default_name = data['filename'] || 'CNC_CUT_CODE.nc'

        chosen_path = UI.savepanel("Lưu file G-Code cho máy CNC (Cắm USB)", "", default_name)
        if chosen_path
          File.open(chosen_path, "w:UTF-8") { |f| f.write(content) }
          UI.messagebox("Đã lưu file G-Code thành công tại:\n#{chosen_path}\nBạn có thể copy file này vào USB để cắm trực tiếp vào máy cắt CNC!")
        end
      rescue => e
        UI.messagebox("Không thể lưu file G-Code: #{e.message}")
      end
    end

    # 5. Ghi log kiểm tra
    dialog.add_action_callback("log_message") do |_action_context, *args|
      puts "[Chill AI Plugin]: #{args.first}"
    end

    # 6. Cầu nối âm thanh bản địa (Native Windows Audio Bridge)
    dialog.add_action_callback("play_audio") do |_action_context, *args|
      begin
        payload = args.first
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        AudioPlayer.play(data)
      rescue => e
        puts "[Chill AI Audio Error]: #{e.message}"
      end
    end

    dialog.add_action_callback("stop_audio") do |_action_context, *args|
      AudioPlayer.stop
    end

    # 7. Đảm bảo máy chủ TTS / STT hoạt động theo yêu cầu từ JavaScript
    dialog.add_action_callback("ensure_tts_server") do |_action_context, *args|
      AudioPlayer.ensure_tts_server
    end

    # 8. Zoom tới đối tượng được chọn trong viewport của SketchUp
    dialog.add_action_callback("zoom_selected_entity") do |_action_context, *args|
      entity_id = args.first
      SelectionManager.zoom_to_entity(entity_id)
    end

    # 9. Yêu cầu làm mới/truy vấn vùng chọn 3 tầng hiện tại (Chủ động Polling từ JS)
    dialog.add_action_callback("get_current_selection") do |_action_context, *args|
      model = Sketchup.active_model
      if model && model.selection.count > 0
        SelectionManager.handle_selection(model.selection, dialog)
      else
        SelectionManager.handle_cleared(dialog)
      end
    end

    # 10. JavaScript báo UI đã sẵn sàng tiếp nhận sự kiện 2 chiều (Handshake)
    dialog.add_action_callback("app_ready") do |_action_context, *args|
      SelectionManager.attach(dialog)
      model = Sketchup.active_model
      if model && model.selection.count > 0
        SelectionManager.handle_selection(model.selection, dialog)
      end
    end

    # 11. Chuyển đổi giữa chế độ Khay Đứng (Default Tray Mode) và Toàn Cảnh Studio
    dialog.add_action_callback("set_window_layout_mode") do |_action_context, *args|
      mode = args.first.to_s
      begin
        if mode == 'dock_tray'
          # Kích thước khay đứng vừa vặn giữa Toolbar và Status bar của SketchUp (320x455)
          dialog.set_size(320, 875)
          dialog.set_position(1208, 70)
          puts "[Chill AI]: Đã chuyển sang Chế độ Khay Đứng (320x455) vị trí (1208, 70)"
        else
          # Chế độ Toàn Cảnh Studio ngang rộng
          dialog.set_size(1120, 680)
          dialog.set_position(100, 70)
          puts "[Chill AI]: Đã chuyển sang Chế độ Toàn Cảnh Studio (1120x680)"
        end
      rescue => e
        puts "[Chill AI Resize Error]: #{e.message}"
      end
    end

    # 12. Cho phép người dùng tự do co kéo chiều ngang mà không bị ngắt quãng
    dialog.add_action_callback("lock_dock_height") do |_action_context, *args|
      # Không ép set_size trong khi user đang kéo chuột để tránh làm đơ thao tác resize của Windows
    end

    # Callback phụ trợ tương thích ngược
    dialog.add_action_callback("clamp_dock_size") do |_action_context, *args|
    end

    # 13. Lấy danh sách Preset kết cấu tri thức mộc
    dialog.add_action_callback("get_structural_presets") do |_action_context, *args|
      presets = StructuralEngine.load_presets
      dialog.execute_script("if(window.onStructuralPresetsLoaded) window.onStructuralPresetsLoaded(#{presets.to_json});")
    end

    # 14. Dựng 3D Tủ Áo Kỹ Thuật Chuẩn Mộc & Dynamic DC từ Preset
    dialog.add_action_callback("build_structural_wardrobe") do |_action_context, *args|
      begin
        json_params = args.first
        params = json_params.is_a?(String) ? JSON.parse(json_params) : (json_params || {})
        instance = StructuralEngine.build_wardrobe_structural(params)
        if instance
          dialog.execute_script("if(window.onSketchUpModelCreated) window.onSketchUpModelCreated(#{instance.entityID.to_json});")
          SelectionManager.handle_selection(Sketchup.active_model.selection, dialog)
          Sketchup.status_text = "Chill AI: Đã tạo Tủ Áo Chuẩn Mộc CNC & Dynamic DC thành công!"
        end
      rescue => e
        UI.messagebox("Lỗi tạo tủ chuẩn mộc: #{e.message}")
        puts e.backtrace
      end
    end

    # 15. Lưu cấu hình riêng của xưởng (Custom Preset)
    dialog.add_action_callback("save_custom_preset") do |_action_context, *args|
      begin
        custom_data = args.first
        data = custom_data.is_a?(String) ? JSON.parse(custom_data) : custom_data
        success = StructuralEngine.save_custom_preset(data)
        dialog.execute_script("if(window.onPresetSaved) window.onPresetSaved(#{success.to_json});")
      rescue => e
        puts "[Chill AI] Lỗi save custom preset: #{e.message}"
      end
    end

    # 16. Góp ý & đóng góp tri thức mộc từ cộng đồng
    dialog.add_action_callback("contribute_knowledge") do |_action_context, *args|
      begin
        payload = args.first
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        StructuralEngine.save_contribution(data)
        dialog.execute_script("if(window.onKnowledgeContributed) window.onKnowledgeContributed(true);")
      rescue => e
        puts "[Chill AI] Lỗi contribute knowledge: #{e.message}"
      end
    end
  end

  # Khởi tạo Toolbar & Menu trong SketchUp
  unless file_loaded?(__FILE__)
    cmd = UI::Command.new("Chill AI Interior") { show_dialog }
    cmd.tooltip = "Mở Bảng Điều Khiển Chill AI Interior"
    cmd.status_bar_text = "Tự động tạo mô hình 3D, Dynamic Component và xuất file cắt G-Code CNC bằng AI"
    icon_dir = File.join(File.dirname(__FILE__), 'ui', 'assets')
    cmd.small_icon = File.join(icon_dir, 'icon_16.png')
    cmd.large_icon = File.join(icon_dir, 'icon_24.png')

    # Menu
    menu = UI.menu("Plugins") || UI.menu("Extensions")
    menu.add_item(cmd)
    submenu = menu.add_submenu("Chill AI Interior")
    submenu.add_item(cmd)
    submenu.add_item("🔄 Tải Lại Plugin (Force Reload)") do
      load __FILE__
      show_dialog
    end

    # Toolbar
    toolbar = UI::Toolbar.new("Chill AI Interior")
    toolbar.add_item(cmd)
    toolbar.show

    UI.start_timer(0.2, false) { AudioPlayer.ensure_tts_server }
    UI.start_timer(0.6, false) { show_dialog }

    file_loaded(__FILE__)
  end
end
