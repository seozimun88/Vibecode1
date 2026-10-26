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

      # Mở URL ngoài trình duyệt hệ thống (Google Auth / Portal)
      dialog.add_action_callback("open_external_url") do |_ctx, *args|
        url = args.first.to_s
        UI.openURL(url) if url.start_with?('http://', 'https://')
      end

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

      # 4g. Quy trình 4 bước ABF: Gắn nhãn tự động
      dialog.add_action_callback("cnc_auto_label") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_cnc_auto_label(params, dialog)
      end

      # 4h. Quy trình 4 bước ABF: Hiệu chỉnh mặt gia công
      dialog.add_action_callback("cnc_flip_face") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_cnc_flip_face(params, dialog)
      end

      # 4i. Quy trình 4 bước ABF: Hiệu chỉnh chiều vân gỗ
      dialog.add_action_callback("cnc_toggle_grain") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_cnc_toggle_grain(params, dialog)
      end

      # 4j. Cấu hình nhãn chuẩn ABF: Get & Save config
      dialog.add_action_callback("get_label_config") do |_ctx, *args|
        cfg = defined?(LabelingEngine) ? LabelingEngine.get_config : {}
        dialog.execute_script("if(window.onLabelConfigLoaded) window.onLabelConfigLoaded(#{cfg.to_json});")
      end

      dialog.add_action_callback("save_label_config") do |_ctx, *args|
        params = parse_json_arg(args.first)
        cfg = defined?(LabelingEngine) ? LabelingEngine.save_config(params) : {}
        dialog.execute_script("if(window.onLabelConfigSaved) window.onLabelConfigSaved(#{cfg.to_json});")
      end

      dialog.add_action_callback("apply_abf_labels") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        sel_only = params['selection_only'] ? true : false
        cfg = params['config']
        result = defined?(LabelingEngine) ? LabelingEngine.apply_labels(sel_only, cfg) : {}
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('label', #{result.to_json});")
      end

      dialog.add_action_callback("rotate_grain_angle") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        angle = (params['angle'] || 90.0).to_f
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(LabelingEngine) ? LabelingEngine.rotate_grain_direction(angle, sel_only) : {}
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
      end

      dialog.add_action_callback("set_grain_angle") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        angle = (params['angle'] || 0.0).to_f
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(LabelingEngine) ? LabelingEngine.set_grain_angle(angle, sel_only) : {}
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
      end

      dialog.add_action_callback("open_grain_palette") do |_ctx, *args|
        WindowManager.show_grain_palette if defined?(WindowManager)
      end

      dialog.add_action_callback("close_grain_palette") do |_ctx, *args|
        WindowManager.close_grain_palette if defined?(WindowManager)
      end

      dialog.add_action_callback("open_rename_dialog") do |_ctx, *args|
        WindowManager.show_rename_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("close_rename_dialog") do |_ctx, *args|
        WindowManager.close_rename_dialog if defined?(WindowManager)
      end

            dialog.add_action_callback("open_print_labels_dialog") do |_ctx, *args|
        begin
          core_dir = File.join(File.dirname(__FILE__), 'core')
          ['print_label_engine.rb', 'window_manager.rb'].each do |fn|
            fp = File.join(core_dir, fn)
            load fp if File.exist?(fp)
          end
        rescue => _e
        end
        WindowManager.show_print_labels_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("close_print_labels_dialog") do |_ctx, *args|
        WindowManager.close_print_labels_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("open_exploded_view") do |_ctx, *args|
        begin
          core_dir = File.join(File.dirname(__FILE__), 'core')
          ['exploded_view_engine.rb', 'window_manager.rb'].each do |fn|
            fp = File.join(core_dir, fn)
            load fp if File.exist?(fp)
          end
        rescue => _e
        end
        WindowManager.show_exploded_hud if defined?(WindowManager)
      end

      dialog.add_action_callback("close_exploded_hud") do |_ctx, *args|
        WindowManager.close_exploded_hud if defined?(WindowManager)
      end

      dialog.add_action_callback("open_report_dialog") do |_ctx, *args|
        WindowManager.show_report_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("close_report_dialog") do |_ctx, *args|
        WindowManager.close_report_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("clear_abf_labels") do |_ctx, *args|
        result = defined?(LabelingEngine) ? LabelingEngine.clear_all_labels : {}
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('clear_label', #{result.to_json});")
      end

      # 4k. Tiết diện giao nhau (Ngàm âm dương / Rãnh hậu / Mộng xương chó chuẩn ABF)
      dialog.add_action_callback("get_intersect_presets") do |_ctx, *args|
        handle_get_intersect_presets(dialog)
      end

      dialog.add_action_callback("save_intersect_presets") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_save_intersect_presets(params, dialog)
      end

      dialog.add_action_callback("apply_intersection") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_apply_intersection(params, dialog)
      end

                  dialog.add_action_callback("activate_edge_banding_tool") do |_ctx, *args|
        EdgeBandingTool.activate_tool if defined?(EdgeBandingTool)
      end

      dialog.add_action_callback("open_edge_banding_dialog") do |_ctx, *args|
        WindowManager.show_edge_banding_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("activate_stretch_tool") do |_ctx, *args|
        StretchTool.activate_tool if defined?(StretchTool)
      end

      dialog.add_action_callback("activate_intersect_tool") do |_ctx, *args|
        params = parse_json_arg(args.first)
        handle_activate_intersect_tool(params, dialog)
      end

      dialog.add_action_callback("clear_intersections") do |_ctx, *args|
        handle_clear_intersections(dialog)
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
        puts "[Chill AI BridgeRouter] Đã hot-reload tươi mới mã nguồn Ruby vào RAM (Không tạo thêm cửa sổ)."
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

      # 15b. Kích hoạt công cụ 3D Khoan Bản Lề Chuẩn ABF (Chọn Cánh -> Chọn Hông)
      dialog.add_action_callback("activate_hinge_tool") do |_ctx, *args|
        HingeTool.activate_tool if defined?(HingeTool)
      end

      # 16. Cầu nối Ollama Local LLM (gemma4:e4b) - Không bị chặn CORS trong CEF
      dialog.add_action_callback("call_ollama") do |_ctx, *args|
        payload = parse_json_arg(args.first)
        handle_call_ollama(payload, dialog)
      end

      dialog.add_action_callback("check_ollama") do |_ctx, *args|
        handle_check_ollama(dialog)
      end
    end

    # ==========================================================================
    # CÁC HÀM XỬ LÝ CHUYÊN MÔN THEO SERVICE
    # ==========================================================================

    def self.route_action(action, data, dialog)
      case action
      when 'open_external_url'
        url = data['url'].to_s
        UI.openURL(url) if url.start_with?('http://', 'https://')
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
      when 'activate_hinge_tool'
        HingeTool.activate_tool if defined?(HingeTool)
      when 'get_intersect_presets'
        handle_get_intersect_presets(dialog)
      when 'save_intersect_presets'
        handle_save_intersect_presets(data, dialog)
      when 'apply_intersection'
        handle_apply_intersection(data, dialog)
      when 'activate_edge_banding_tool'
        EdgeBandingTool.activate_tool if defined?(EdgeBandingTool)
      when 'open_edge_banding_dialog'
        WindowManager.show_edge_banding_dialog if defined?(WindowManager)
      when 'open_flatten_dialog', 'show_flatten_dialog'
        WindowManager.show_flatten_dialog if defined?(WindowManager)
      when 'activate_flatten_tool'
        FlattenTool.activate_tool(data) if defined?(FlattenTool)
      when 'get_flatten_config'
        cfg = defined?(FlattenEngine) ? FlattenEngine.get_config : {}
        dialog.execute_script("if(window.receiveFlattenConfig) window.receiveFlattenConfig(#{cfg.to_json});")
      when 'save_flatten_config'
        cfg = defined?(FlattenEngine) ? FlattenEngine.save_config(data) : {}
        dialog.execute_script("if(window.receiveFlattenConfig) window.receiveFlattenConfig(#{cfg.to_json});")
      when 'apply_flatten_panel'
        handle_apply_flatten_panel(data, dialog)
      when 'activate_stretch_tool'
        StretchTool.activate_tool if defined?(StretchTool)
      when 'activate_intersect_tool'
        handle_activate_intersect_tool(data, dialog)
      when 'clear_intersections'
        handle_clear_intersections(dialog)
      when 'export_gcode'
        handle_export_gcode(data, dialog)
      when 'export_dxf'
        handle_export_dxf_direct(dialog)
when 'open_exploded_view', 'show_exploded_hud', 'exploded_view'
        begin
          core_dir = File.join(File.dirname(__FILE__), 'core')
          ['exploded_view_engine.rb', 'window_manager.rb'].each do |fn|
            fp = File.join(core_dir, fn)
            load fp if File.exist?(fp)
          end
        rescue => _e
        end
        WindowManager.show_exploded_hud if defined?(WindowManager)
      when 'open_print_labels_dialog', 'print_labels', 'in_tem'
        begin
          plugins_dir = Sketchup.find_support_file("Plugins") rescue nil
          search_dirs = [
            (defined?(PLUGIN_ROOT) ? File.join(PLUGIN_ROOT, 'core') : nil),
            (plugins_dir ? File.join(plugins_dir, 'chill_ai_interior', 'core') : nil)
          ].compact.uniq
          search_dirs.each do |cd|
            ['print_label_engine.rb', 'window_manager.rb'].each do |fn|
              fp = File.join(cd, fn)
              load fp if File.exist?(fp)
            end
          end
        rescue => _e
        end
        WindowManager.show_print_labels_dialog if defined?(WindowManager)
      when 'snap_dock', 'snap_dock_to_viewport', 'snap_to_viewport'
        WindowManager.snap_to_viewport if defined?(WindowManager)
      when 'open_report_dialog', 'open_statistics'
        WindowManager.show_report_dialog if defined?(WindowManager)
      when 'reload_plugin'
        ModuleLoader.reload_all if defined?(ModuleLoader)
        WindowManager.snap_to_viewport if defined?(WindowManager)
      when 'snap_dock'
        WindowManager.snap_to_viewport if defined?(WindowManager)
      when 'play_sound'
        AudioPlayer.play(data) if defined?(AudioPlayer)
      when 'call_ollama'
        handle_call_ollama(data, dialog)
      when 'check_ollama'
        handle_check_ollama(dialog)
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
      # Cưỡng bức Hot-Reload tự động nạp đè tươi mới các module Lego vào RAM của SketchUp
      begin
        plugins_dir = Sketchup.find_support_file("Plugins") rescue nil
        search_dirs = [
          (defined?(PLUGIN_ROOT) ? File.join(PLUGIN_ROOT, 'core') : nil),
          (plugins_dir ? File.join(plugins_dir, 'chill_ai_interior', 'core') : nil),
          File.expand_path(File.join(File.dirname(__FILE__), 'core'))
        ].compact.uniq

        loaded_files = []
        search_dirs.each do |cd|
          if Dir.exist?(cd)
            ['edge_banding_engine.rb', 'labeling_engine.rb', 'cam_gcode.rb'].each do |fn|
              fp = File.join(cd, fn)
              if File.exist?(fp)
                load fp
                loaded_files << fn
              end
            end
          end
        end

        root_dir = defined?(PLUGIN_ROOT) ? PLUGIN_ROOT : (plugins_dir ? File.join(plugins_dir, 'chill_ai_interior') : File.dirname(__FILE__))
        log_fp = File.join(root_dir, 'runtime_nest.log')
        File.open(log_fp, 'a') do |f|
          f.puts("[#{Time.now}] handle_nest_to_sketchup executed with fresh modules: #{loaded_files.uniq.join(', ')}")
        end rescue nil
      rescue => e
        UI.messagebox("Lỗi hot-reload: #{e.message}") rescue nil
      end

      if defined?(CamGCodeExporter)
        result = CamGCodeExporter.nest_to_sketchup(params)
        dialog.execute_script("if(window.onNestingToSUCompleted) window.onNestingToSUCompleted(#{result.to_json});")
        if result['status'] == 'success'
          Sketchup.status_text = "Chill AI: Đã trải phẳng #{result['total_sheets']} khổ ván lên mặt bàn SketchUp (Chuẩn ABF DXF)!"
          WindowManager.snap_to_viewport rescue nil if defined?(WindowManager)
        else
          UI.messagebox("Lỗi trải phẳng SU: #{result['message']}")
        end
      end
    rescue => e
      UI.messagebox("Lỗi trải phẳng lên SketchUp: #{e.message}")
    end

    def self.handle_cnc_auto_label(params, dialog)
      core_dir = File.join(File.dirname(__FILE__), 'core')
      ['labeling_engine.rb', 'cam_gcode.rb', 'edge_banding_engine.rb'].each do |fn|
        fp = File.join(core_dir, fn)
        load fp if File.exist?(fp)
      end

      sel_only = params.is_a?(Hash) && params['selection_only'] ? true : false
      if defined?(LabelingEngine)
        result = LabelingEngine.apply_labels(sel_only)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('label', #{result.to_json});")
      elsif defined?(CamGCodeExporter)
        result = CamGCodeExporter.auto_label_parts(sel_only)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('label', #{result.to_json});")
      end
    rescue => e
      UI.messagebox("Lỗi gắn nhãn: #{e.message}")
    end

    def self.handle_cnc_flip_face(params, dialog)
      if defined?(LabelingEngine)
        result = LabelingEngine.flip_machining_face(true)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('flip_face', #{result.to_json});")
      elsif defined?(CamGCodeExporter)
        result = CamGCodeExporter.flip_machining_face(true)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('flip_face', #{result.to_json});")
      end
    rescue => e
      UI.messagebox("Lỗi đổi mặt gia công: #{e.message}")
    end

    def self.handle_cnc_toggle_grain(params, dialog)
      if defined?(LabelingEngine)
        result = LabelingEngine.rotate_grain_direction(90.0, true)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
      elsif defined?(CamGCodeExporter)
        result = CamGCodeExporter.toggle_grain_direction(true)
        dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
      end
    rescue => e
      UI.messagebox("Lỗi chỉnh chiều vân gỗ: #{e.message}")
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

    # ==========================================================================
    # CẦU NỐI OLLAMA LOCAL LLM (gemma4:e4b) - THỰC THI LUỒNG NỀN KHÔNG BLOCK UI
    # ==========================================================================
    def self.handle_call_ollama(payload, dialog)
      return unless dialog
      Thread.new do
        begin
          require 'net/http'
          require 'uri'

          model_name = payload['model'] || 'gemma4:e4b'
          messages = payload['messages'] || []
          if messages.empty? && payload['prompt']
            messages = [{ 'role' => 'user', 'content' => payload['prompt'].to_s }]
          end
          callback_id = payload['callback_id'] || 'default'

          uri = URI.parse("http://127.0.0.1:11434/api/chat")
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 5
          http.read_timeout = 90 # Cho phép inference tới 90s trên GPU/CPU local

          req = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json; charset=utf-8' })
          req.body = {
            'model' => model_name,
            'messages' => messages,
            'stream' => false
          }.to_json

          res = http.request(req)
          if res.is_a?(Net::HTTPSuccess)
            raw_body = res.body
            raw_body = raw_body.force_encoding('UTF-8') if raw_body.respond_to?(:force_encoding)
            parsed = JSON.parse(raw_body)
            reply_text = parsed.dig('message', 'content') || parsed['response'] || ''
            js_payload = { 'success' => true, 'text' => reply_text, 'callback_id' => callback_id }.to_json
            UI.start_timer(0.01, false) do
              dialog.execute_script("if(window.onOllamaChatResponse) window.onOllamaChatResponse(#{js_payload});")
            end
          else
            err_msg = "Ollama phản hồi mã lỗi HTTP #{res.code}: #{res.message}"
            js_payload = { 'success' => false, 'error' => err_msg, 'callback_id' => callback_id }.to_json
            UI.start_timer(0.01, false) do
              dialog.execute_script("if(window.onOllamaChatResponse) window.onOllamaChatResponse(#{js_payload});")
            end
          end
        rescue => e
          err_msg = "Không thể kết nối Ollama local: #{e.message}. Anh Huy kiểm tra lệnh 'ollama serve' hoặc model 'gemma4:e4b' đã tải chưa nhé."
          js_payload = { 'success' => false, 'error' => err_msg, 'callback_id' => callback_id }.to_json
          UI.start_timer(0.01, false) do
            dialog.execute_script("if(window.onOllamaChatResponse) window.onOllamaChatResponse(#{js_payload});")
          end
        end
      end
    end

    def self.handle_check_ollama(dialog)
      return unless dialog
      Thread.new do
        begin
          require 'net/http'
          require 'uri'
          uri = URI.parse("http://127.0.0.1:11434/api/tags")
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 3
          http.read_timeout = 3
          req = Net::HTTP::Get.new(uri.path)
          res = http.request(req)
          if res.is_a?(Net::HTTPSuccess)
            raw_body = res.body
            raw_body = raw_body.force_encoding('UTF-8') if raw_body.respond_to?(:force_encoding)
            parsed = JSON.parse(raw_body)
            models = (parsed['models'] || []).map { |m| m['name'] }
            has_gemma = models.any? { |n| n.to_s.include?('gemma4') || n.to_s.include?('gemma') }
            js_payload = { 'running' => true, 'models' => models, 'has_gemma' => has_gemma }.to_json
            UI.start_timer(0.01, false) do
              dialog.execute_script("if(window.onOllamaStatusChecked) window.onOllamaStatusChecked(#{js_payload});")
            end
          else
            js_payload = { 'running' => false, 'error' => "HTTP #{res.code}" }.to_json
            UI.start_timer(0.01, false) do
              dialog.execute_script("if(window.onOllamaStatusChecked) window.onOllamaStatusChecked(#{js_payload});")
            end
          end
        rescue => e
          js_payload = { 'running' => false, 'error' => e.message }.to_json
          UI.start_timer(0.01, false) do
            dialog.execute_script("if(window.onOllamaStatusChecked) window.onOllamaStatusChecked(#{js_payload});")
          end
        end
      end
    end

    # --- TIẾT DIỆN GIAO NHAU (CHUẨN ABF) ---
    def self.handle_get_intersect_presets(dialog)
      return unless dialog
      presets = defined?(IntersectEngine) ? IntersectEngine.get_presets : []
      active = defined?(IntersectEngine) ? IntersectEngine.get_active_preset : {}
      payload = { 'presets' => presets, 'active' => active }.to_json
      dialog.execute_script("if(window.onIntersectPresetsLoaded) window.onIntersectPresetsLoaded(#{payload});")
    end

    def self.handle_save_intersect_presets(params, dialog)
      return unless dialog
      if defined?(IntersectEngine) && params && params['presets']
        saved = IntersectEngine.save_presets(params['presets'])
        active_id = params['active_id']
        IntersectEngine.set_active_preset_id(active_id) if active_id
        active = IntersectEngine.get_active_preset
        payload = { 'status' => 'success', 'presets' => saved, 'active' => active }.to_json
        dialog.execute_script("if(window.onIntersectPresetsSaved) window.onIntersectPresetsSaved(#{payload});")
      end
    end

    def self.handle_apply_intersection(params, dialog)
      result = defined?(IntersectEngine) ? IntersectEngine.apply_to_selection(params || {}) : { 'status' => 'error', 'message' => 'IntersectEngine chưa nạp' }
      dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('intersect', #{result.to_json});") if dialog
      result
    end

    def self.handle_activate_intersect_tool(params, dialog)
      if defined?(IntersectTool)
        IntersectTool.activate_tool(params || {})
      end
    end

    def self.handle_clear_intersections(dialog)
      result = defined?(IntersectEngine) ? IntersectEngine.clear_intersections : { 'status' => 'error' }
      dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('clear_intersect', #{result.to_json});") if dialog
      result
    end

    def self.register_grain_palette_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("set_grain_angle") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        angle = (params['angle'] || 0.0).to_f
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(LabelingEngine) ? LabelingEngine.set_grain_angle(angle, sel_only) : {}
        dialog.execute_script("if(window.onAngleApplied) window.onAngleApplied(#{angle}, #{result.to_json});")
        if defined?(WindowManager) && WindowManager.dialog && WindowManager.dialog.visible?
          WindowManager.dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
        end
      end

      dialog.add_action_callback("rotate_grain_step") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        step = (params['step'] || 15.0).to_f
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(LabelingEngine) ? LabelingEngine.rotate_grain_direction(step, sel_only) : {}
        dialog.execute_script("if(window.onStepApplied) window.onStepApplied(#{step}, #{result.to_json});")
        if defined?(WindowManager) && WindowManager.dialog && WindowManager.dialog.visible?
          WindowManager.dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('grain', #{result.to_json});")
        end
      end

      dialog.add_action_callback("close_palette") do |_ctx, *args|
        WindowManager.close_grain_palette if defined?(WindowManager)
      end
    end

    def self.register_rename_dialog_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("rename_apply") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        result = defined?(RenameEngine) ? RenameEngine.rename_selection(params) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
        if defined?(WindowManager) && WindowManager.dialog && WindowManager.dialog.visible?
          WindowManager.dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('rename', #{result.to_json});")
        end
      end

      dialog.add_action_callback("rename_quick") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        name = params['name'].to_s
        is_mod = params['is_module'] ? true : false
        auto_idx = params['auto_index'] ? true : false
        result = defined?(RenameEngine) ? RenameEngine.apply_quick_name(name, is_mod, auto_idx, params) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
        if defined?(WindowManager) && WindowManager.dialog && WindowManager.dialog.visible?
          WindowManager.dialog.execute_script("if(window.onCncActionCompleted) window.onCncActionCompleted('rename', #{result.to_json});")
        end
      end

      dialog.add_action_callback("rename_replace") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        find_str = params['find'].to_s
        rep_str = params['replace'].to_s
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(RenameEngine) ? RenameEngine.replace_text(find_str, rep_str, sel_only) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
      end

      dialog.add_action_callback("rename_clean_copy") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(RenameEngine) ? RenameEngine.clean_copy_names(sel_only) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
      end

      dialog.add_action_callback("rename_clear_id") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        sel_only = params.key?('selection_only') ? params['selection_only'] : true
        result = defined?(RenameEngine) ? RenameEngine.clear_part_ids(sel_only) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
      end

      dialog.add_action_callback("rename_undo") do |_ctx, *args|
        Sketchup.undo
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted({'status':'success','message':'Đã hoàn tác (Undo) thành công!'});")
      end

      dialog.add_action_callback("get_rename_presets") do |_ctx, *args|
        presets = defined?(RenameEngine) ? RenameEngine.get_presets : {}
        dialog.execute_script("if(window.onPresetsLoaded) window.onPresetsLoaded(#{presets.to_json});")
      end

      dialog.add_action_callback("save_rename_presets") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        result = defined?(RenameEngine) ? RenameEngine.save_presets(params) : {}
        dialog.execute_script("if(window.onRenameCompleted) window.onRenameCompleted(#{result.to_json});")
      end
    end

    
    # Cài đặt toàn bộ Callback cho Cửa sổ Thống Kê & Dự Toán (Report Dialog Chuẩn ABF)
    def self.register_report_dialog_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("get_statistics_data") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        sel_only = params['selection_only'] ? true : false
        data = defined?(ReportEngine) ? ReportEngine.collect_statistics(sel_only) : { 'status' => 'error' }
        dialog.execute_script("if(window.onStatisticsLoaded) window.onStatisticsLoaded(#{data.to_json});")
      end

      dialog.add_action_callback("export_statistics_excel") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        res = defined?(ReportEngine) ? ReportEngine.export_to_excel(data) : { 'status' => 'error' }
        dialog.execute_script("if(window.onExcelExported) window.onExcelExported(#{res.to_json});")
      end

      dialog.add_action_callback("save_cost_presets") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        res = defined?(ReportEngine) ? ReportEngine.save_cost_presets(data) : { 'status' => 'error' }
      end

      dialog.add_action_callback("close_report_dialog") do |_ctx, *args|
        WindowManager.close_report_dialog if defined?(WindowManager)
      end
    end

    def self.parse_json_arg(arg)
      return {} if arg.nil?
      return arg if arg.is_a?(Hash)
      return JSON.parse(arg) if arg.is_a?(String)
      arg
    rescue => _e
      {}
    end

    # ==========================================================================
    # CÁC CALLBACK TIẾP NHẬN CHO BẢNG CHỈ DÁN CẠNH (PALETTE & DIALOG)
    # ==========================================================================
    def self.register_edge_banding_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("get_edge_banding_config") do |_ctx, *args|
        cfg = defined?(EdgeBandingEngine) ? EdgeBandingEngine.get_config : {}
        dialog.execute_script("if(window.onConfigLoaded) window.onConfigLoaded(#{cfg.to_json});")
      end

      dialog.add_action_callback("save_edge_banding_config") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        cfg = defined?(EdgeBandingEngine) ? EdgeBandingEngine.save_config(data) : {}
        dialog.execute_script("if(window.onConfigLoaded) window.onConfigLoaded(#{cfg.to_json});")
      end

      dialog.add_action_callback("set_active_edge_band") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        if defined?(EdgeBandingEngine) && data['id']
          EdgeBandingEngine.set_active_preset(data['id'])
        end
      end

      dialog.add_action_callback("set_edge_banding_mode") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        mode = data['mode'] || 'single'
        if defined?(EdgeBandingTool) && EdgeBandingTool.current_tool
          EdgeBandingTool.current_tool.set_mode(mode)
        end
      end

      dialog.add_action_callback("toggle_xray_mode") do |_ctx, *args|
        if defined?(EdgeBandingTool) && EdgeBandingTool.current_tool
          EdgeBandingTool.current_tool.toggle_xray
        else
          opts = Sketchup.active_model.rendering_options rescue nil
          opts['ModelTransparency'] = !opts['ModelTransparency'] if opts
        end
      end

      dialog.add_action_callback("open_edge_banding_dialog") do |_ctx, *args|
        WindowManager.show_edge_banding_dialog if defined?(WindowManager)
      end

      dialog.add_action_callback("close_edge_banding_dialog") do |_ctx, *args|
        WindowManager.close_edge_banding_dialog if defined?(WindowManager)
      end
    end

    # ==========================================================================
    # ĐĂNG KÝ CALLBACK CHO CỬA SỔ IN TEM NHÃN (CHUẨN ABF & MÁY IN TEM)
    # ==========================================================================
    def self.register_print_label_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("get_print_labels_data") do |_ctx, *args|
        data = defined?(PrintLabelEngine) ? PrintLabelEngine.collect_panels_for_labels : { 'status' => 'error' }
        dialog.execute_script("if(window.onLabelsDataLoaded) window.onLabelsDataLoaded(#{data.to_json});")
      end

      dialog.add_action_callback("save_print_label_config") do |_ctx, *args|
        cfg = parse_json_arg(args.first) || {}
        res = defined?(PrintLabelEngine) ? PrintLabelEngine.save_config(cfg) : {}
      end

      dialog.add_action_callback("export_labels_pdf") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        res = defined?(PrintLabelEngine) ? PrintLabelEngine.export_labels_pdf(params) : { 'status' => 'error' }
        if res['status'] == 'success'
          UI.messagebox("Đã xuất file bản in tem nhãn thành công:\n#{res['file_path']}")
        else
          UI.messagebox("Lỗi xuất file in tem: #{res['message']}")
        end
      end

      dialog.add_action_callback("close_print_labels_dialog") do |_ctx, *args|
        WindowManager.close_print_labels_dialog if defined?(WindowManager)
      end
    end

    # ==========================================================================
    # ĐĂNG KÝ CALLBACK CHO CỬA SỔ BUNG NỔ MÔ HÌNH (EXPLODED VIEW CHUẨN ABF)
    # ==========================================================================
    def self.register_exploded_hud_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("init_exploded_view") do |_ctx, *args|
        core_dir = File.join(File.dirname(__FILE__), 'core')
        ['labeling_engine.rb', 'exploded_view_engine.rb'].each do |fn|
          fp = File.join(core_dir, fn)
          load fp if File.exist?(fp)
        end
        res = defined?(ExplodedViewEngine) ? ExplodedViewEngine.init_exploded_view : { 'status' => 'error' }
        dialog.execute_script("if(window.onExplodedViewReady) window.onExplodedViewReady(#{res.to_json});")
      end

      dialog.add_action_callback("update_exploded_view") do |_ctx, *args|
        params = parse_json_arg(args.first) || {}
        ExplodedViewEngine.update_explosion(params) if defined?(ExplodedViewEngine)
      end

      dialog.add_action_callback("reset_exploded_view") do |_ctx, *args|
        res = defined?(ExplodedViewEngine) ? ExplodedViewEngine.reset_to_original : {}
      end

      dialog.add_action_callback("commit_exploded_view") do |_ctx, *args|
        res = defined?(ExplodedViewEngine) ? ExplodedViewEngine.commit_and_create_scene : {}
      end

      dialog.add_action_callback("close_exploded_hud") do |_ctx, *args|
        WindowManager.close_exploded_hud if defined?(WindowManager)
      end

      dialog.add_action_callback("dispatch") do |_ctx, *args|
        raw = args.first
        payload = parse_json_arg(raw)
        action = payload['action'] || payload[:action]
        data = payload['data'] || payload[:data] || {}

        case action.to_s
        when 'init_exploded_view'
          res = defined?(ExplodedViewEngine) ? ExplodedViewEngine.init_exploded_view : { 'status' => 'error' }
          dialog.execute_script("if(window.onExplodedViewReady) window.onExplodedViewReady(#{res.to_json});")
        when 'update_exploded_view'
          ExplodedViewEngine.update_explosion(data) if defined?(ExplodedViewEngine)
        when 'reset_exploded_view'
          ExplodedViewEngine.reset_to_original if defined?(ExplodedViewEngine)
        when 'commit_exploded_view'
          ExplodedViewEngine.commit_and_create_scene if defined?(ExplodedViewEngine)
        when 'close_exploded_hud'
          WindowManager.close_exploded_hud if defined?(WindowManager)
        end
      end
    end

    # ==========================================================================
    # XỬ LÝ LỆNH TRẢI PHẲNG TẤM VÁN ĐANG CHỌN (TỪ THẺ DC)
    # ==========================================================================
    def self.handle_apply_flatten_panel(data, dialog)
      model = Sketchup.active_model
      unless model && model.selection && !model.selection.empty?
        FlattenTool.activate_tool(data) if defined?(FlattenTool)
        return
      end

      target = model.selection.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      unless target
        FlattenTool.activate_tool(data) if defined?(FlattenTool)
        return
      end

      ents = target.is_a?(Sketchup::Group) ? target.entities : target.definition.entities
      faces = ents.grep(Sketchup::Face)
      curved_face = faces.find { |f| f.edges.any? { |e| e.smooth? || e.soft? } }

      if curved_face && defined?(FlattenEngine)
        res = FlattenEngine.flatten_curved_face(curved_face, target, target.transformation, data)
        if res && res['status'] == 'success'
          dialog.execute_script("if (window.ChillAI && window.ChillAI.onFlattenCompleted) { window.ChillAI.onFlattenCompleted(#{res.to_json}); }") rescue nil
        end
      else
        FlattenTool.activate_tool(data) if defined?(FlattenTool)
      end
    end

    # ==========================================================================
    # ĐĂNG KÝ CALLBACK CHO CỬA SỔ BẢNG THÔNG SỐ VÁN UỐN CONG (CHUẨN ẢNH 2)
    # ==========================================================================
    def self.register_flatten_dialog_callbacks(dialog)
      return unless dialog

      dialog.add_action_callback("get_flatten_config") do |_ctx, *args|
        cfg = defined?(FlattenEngine) ? FlattenEngine.get_config : {}
        dialog.execute_script("if(window.receiveFlattenConfig) window.receiveFlattenConfig(#{cfg.to_json});")
      end

      dialog.add_action_callback("save_flatten_config") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        cfg = defined?(FlattenEngine) ? FlattenEngine.save_config(data) : {}
        dialog.execute_script("if(window.receiveFlattenConfig) window.receiveFlattenConfig(#{cfg.to_json});")
      end

      dialog.add_action_callback("activate_flatten_tool") do |_ctx, *args|
        data = parse_json_arg(args.first) || {}
        FlattenTool.activate_tool(data) if defined?(FlattenTool)
      end

      dialog.add_action_callback("close_flatten_dialog") do |_ctx, *args|
        WindowManager.close_flatten_dialog if defined?(WindowManager)
      end
    end

  end
end
