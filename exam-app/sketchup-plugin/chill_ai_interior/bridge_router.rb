# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Bridge Router (Quầy Lễ Tân Một Cửa / API Gateway)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# Nguyên tắc: Chuẩn hóa dữ liệu bằng JSON & Phân luồng lệnh độc lập
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module BridgeRouter
    # Cài đặt toàn bộ Callback tiếp nhận thông điệp từ giao diện Chromium CEF
    def self.setup_callbacks(dialog)
      return unless dialog

      # ========================================================================
      # 🎯 KÊNH CHÍNH QUY (UNIFIED DISPATCH CHANNEL): CHUẨN HÓA DỮ LIỆU JSON
      # Định dạng gói tin: { action: "tên_lệnh", data: { ... } }
      # ========================================================================
      dialog.add_action_callback("dispatch") do |_ctx, *args|
        begin
          raw_payload = args.first
          packet = raw_payload.is_a?(String) ? JSON.parse(raw_payload) : (raw_payload || {})
          action = packet['action'].to_s
          data = packet['data'] || {}

          route_action(action, data, dialog)
        rescue => err
          puts "[Chill AI Router Error] Lỗi giải mã gói tin dispatch: #{err.message}"
        end
      end

      # ========================================================================
      # 🔄 ADAPTER TƯƠNG THÍCH NGƯỢC (BACKWARD COMPATIBILITY ADAPTER)
      # Giữ nguyên 100% các callback cũ để app.js không bao giờ bị đứt gãy
      # ========================================================================

      # 1. Dựng hình 3D
      dialog.add_action_callback("create_3d_model") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_create_3d_model(params, dialog)
      end

      # 2. Sinh Dynamic Component
      dialog.add_action_callback("create_dynamic_component") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_create_dynamic_component(params, dialog)
      end

      # 3. Xuất mã G-Code
      dialog.add_action_callback("export_gcode") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_export_gcode(params, dialog)
      end

      # 4. Lưu file G-Code vào đĩa/USB
      dialog.add_action_callback("save_gcode_file") do |_ctx, *args|
        data = parse_json_arg(args.first)
        handle_save_gcode_file(data)
      end

      # 4a. Xuất G-Code trực tiếp 1-chạm
      dialog.add_action_callback("export_gcode_direct") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_export_gcode_direct(params, dialog)
      end

      # 4b. Lưu file DXF cho Vectric Aspire
      dialog.add_action_callback("save_dxf_file") do |_ctx, *args|
        data = parse_json_arg(args.first)
        handle_save_dxf_file(data)
      end

      # 4c. Xuất DXF 2D trực tiếp 1-chạm
      dialog.add_action_callback("export_dxf_direct") do |_ctx, *args|
        handle_export_dxf_direct(dialog)
      end

      # 4d. Trải phẳng ván lên mặt bàn SketchUp (One Click style)
      dialog.add_action_callback("nest_to_sketchup") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_nest_to_sketchup(params, dialog)
      end

      # 4e. Co về khổ ván tiêu chuẩn 2440mm
      dialog.add_action_callback("clamp_oversized_to_standard") do |_ctx, *args|
        SelectionManager.clamp_to_standard rescue nil if defined?(SelectionManager)
      end

      # 4f. Zoom tiêu điểm tới chi tiết
      dialog.add_action_callback("zoom_to_entity") do |_ctx, *args|
        entity_id = args.first
        SelectionManager.zoom_to_entity(entity_id) rescue nil if defined?(SelectionManager) && entity_id
      end

      # 5. Ghi log kiểm tra
      dialog.add_action_callback("log_message") do |_ctx, *args|
        puts "[Chill AI Plugin]: #{args.first}"
      end

      # 6. Cầu nối âm thanh Windows Media Player
      dialog.add_action_callback("play_audio") do |_ctx, *args|
        data = parse_json_arg(args.first)
        AudioPlayer.play(data) rescue nil if defined?(AudioPlayer)
      end

      dialog.add_action_callback("stop_audio") do |_ctx, *args|
        AudioPlayer.stop rescue nil if defined?(AudioPlayer)
      end

      # 7. Đảm bảo máy chủ TTS hoạt động
      dialog.add_action_callback("ensure_tts_server") do |_ctx, *args|
        AudioPlayer.ensure_tts_server rescue nil if defined?(AudioPlayer)
      end

      # 8. Yêu cầu lấy thông tin vùng chọn hiện tại
      dialog.add_action_callback("get_current_selection") do |_ctx, *args|
        if defined?(SelectionManager)
          model = Sketchup.active_model
          if model && model.selection.count > 0
            SelectionManager.handle_selection(model.selection, dialog, force: true)
          else
            SelectionManager.handle_cleared(dialog)
          end
        end
      end

      # 9. TẢI LẠI TOÀN BỘ MÃ NGUỒN RUBY (HOT-RELOAD SẠCH RAM)
      dialog.add_action_callback("reload_plugin_all") do |_ctx, *args|
        ModuleLoader.reload_all if defined?(ModuleLoader)
        UI.start_timer(0.05, false) do
          WindowManager.reset_dialog_position if defined?(WindowManager)
        end
      end

      # 10. Handshake khi giao diện khởi động xong
      dialog.add_action_callback("app_ready") do |_ctx, *args|
        payload = parse_json_arg(args.first)
        if payload.is_a?(Hash) && payload['availHeight']
          WindowManager.set_screen_metrics(payload['availWidth'], payload['availHeight']) if defined?(WindowManager)
        end
        WindowManager.snap_to_viewport if defined?(WindowManager)
        if defined?(SelectionManager)
          SelectionManager.attach(dialog)
          model = Sketchup.active_model
          if model && model.selection.count > 0
            SelectionManager.handle_selection(model.selection, dialog)
          end
        end
      end

      # 11. Đổi chế độ cửa sổ
      dialog.add_action_callback("set_window_layout_mode") do |_ctx, *args|
        mode = args.first.to_s
        WindowManager.set_layout_mode(mode) if defined?(WindowManager)
      end

      dialog.add_action_callback("lock_dock_height") do |_ctx, *args|
        WindowManager.snap_to_viewport if defined?(WindowManager)
      end

      dialog.add_action_callback("clamp_dock_size") do |_ctx, *args|
        WindowManager.snap_to_viewport if defined?(WindowManager)
      end

      dialog.add_action_callback("snap_dock_to_viewport") do |_ctx, *args|
        WindowManager.snap_to_viewport if defined?(WindowManager)
      end

      # 12. Tri thức mộc & Preset tủ áo
      dialog.add_action_callback("get_structural_presets") do |_ctx, *args|
        if defined?(StructuralEngine)
          presets = StructuralEngine.load_presets
          dialog.execute_script("if(window.onStructuralPresetsLoaded) window.onStructuralPresetsLoaded(#{presets.to_json});")
        end
      end

      dialog.add_action_callback("build_structural_wardrobe") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_build_wardrobe(params, dialog)
      end

      dialog.add_action_callback("save_custom_preset") do |_ctx, *args|
        data = parse_json_arg(args.first)
        if defined?(StructuralEngine)
          success = StructuralEngine.save_custom_preset(data)
          dialog.execute_script("if(window.onPresetSaved) window.onPresetSaved(#{success.to_json});")
        end
      end

      dialog.add_action_callback("contribute_knowledge") do |_ctx, *args|
        data = parse_json_arg(args.first)
        if defined?(StructuralEngine)
          StructuralEngine.save_contribution(data)
          dialog.execute_script("if(window.onKnowledgeContributed) window.onKnowledgeContributed(true);")
        end
      end

      # 13. Phụ kiện liên kết Cam Chốt Minifix & Bản Lề (Chưng cất từ ABF)
      dialog.add_action_callback("apply_cam_locks") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_apply_cam_locks(params, dialog)
      end

      dialog.add_action_callback("apply_hinges") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_apply_hinges(params, dialog)
      end

      dialog.add_action_callback("clear_fittings") do |_ctx, *args|
        handle_clear_fittings(dialog)
      end

      # 14. Bảng Cấu Hình Cam Chốt (Fitting Studio)
      dialog.add_action_callback("open_fitting_studio") do |_ctx, *args|
        WindowManager.show_fitting_studio if defined?(WindowManager)
      end

      dialog.add_action_callback("close_fitting_studio") do |_ctx, *args|
        WindowManager.close_fitting_studio if defined?(WindowManager)
      end

      # 15. Kích hoạt công cụ 3D Liên Kết Ngang (Click đúp)
      dialog.add_action_callback("activate_fitting_tool") do |_ctx, *args|
        FittingTool.activate_tool if defined?(FittingTool)
      end
    end

    # ==========================================================================
    # CÁC HÀM XỬ LÝ CHUYÊN MÔN THEO SERVICE
    # ==========================================================================

    def self.route_action(action, data, dialog)
      case action
      when 'create_3d_model'
        handle_create_3d_model(data, dialog)
      when 'build_wardrobe'
        handle_build_wardrobe(data, dialog)
      when 'apply_cam_locks'
        handle_apply_cam_locks(data, dialog)
      when 'apply_hinges'
        handle_apply_hinges(data, dialog)
      when 'clear_fittings'
        handle_clear_fittings(dialog)
      when 'open_fitting_studio'
        WindowManager.show_fitting_studio if defined?(WindowManager)
      when 'close_fitting_studio'
        WindowManager.close_fitting_studio if defined?(WindowManager)
      when 'get_fitting_presets'
        handle_get_fitting_presets(dialog)
      when 'save_fitting_presets'
        handle_save_fitting_presets(data, dialog)
      when 'apply_fitting_preset'
        handle_apply_cam_locks(data, dialog)
      when 'activate_fitting_tool'
        FittingTool.activate_tool if defined?(FittingTool)
      when 'export_gcode'
        handle_export_gcode(data, dialog)
      when 'export_dxf'
        handle_export_dxf_direct(dialog)
      when 'reload_plugin'
        ModuleLoader.reload_all if defined?(ModuleLoader)
        WindowManager.snap_to_viewport if defined?(WindowManager)
      when 'snap_dock'
        WindowManager.snap_to_viewport if defined?(WindowManager)
      when 'play_sound'
        AudioPlayer.play(data) if defined?(AudioPlayer)
      else
        puts "[Chill AI Router] Action không xác định: #{action}"
      end
    end

    def self.handle_apply_cam_locks(params, dialog)
      if defined?(FittingEngine)
        res = FittingEngine.apply_cam_locks(params, dialog)
        if res && res[:status] == 'success' && defined?(AudioPlayer)
          count = res[:total] || res[:cams] || 0
          name = res[:preset] || "Cam chốt"
          AudioPlayer.play({ 'text' => "Đã tạo thành công #{count} lỗ liên kết #{name} rồi anh Huy nhé!" }) rescue nil
        end
      end
    end

    def self.handle_get_fitting_presets(dialog)
      if defined?(FittingEngine)
        data = FittingEngine.load_presets
        dialog.execute_script("if(window.onPresetsLoaded) window.onPresetsLoaded(#{data.to_json});")
      end
    end

    def self.handle_save_fitting_presets(data, dialog)
      if defined?(FittingEngine)
        success = FittingEngine.save_presets(data)
        if success
          dialog.execute_script("if(window.showToast) window.showToast('Đã lưu cấu hình Preset thành công!', 'success');")
        else
          dialog.execute_script("if(window.showToast) window.showToast('Lỗi khi lưu cấu hình Preset!', 'error');")
        end
      end
    end

    # Cài đặt toàn bộ Callback cho Cửa sổ Bảng Cam Chốt (Fitting Studio)
    def self.register_fitting_studio_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("get_fitting_presets") do |_ctx, *args|
        handle_get_fitting_presets(dialog)
      end

      dialog.add_action_callback("save_fitting_presets") do |_ctx, *args|
        data = parse_json_arg(args.first)
        handle_save_fitting_presets(data, dialog)
      end

      dialog.add_action_callback("apply_fitting_preset") do |_ctx, *args|
        preset = parse_json_arg(args.first)
        handle_apply_cam_locks(preset, dialog)
      end

      dialog.add_action_callback("activate_fitting_tool") do |_ctx, *args|
        preset = parse_json_arg(args.first)
        FittingTool.activate_tool(preset) if defined?(FittingTool)
      end

      dialog.add_action_callback("close_fitting_studio") do |_ctx, *args|
        WindowManager.close_fitting_studio if defined?(WindowManager)
      end

      dialog.add_action_callback("dispatch") do |_ctx, *args|
        raw_payload = args.first
        packet = raw_payload.is_a?(String) ? JSON.parse(raw_payload) : (raw_payload || {})
        action = packet['action'].to_s
        data = packet['data'] || {}
        route_action(action, data, dialog)
      end
    end

    def self.handle_apply_hinges(params, dialog)
      if defined?(FittingEngine)
        res = FittingEngine.apply_hinges(params, dialog)
        if res && res[:status] == 'success' && defined?(AudioPlayer)
          AudioPlayer.play({ 'text' => "Đã tạo thành công #{res[:hinges]} chén bản lề 35mm cho cánh tủ rồi anh Huy nhé!" }) rescue nil
        end
      end
    end

    def self.handle_clear_fittings(dialog)
      if defined?(FittingEngine)
        FittingEngine.clear_fittings(dialog)
      end
    end

    def self.handle_create_3d_model(params, dialog)
      if defined?(ModelGenerator)
        instance = ModelGenerator.generate(params)
        if instance
          dialog.execute_script("if(window.onSketchUpModelCreated) window.onSketchUpModelCreated(#{instance.entityID.to_json});")
          SelectionManager.handle_selection(Sketchup.active_model.selection, dialog) if defined?(SelectionManager)
          Sketchup.status_text = "Chill AI: Đã tạo mô hình 3D thành công!"
        end
      end
    rescue => e
      UI.messagebox("Lỗi khi tạo mô hình 3D: #{e.message}")
    end

    def self.handle_create_dynamic_component(params, dialog)
      if defined?(DynamicComponentBuilder)
        instance = DynamicComponentBuilder.build_and_attach(params)
        if instance
          dialog.execute_script("if(window.onDynamicComponentCreated) window.onDynamicComponentCreated(#{instance.entityID.to_json});")
          Sketchup.status_text = "Chill AI: Đã sinh Dynamic Component thành công!"
        end
      end
    rescue => e
      UI.messagebox("Lỗi khi sinh Dynamic Component: #{e.message}")
    end

    def self.handle_export_gcode(params, dialog)
      if defined?(CamGCodeExporter)
        result = CamGCodeExporter.process(params)
        dialog.execute_script("if(window.onGCodeGenerated) window.onGCodeGenerated(#{result.to_json});")
      end
    rescue => e
      UI.messagebox("Lỗi xuất G-Code: #{e.message}")
    end

    def self.handle_save_gcode_file(data)
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

    def self.handle_export_gcode_direct(params, dialog)
      if defined?(CamGCodeExporter)
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
      end
    rescue => e
      UI.messagebox("Không thể xuất file G-Code: #{e.message}")
    end

    def self.handle_save_dxf_file(data)
      content = data['content'] || ''
      default_name = data['filename'] || 'CNC_ASPIRE_NESTING.dxf'
      chosen_path = UI.savepanel("Lưu file DXF cho Vectric Aspire", "", default_name)
      if chosen_path
        File.open(chosen_path, "w:UTF-8") { |f| f.write(content) }
        UI.messagebox("Đã lưu file DXF thành công tại:\n#{chosen_path}\nBạn có thể mở trực tiếp vào Vectric Aspire (Import Vectors) để gán đường dao!")
      end
    rescue => e
      UI.messagebox("Không thể lưu file DXF: #{e.message}")
    end

    def self.handle_export_dxf_direct(dialog)
      if defined?(CamGCodeExporter)
        result = CamGCodeExporter.export_selected_dxf
        if result && result['status'] == 'success'
          UI.messagebox("Đã xuất DXF 2D thành công:\n#{result['path']}\n\n#{result['total_parts']} chi tiết / #{result['total_sheets']} khổ ván.\nMở file này trong Aspire bằng Import Vectors.")
          dialog.execute_script("if(window.onDxfExported) window.onDxfExported(#{result.to_json});")
        end
      end
    rescue => e
      UI.messagebox("Không thể xuất file DXF: #{e.message}")
    end

    def self.handle_nest_to_sketchup(params, dialog)
      if defined?(CamGCodeExporter)
        result = CamGCodeExporter.nest_to_sketchup(params)
        dialog.execute_script("if(window.onNestingToSUCompleted) window.onNestingToSUCompleted(#{result.to_json});")
        if result['status'] == 'success'
          Sketchup.status_text = "Chill AI: Đã trải phẳng #{result['total_sheets']} khổ ván lên mặt bàn SketchUp!"
        else
          UI.messagebox("Lỗi trải phẳng SU: #{result['message']}")
        end
      end
    rescue => e
      UI.messagebox("Lỗi trải phẳng lên SketchUp: #{e.message}")
    end

    def self.handle_build_wardrobe(params, dialog)
      if defined?(StructuralEngine)
        instance = StructuralEngine.build_wardrobe_structural(params)
        if instance
          dialog.execute_script("if(window.onSketchUpModelCreated) window.onSketchUpModelCreated(#{instance.entityID.to_json});")
          SelectionManager.handle_selection(Sketchup.active_model.selection, dialog) if defined?(SelectionManager)
          Sketchup.status_text = "Chill AI: Đã tạo Tủ Áo Chuẩn Mộc CNC & Dynamic DC thành công!"
        end
      end
    rescue => e
      UI.messagebox("Lỗi tạo tủ chuẩn mộc: #{e.message}")
    end

    def self.parse_json_arg(arg)
      return {} if arg.nil?
      return arg if arg.is_a?(Hash)
      return JSON.parse(arg) if arg.is_a?(String)
      arg
    rescue => _e
      {}
    end
  end
end
