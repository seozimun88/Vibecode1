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
      begin
        load fpath if File.exist?(fpath)
      rescue => e
        puts "[Chill AI] Lỗi nạp module #{f}: #{e.message}"
      end
    end
    puts "[Chill AI] Đã nạp lại toàn bộ module Ruby mới nhất!"
  rescue => e
    puts "[Chill AI] Lỗi reload_modules: #{e.message}"
  end

  def self.reset_dialog_position
    begin
      if @dialog && @dialog.visible?
        @dialog.set_position(100, 80)
        @dialog.set_size(340, 840)
        @dialog.bring_to_front
        UI.messagebox("Đã đặt lại vị trí cửa sổ Chill AI về góc trên bên trái màn hình (100, 80)!")
      else
        show_dialog(force_default_pos: true)
      end
    rescue => err
      UI.messagebox("Lỗi khi đặt lại vị trí cửa sổ: #{err.message}")
    end
  end

  def self.show_dialog(force_default_pos: false)
    begin
      reload_modules

      # 1. Nếu dialog đang mở và hiển thị, chỉ cần mang lên phía trước
      if @dialog && @dialog.visible?
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

      html_path = File.join(File.dirname(__FILE__), 'ui', 'index.html')
      unless File.exist?(html_path)
        UI.messagebox("Không tìm thấy tệp giao diện UI tại:\n#{html_path}")
        return nil
      end

      # Kích thước mặc định chuẩn khay dock
      dock_w = 330
      dock_h = 850
      dock_top = 60
      dock_left = 1100

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
      dialog_options[:preferences_key] = "ChillAIInterior_MainWindow_v2026" unless force_default_pos

      @dialog = UI::HtmlDialog.new(dialog_options)

      setup_callbacks(@dialog)

      @dialog.set_on_closed do
        SelectionManager.detach rescue nil
        @dialog = nil
      end

      @dialog.set_file(html_path)
      @dialog.show
      @dialog.bring_to_front

      # Gắn observer giám sát đối tượng 3 tầng vào SketchUp
      SelectionManager.attach(@dialog) rescue nil

      # Kích hoạt TTS Server ngầm
      UI.start_timer(0.4, false) do
        AudioPlayer.ensure_tts_server rescue nil
      end

      @dialog
    rescue => err
      msg = "Lỗi khi mở giao diện Chill AI Interior:\n#{err.message}\n\nChi tiết:\n#{err.backtrace ? err.backtrace.first(4).join("\n") : ''}"
      puts "[Chill AI Fatal] #{msg}"
      UI.messagebox(msg)
      nil
    end
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

    # 4. Lưu file G-Code trực tiếp vào máy tính / USB (Lựa chọn A - Xuất Aspire / CNC)
    dialog.add_action_callback("save_gcode_file") do |_action_context, *args|
      begin
        payload = args.first
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        content = data['content'] || ''
        default_name = data['filename'] || 'CNC_CUT_CODE.nc'

        chosen_path = UI.savepanel("Lưu file G-Code cho máy CNC (Cắm USB / Nạp Aspire)", "", default_name)
        if chosen_path
          File.open(chosen_path, "w:UTF-8") { |f| f.write(content) }
          UI.messagebox("Đã lưu file G-Code thành công tại:\n#{chosen_path}\nBạn có thể copy file này vào USB hoặc nạp trực tiếp vào phần mềm CNC / Aspire!")
        end
      rescue => e
        UI.messagebox("Không thể lưu file G-Code: #{e.message}")
      end
    end

    # 4a. Xuất trực tiếp G-Code 1-chạm (Tự động tính Nesting và mở hộp thoại Lưu G-Code .nc)
    dialog.add_action_callback("export_gcode_direct") do |_action_context, *args|
      begin
        json_params = args.first
        params = (json_params && json_params.is_a?(String)) ? JSON.parse(json_params) : (json_params || {})
        result = CamGCodeExporter.process(params)
        gcode_content = result['gcode'] || ''
        model_name = (params['name'] || 'NESTING').to_s.gsub(/\s+/, '_')
        default_name = "CNC_GCODE_#{model_name}_#{Time.now.strftime('%d%m_%H%M%S')}.nc"
        chosen_path = UI.savepanel("Lưu file G-Code cho máy CNC Router", "", default_name)
        if chosen_path
          File.open(chosen_path, "w:UTF-8") { |f| f.write(gcode_content) }
          UI.messagebox("Đã xuất file G-Code thành công tại:\n#{chosen_path}\n\nTổng cộng #{result['total_parts']} chi tiết trên #{result['sheets'].length} khổ ván.\nBạn có thể nạp thẳng file này vào máy CNC Router để cắt phôi!")
          dialog.execute_script("if(window.onGCodeGenerated) window.onGCodeGenerated(#{result.to_json});")
        end
      rescue => e
        UI.messagebox("Không thể xuất file G-Code: #{e.message}")
      end
    end

    # 4b. Lưu file DXF cho phần mềm Vectric Aspire (Lựa chọn A - Xuất sang Aspire chỉnh sửa)
    dialog.add_action_callback("save_dxf_file") do |_action_context, *args|
      begin
        payload = args.first
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        content = data['content'] || ''
        default_name = data['filename'] || 'CNC_ASPIRE_NESTING.dxf'

        chosen_path = UI.savepanel("Lưu file DXF cho Vectric Aspire", "", default_name)
        if chosen_path
          File.open(chosen_path, "w:UTF-8") { |f| f.write(content) }
          UI.messagebox("Đã lưu file DXF thành công tại:\n#{chosen_path}\nBạn có thể mở trực tiếp vào Vectric Aspire (Import Vectors) để gán đường dao như video Kiếm Thu CNC!")
        end
      rescue => e
        UI.messagebox("Không thể lưu file DXF: #{e.message}")
      end
    end

    # 4c. Xuất trực tiếp DXF 1-chạm (Tự động bóc tách Nesting và mở hộp thoại Lưu DXF)
    dialog.add_action_callback("export_dxf_direct") do |_action_context, *args|
      begin
        result = CamGCodeExporter.export_selected_dxf
        if result && result['status'] == 'success'
          UI.messagebox("Đã xuất DXF 2D thành công:\n#{result['path']}\n\n#{result['total_parts']} chi tiết / #{result['total_sheets']} khổ ván.\nMở file này trong Aspire bằng Import Vectors.")
          dialog.execute_script("if(window.onDxfExported) window.onDxfExported(#{result.to_json});")
        end
      rescue => e
        UI.messagebox("Không thể xuất file DXF: #{e.message}")
      end
    end

    # 4c. Nhận lệnh trải phẳng ván trực tiếp lên mặt bàn SketchUp (Lựa chọn B - Như One Click làm)
    dialog.add_action_callback("nest_to_sketchup") do |_action_context, *args|
      begin
        json_params = args.first
        params = json_params.is_a?(String) ? JSON.parse(json_params) : (json_params || {})
        result = CamGCodeExporter.nest_to_sketchup(params)
        dialog.execute_script("if(window.onNestingToSUCompleted) window.onNestingToSUCompleted(#{result.to_json});")
        if result['status'] == 'success'
          Sketchup.status_text = "Chill AI: Đã trải phẳng #{result['total_sheets']} khổ ván lên mặt bàn SketchUp!"
        else
          UI.messagebox("Lỗi trải phẳng SU: #{result['message']}")
        end
      rescue => e
        UI.messagebox("Lỗi trải phẳng lên SketchUp: #{e.message}")
        puts e.backtrace
      end
    end

    # 4d. Thu về khổ ván tiêu chuẩn 2440mm
    dialog.add_action_callback("clamp_oversized_to_standard") do |_action_context, *args|
      begin
        SelectionManager.clamp_to_standard
      rescue => e
        UI.messagebox("Lỗi khi co kích thước: #{e.message}")
      end
    end

    # 4e. Zoom tiêu điểm đến chi tiết được chọn
    dialog.add_action_callback("zoom_to_entity") do |_action_context, *args|
      begin
        entity_id = args.first
        SelectionManager.zoom_to_entity(entity_id) if entity_id
      rescue => e
        puts "[Chill AI] Lỗi zoom: #{e.message}"
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
        SelectionManager.handle_selection(model.selection, dialog, force: true)
      else
        SelectionManager.handle_cleared(dialog)
      end
    end

    # 9b. Tải lại toàn bộ mã nguồn Ruby & Refresh giao diện
    dialog.add_action_callback("reload_plugin_all") do |_action_context, *args|
      reload_modules
      model = Sketchup.active_model
      SelectionManager.reconnect(model)
      if model && model.selection.count > 0
        SelectionManager.handle_selection(model.selection, dialog, force: true)
      end
      dialog.execute_script("window.location.reload(true);")
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
          # Kích thước khay đứng vừa vặn giữa Toolbar và Status bar của SketchUp (320x875)
          dialog.set_size(320, 875)
          dialog.set_position(1208, 58)
          puts "[Chill AI]: Đã chuyển sang Chế độ Khay Đứng (320x875)"
        else
          # Chế độ Toàn Cảnh Studio ngang rộng
          dialog.set_size(1180, 750)
          dialog.set_position(80, 50)
          puts "[Chill AI]: Đã chuyển sang Chế độ Toàn Cảnh Studio (1180x750)"
        end
      rescue => e
        puts "[Chill AI Resize Error]: #{e.message}"
      end
    end

    # 12. Cho phép người dùng tự do co kéo chiều ngang mà không bị ngắt quãng
    dialog.add_action_callback("lock_dock_height") do |_action_context, *args|
      dialog.set_size(320, 875)
      # Không ép set_size trong khi user đang kéo chuột để tránh làm đơ thao tác resize của Windows
    end

    # Callback phụ trợ tương thích ngược
    dialog.add_action_callback("clamp_dock_size") do |_action_context, *args|
      dialog.set_size(320, 875)
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

    cmd_export_dxf = UI::Command.new('Xuất DXF 2D (Nesting)') do
      result = CamGCodeExporter.export_selected_dxf
      if result['status'] == 'success'
        UI.messagebox("Đã xuất DXF 2D thành công:\n#{result['path']}\n\n#{result['total_parts']} chi tiết / #{result['total_sheets']} khổ ván.\nMở file này trong Aspire bằng Import Vectors.")
      end
    end
    cmd_export_dxf.tooltip = 'Xuất DXF 2D từ model đang chọn cho Vectric Aspire'
    cmd_export_dxf.status_bar_text = 'Chọn model/tấm ván, sau đó xuất sơ đồ Nesting DXF 2D cho Aspire'
    cmd_export_dxf.small_icon = File.join(icon_dir, 'icon_dxf_16.png')
    cmd_export_dxf.large_icon = File.join(icon_dir, 'icon_dxf_24.png')

    # Menu
    menu = UI.menu("Plugins") || UI.menu("Extensions")
    menu.add_item(cmd)
    submenu = menu.add_submenu("Chill AI Interior")
    submenu.add_item(cmd)
    submenu.add_item(cmd_export_dxf)
    submenu.add_item("🔄 Đặt Lại Vị Trí Cửa Sổ (Reset Vị Trí)") do
      reset_dialog_position
    end
    submenu.add_item("🔄 Tải Lại Plugin (Force Reload)") do
      reload_modules
      if @dialog && @dialog.visible?
        @dialog.execute_script("location.reload();")
      else
        show_dialog
      end
    end

    # Toolbar
    toolbar = UI::Toolbar.new("Chill AI Interior")
    toolbar.add_item(cmd)
    toolbar.add_item(cmd_export_dxf)
    toolbar.show

    UI.start_timer(0.4, false) do
      AudioPlayer.ensure_tts_server rescue nil
    end
    UI.start_timer(0.8, false) do
      show_dialog rescue nil
    end

    file_loaded(__FILE__)
  end
end
