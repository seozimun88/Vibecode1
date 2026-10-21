# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Fitting Tool (Công Cụ Tương Tác 3D: Vị Trí Liên Kết Ngang)
# Chưng cất chuẩn xác cơ chế tương tác trực tiếp 3D của ABF Solutions
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class FittingTool
    attr_accessor :selected_preset_index, :active_preset, :flip_face

    # Khởi động công cụ trên màn hình 3D SketchUp
    def self.activate_tool(preset = nil)
      tool = new(preset)
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(preset = nil)
      @active_preset = preset || FittingEngine.get_active_preset rescue {}
      @selected_preset_index = 2 # Mặc định: CAM 2 LỖ (Chuẩn)
      @flip_face = false # Mặc định bắt cam mặt dưới (ẩn cam)
      @hover_panel = nil
      @hover_joints = []
      @all_panels = []

      @presets_quick = [
        { id: 'cam_1_hole', name: 'CAM 1 LỖ', d_count: 1 },
        { id: 'cam_2_hole', name: 'CAM 2 LỖ (Chuẩn)', d_count: 2 },
        { id: 'cam_dowel',  name: 'CAM + CHỐT GỖ D8', d_count: 2 },
        { id: 'cabineo',    name: 'CABINEO 8/12', d_count: 2 },
        { id: 'shelf_pin',  name: 'CHỐT ĐỢT D5', d_count: 1 }
      ]
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      refresh_panel_cache
      update_status_bar
      @view.invalidate
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      refresh_panel_cache
      update_status_bar
      view.invalidate
    end

    def update_status_bar
      current_name = @presets_quick[@selected_preset_index - 1][:name] rescue "CAM 2 LỖ (Chuẩn)"
      face_name = @flip_face ? "MẶT TRÊN" : "MẶT DƯỚI"
      msg = "Chill AI [Vị Trí Liên Kết Ngang: #{current_name} | Mặt Cam: #{face_name}] 👉 Kích đúp vào tấm ván để tạo liên kết dính trên mặt | Phím 1-5 đổi mẫu | Phím F lật mặt | ESC thoát"
      Sketchup.status_text = msg
    end

    # NẠP TOÀN BỘ CÁC TẤM VÁN MỘC TRONG BẢN VẼ
    def refresh_panel_cache
      return unless @model
      ents = @model.active_entities
      @all_panels = []

      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.name =~ /Chill_AI_Fittings/i

        sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        has_subs = false
        sub_ents.each do |sub|
          next unless sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
          next if sub.name =~ /Chill_AI_Fittings/i
          @all_panels << { entity: sub, parent: e }
          has_subs = true
        end

        @all_panels << { entity: e, parent: nil } unless has_subs
      end
    end

    # BẮT ĐỐI TƯỢNG TẤM VÁN CHUẨN XÁC KHI DI CHUỘT / CLICK
    def get_picked_panel(x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)

      # 1. Duyệt qua toàn bộ path phân cấp từ sâu nhất (lá) lên gốc
      (0...ph.count).each do |idx|
        path = ph.path_at(idx)
        next unless path
        path.reverse_each do |item|
          found = @all_panels.find { |p| p[:entity] == item }
          return found if found
        end
      end

      # 2. Duyệt all_picked
      if ph.all_picked
        ph.all_picked.each do |item|
          found = @all_panels.find { |p| p[:entity] == item }
          return found if found
        end
      end

      # 3. Fallback best_picked
      best = ph.best_picked
      if best
        found = @all_panels.find { |p| p[:entity] == best }
        return found if found
        @all_panels.find do |p|
          ent = p[:entity]
          if ent.is_a?(Sketchup::Group)
            ent.entities.include?(best)
          elsif ent.is_a?(Sketchup::ComponentInstance)
            ent.definition.entities.include?(best)
          else
            false
          end
        end
      end
    end

    # ==========================================================================
    # THUẬT TOÁN QUÉT TIẾP XÚC 3 CHIỀU TOÀN DIỆN (X, Y, Z) VỚI DUNG SAI MỘNG
    # ==========================================================================
    def calculate_joints_for_panel(panel_info)
      return [] unless panel_info && @all_panels
      ent_a = panel_info[:entity]
      bb_a = FittingEngine.get_world_bounds(ent_a, panel_info[:parent])

      joints = []
      tol = 12.mm # Dung sai tiếp xúc: Hỗ trợ cả mộng âm -10mm lẫn khe hở +12mm

      @all_panels.each do |other_info|
        ent_b = other_info[:entity]
        next if ent_a == ent_b

        bb_b = FittingEngine.get_world_bounds(ent_b, other_info[:parent])

        # ----------------------------------------------------------------------
        # 1. TIẾP XÚC THEO TRỤC X (Mối nối Hồi - Đáy/Đợt phổ biến nhất)
        # ----------------------------------------------------------------------
        touch_x_left  = (bb_a.min.x - bb_b.max.x).abs <= tol || (bb_a.min.x >= bb_b.min.x - tol && bb_a.min.x <= bb_b.max.x + tol)
        touch_x_right = (bb_a.max.x - bb_b.min.x).abs <= tol || (bb_a.max.x >= bb_b.min.x - tol && bb_a.max.x <= bb_b.max.x + tol)

        if touch_x_left || touch_x_right
          overlap_y = [bb_a.max.y, bb_b.max.y].min - [bb_a.min.y, bb_b.min.y].max
          overlap_z = [bb_a.max.z, bb_b.max.z].min - [bb_a.min.z, bb_b.min.z].max

          # 1a. Cạnh theo Y (Chiều sâu), chiều dày theo Z
          if overlap_y > 80.mm && overlap_z > 4.mm
            joint_x = touch_x_left ? [bb_a.min.x, bb_b.max.x].max : [bb_a.max.x, bb_b.min.x].min
            y_min = [bb_a.min.y, bb_b.min.y].max
            y_max = [bb_a.max.y, bb_b.max.y].min
            z_mid = [bb_a.min.z, bb_b.min.z].max + overlap_z / 2.0
            direction = touch_x_left ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :x,
              run_axis: :y,
              joint_coord: joint_x,
              line_pts: [Geom::Point3d.new(joint_x, y_min, z_mid), Geom::Point3d.new(joint_x, y_max, z_mid)],
              cam_points: calculate_cam_points_on_line(joint_x, y_min, y_max, z_mid, :y, direction),
              direction: direction,
              length: overlap_y
            }
          # 1b. Cạnh theo Z (Chiều cao), chiều dày theo Y
          elsif overlap_z > 80.mm && overlap_y > 4.mm
            joint_x = touch_x_left ? [bb_a.min.x, bb_b.max.x].max : [bb_a.max.x, bb_b.min.x].min
            z_min = [bb_a.min.z, bb_b.min.z].max
            z_max = [bb_a.max.z, bb_b.max.z].min
            y_mid = [bb_a.min.y, bb_b.min.y].max + overlap_y / 2.0
            direction = touch_x_left ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :x,
              run_axis: :z,
              joint_coord: joint_x,
              line_pts: [Geom::Point3d.new(joint_x, y_mid, z_min), Geom::Point3d.new(joint_x, y_mid, z_max)],
              cam_points: calculate_cam_points_on_line(joint_x, z_min, z_max, y_mid, :z, direction),
              direction: direction,
              length: overlap_z
            }
          end
        end

        # ----------------------------------------------------------------------
        # 2. TIẾP XÚC THEO TRỤC Y (Mặt hoặc Cạnh gặp nhau theo phương Y)
        # ----------------------------------------------------------------------
        touch_y_front = (bb_a.min.y - bb_b.max.y).abs <= tol || (bb_a.min.y >= bb_b.min.y - tol && bb_a.min.y <= bb_b.max.y + tol)
        touch_y_back  = (bb_a.max.y - bb_b.min.y).abs <= tol || (bb_a.max.y >= bb_b.min.y - tol && bb_a.max.y <= bb_b.max.y + tol)

        if touch_y_front || touch_y_back
          overlap_x = [bb_a.max.x, bb_b.max.x].min - [bb_a.min.x, bb_b.min.x].max
          overlap_z = [bb_a.max.z, bb_b.max.z].min - [bb_a.min.z, bb_b.min.z].max

          # 2a. Cạnh theo X (Chiều ngang), chiều dày theo Z
          if overlap_x > 80.mm && overlap_z > 4.mm
            joint_y = touch_y_front ? [bb_a.min.y, bb_b.max.y].max : [bb_a.max.y, bb_b.min.y].min
            x_min = [bb_a.min.x, bb_b.min.x].max
            x_max = [bb_a.max.x, bb_b.max.x].min
            z_mid = [bb_a.min.z, bb_b.min.z].max + overlap_z / 2.0
            direction = touch_y_front ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :y,
              run_axis: :x,
              joint_coord: joint_y,
              line_pts: [Geom::Point3d.new(x_min, joint_y, z_mid), Geom::Point3d.new(x_max, joint_y, z_mid)],
              cam_points: calculate_cam_points_on_line(joint_y, x_min, x_max, z_mid, :x, direction),
              direction: direction,
              length: overlap_x
            }
          # 2b. Cạnh theo Z (Chiều cao), chiều dày theo X
          elsif overlap_z > 80.mm && overlap_x > 4.mm
            joint_y = touch_y_front ? [bb_a.min.y, bb_b.max.y].max : [bb_a.max.y, bb_b.min.y].min
            z_min = [bb_a.min.z, bb_b.min.z].max
            z_max = [bb_a.max.z, bb_b.max.z].min
            x_mid = [bb_a.min.x, bb_b.min.x].max + overlap_x / 2.0
            direction = touch_y_front ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :y,
              run_axis: :z,
              joint_coord: joint_y,
              line_pts: [Geom::Point3d.new(x_mid, joint_y, z_min), Geom::Point3d.new(x_mid, joint_y, z_max)],
              cam_points: calculate_cam_points_on_line(joint_y, z_min, z_max, x_mid, :z, direction),
              direction: direction,
              length: overlap_z
            }
          end
        end

        # ----------------------------------------------------------------------
        # 3. TIẾP XÚC THEO TRỤC Z (Tấm ngồi trên tấm khác theo phương đứng)
        # ----------------------------------------------------------------------
        touch_z_bot = (bb_a.min.z - bb_b.max.z).abs <= tol || (bb_a.min.z >= bb_b.min.z - tol && bb_a.min.z <= bb_b.max.z + tol)
        touch_z_top = (bb_a.max.z - bb_b.min.z).abs <= tol || (bb_a.max.z >= bb_b.min.z - tol && bb_a.max.z <= bb_b.max.z + tol)

        if touch_z_bot || touch_z_top
          overlap_x = [bb_a.max.x, bb_b.max.x].min - [bb_a.min.x, bb_b.min.x].max
          overlap_y = [bb_a.max.y, bb_b.max.y].min - [bb_a.min.y, bb_b.min.y].max

          # 3a. Cạnh theo Y (Chiều sâu)
          if overlap_y > 80.mm && overlap_x > 4.mm
            joint_z = touch_z_bot ? [bb_a.min.z, bb_b.max.z].max : [bb_a.max.z, bb_b.min.z].min
            y_min = [bb_a.min.y, bb_b.min.y].max
            y_max = [bb_a.max.y, bb_b.max.y].min
            x_mid = [bb_a.min.x, bb_b.min.x].max + overlap_x / 2.0
            direction = touch_z_bot ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :z,
              run_axis: :y,
              joint_coord: joint_z,
              line_pts: [Geom::Point3d.new(x_mid, y_min, joint_z), Geom::Point3d.new(x_mid, y_max, joint_z)],
              cam_points: calculate_cam_points_on_line(joint_z, y_min, y_max, x_mid, :y, direction),
              direction: direction,
              length: overlap_y
            }
          # 3b. Cạnh theo X (Chiều ngang)
          elsif overlap_x > 80.mm && overlap_y > 4.mm
            joint_z = touch_z_bot ? [bb_a.min.z, bb_b.max.z].max : [bb_a.max.z, bb_b.min.z].min
            x_min = [bb_a.min.x, bb_b.min.x].max
            x_max = [bb_a.max.x, bb_b.max.x].min
            y_mid = [bb_a.min.y, bb_b.min.y].max + overlap_y / 2.0
            direction = touch_z_bot ? 1 : -1

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :z,
              run_axis: :x,
              joint_coord: joint_z,
              line_pts: [Geom::Point3d.new(x_min, y_mid, joint_z), Geom::Point3d.new(x_max, y_mid, joint_z)],
              cam_points: calculate_cam_points_on_line(joint_z, x_min, x_max, y_mid, :x, direction),
              direction: direction,
              length: overlap_x
            }
          end
        end
      end

      joints
    end

    # TÍNH CÁC ĐIỂM CAM/CHỐT DỌC THEO CẠNH TIẾP XÚC
    def calculate_cam_points_on_line(fixed_val, min_val, max_val, mid_val, running_axis, _dir)
      len = max_val - min_val
      return [] if len < 80.mm

      pts = []
      offset_L = 34.mm
      offset_C = 34.mm

      if running_axis == :y
        pts << Geom::Point3d.new(fixed_val, min_val + offset_L, mid_val)
        if len > 450.mm
          pts << Geom::Point3d.new(fixed_val, min_val + (len / 2.0), mid_val)
        end
        pts << Geom::Point3d.new(fixed_val, max_val - offset_C, mid_val)
      elsif running_axis == :x
        pts << Geom::Point3d.new(min_val + offset_L, fixed_val, mid_val)
        if len > 450.mm
          pts << Geom::Point3d.new(min_val + (len / 2.0), fixed_val, mid_val)
        end
        pts << Geom::Point3d.new(max_val - offset_C, fixed_val, mid_val)
      else # :z
        pts << Geom::Point3d.new(fixed_val, mid_val, min_val + offset_L)
        if len > 450.mm
          pts << Geom::Point3d.new(fixed_val, mid_val, min_val + (len / 2.0))
        end
        pts << Geom::Point3d.new(fixed_val, mid_val, max_val - offset_C)
      end

      # Sắp xếp các điểm tăng dần theo trục chạy dài
      pts.sort_by! { |p| p.send(running_axis) }
      pts
    end

    # ==========================================================================
    # CÁC SỰ KIỆN CHUỘT & BÀN PHÍM
    # ==========================================================================

    def onMouseMove(_flags, x, y, view)
      panel = get_picked_panel(x, y, view)

      if panel != @hover_panel
        @hover_panel = panel
        if @hover_panel
          @hover_joints = calculate_joints_for_panel(@hover_panel)
        else
          @hover_joints = []
        end
        view.invalidate
      end
    end

    # CLICK ĐƠN: CHỌN VÀ HIGHLIGHT TẤM VÁN
    def onLButtonDown(_flags, x, y, view)
      panel = get_picked_panel(x, y, view)
      if panel
        @hover_panel = panel
        @hover_joints = calculate_joints_for_panel(@hover_panel)
        view.invalidate
      end
    end

    # KÍCH ĐÚP CHUỘT TRÁI (DOUBLE CLICK) -> KÍCH HOẠT LIÊN KẾT DÍNH TRỰC TIẾP TRÊN 2 TẤM VÁN!
    def onLButtonDoubleClick(_flags, x, y, view)
      panel = get_picked_panel(x, y, view)

      unless panel
        UI.messagebox("Vui lòng click đúp vào 1 tấm ván mộc để đục lỗ liên kết.")
        return
      end

      joints = calculate_joints_for_panel(panel)
      if joints.empty?
        UI.messagebox("Tấm ván này không có cạnh nào tiếp xúc vuông góc với các tấm ván lân cận.\n(Khoảng cách vượt quá dung sai 12mm hoặc không giao nhau)")
        return
      end

      apply_joints_to_panel(panel, joints)
      view.invalidate
    end

    # ĐỔI PRESET NHANH QUA BÀN PHÍM (PHÍM 1-5, PHÍM F LẬT MẶT)
    def onKeyDown(key, _repeat, _flags, view)
      case key
      when 49 # Phím '1'
        @selected_preset_index = 1
        update_status_bar
        view.invalidate
      when 50 # Phím '2'
        @selected_preset_index = 2
        update_status_bar
        view.invalidate
      when 51 # Phím '3'
        @selected_preset_index = 3
        update_status_bar
        view.invalidate
      when 52 # Phím '4'
        @selected_preset_index = 4
        update_status_bar
        view.invalidate
      when 53 # Phím '5'
        @selected_preset_index = 5
        update_status_bar
        view.invalidate
      when 70, 102, 32 # Phím 'F', 'f' hoặc Phím Cách (Space) -> Lật mặt bầu cam (Trên / Dưới)
        @flip_face = !@flip_face
        update_status_bar
        view.invalidate
      when 27 # Phím ESC -> Thoát chế độ tool
        Sketchup.send_action("selectSelectionTool:")
      end
    end

    # ==========================================================================
    # THI CÔNG ĐỤC LỖ LIÊN KẾT DÍNH TRỰC TIẾP TRÊN BỀ MẶT 2 TẤM VÁN (CHUẨN ABF)
    # ==========================================================================
    def apply_joints_to_panel(panel, joints)
      model = Sketchup.active_model
      preset_info = @presets_quick[@selected_preset_index - 1] || @presets_quick[1]

      model.start_operation("Chill AI: Kích Hoạt Liên Kết Ngang (#{preset_info[:name]})", true)
      FittingEngine.ensure_layers(model)

      # Xây dựng cấu hình preset chi tiết tương ứng với lựa chọn
      preset = case @selected_preset_index
               when 1 # CAM 1 LỖ
                 {
                   'name' => 'CAM 1 LỖ',
                   'L' => 34.0, 'C' => 34.0,
                   'D' => [{ 'id' => 'D1', 'dia' => 15.0, 'depth' => 13.5, 'layer' => FittingEngine::LAYER_CAM_15, 'active' => true }],
                   'd' => [{ 'id' => 'd1', 'dia' => 8.0, 'depth' => 34.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }],
                   'Dside' => [{ 'id' => 'Dside1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true }],
                   'n' => [{ 'val' => 32.0 }]
                 }
               when 2 # CAM 2 LỖ (Chuẩn)
                 {
                   'name' => 'CAM 2 LỖ (Chuẩn)',
                   'L' => 34.0, 'C' => 34.0,
                   'D' => [{ 'id' => 'D1', 'dia' => 15.0, 'depth' => 13.5, 'layer' => FittingEngine::LAYER_CAM_15, 'active' => true }],
                   'd' => [
                     { 'id' => 'd1', 'dia' => 8.0, 'depth' => 34.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true },
                     { 'id' => 'd2', 'dia' => 8.0, 'depth' => 25.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }
                   ],
                   'Dside' => [
                     { 'id' => 'Dside1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true },
                     { 'id' => 'Dside2', 'dia' => 8.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }
                   ],
                   'n' => [{ 'val' => 32.0 }]
                 }
               when 3 # CAM + CHỐT GỖ D8
                 {
                   'name' => 'CAM + CHỐT GỖ D8',
                   'L' => 34.0, 'C' => 34.0,
                   'D' => [{ 'id' => 'D1', 'dia' => 15.0, 'depth' => 13.5, 'layer' => FittingEngine::LAYER_CAM_15, 'active' => true }],
                   'd' => [
                     { 'id' => 'd1', 'dia' => 8.0, 'depth' => 34.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true },
                     { 'id' => 'd2', 'dia' => 8.0, 'depth' => 25.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }
                   ],
                   'Dside' => [
                     { 'id' => 'Dside1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true },
                     { 'id' => 'Dside2', 'dia' => 8.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }
                   ],
                   'n' => [{ 'val' => 32.0 }]
                 }
               when 4 # CABINEO 8/12
                 {
                   'name' => 'CABINEO 8/12',
                   'L' => 34.0, 'C' => 34.0,
                   'D' => [
                     { 'id' => 'D1', 'dia' => 12.0, 'depth' => 10.0, 'layer' => FittingEngine::LAYER_CAM_15, 'active' => true },
                     { 'id' => 'D2', 'dia' => 12.0, 'depth' => 10.0, 'layer' => FittingEngine::LAYER_CAM_15, 'active' => true }
                   ],
                   'd' => [{ 'id' => 'd1', 'dia' => 8.0, 'depth' => 25.0, 'layer' => FittingEngine::LAYER_DOWEL_8, 'active' => true }],
                   'Dside' => [{ 'id' => 'Dside1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true }],
                   'n' => [{ 'val' => 32.0 }]
                 }
               when 5 # CHỐT ĐỢT D5
                 {
                   'name' => 'CHỐT ĐỢT D5',
                   'L' => 34.0, 'C' => 34.0,
                   'D' => [],
                   'd' => [{ 'id' => 'd1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true }],
                   'Dside' => [{ 'id' => 'Dside1', 'dia' => 5.0, 'depth' => 12.0, 'layer' => FittingEngine::LAYER_PIN_5, 'active' => true }],
                   'n' => [{ 'val' => 32.0 }]
                 }
               else
                 FittingEngine.get_active_preset
               end

      total_fittings = 0

      # Áp dụng đục lỗ dính trực tiếp trên bề mặt cả 2 tấm ván đối diện
      joints.each do |joint|
        cnt = FittingEngine.apply_joint_pair(
          joint[:panel_a],
          joint[:panel_b],
          joint[:axis],
          joint[:run_axis],
          joint[:joint_coord],
          joint[:cam_points],
          preset,
          @flip_face
        )
        total_fittings += cnt
      end

      model.commit_operation

      face_text = @flip_face ? "Mặt trên" : "Mặt dưới"
      msg = "Chill AI: Đã tạo thành công #{total_fittings} lỗ [#{preset_info[:name]} - #{face_text}] dính trực tiếp trên bề mặt cả 2 tấm ván theo chuẩn ABF!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingTool] #{msg}"

      AudioPlayer.play({ 'text' => "Đã kích hoạt liên kết #{preset_info[:name]} dính trên mặt ván cho anh Huy rồi nhé!" }) rescue nil if defined?(AudioPlayer)

      # Cập nhật lại danh sách joints sau khi đã đục
      @hover_joints = calculate_joints_for_panel(panel)
    rescue => e
      model.abort_operation rescue nil
      puts "[Chill AI FittingTool Error] #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      UI.messagebox("Lỗi khi tạo liên kết: #{e.message}")
    end

    # ==========================================================================
    # VẼ PREVIEW NÉT ĐỨT & HUD LÊN MÀN HÌNH 3D (GIỐNG HỆT ABF)
    # ==========================================================================
    def draw(view)
      draw_hud(view)

      return if @hover_joints.nil? || @hover_joints.empty?

      @hover_joints.each do |joint|
        # 1. Vẽ cạnh tiếp xúc màu cam vàng (nét đứt)
        view.drawing_color = Sketchup::Color.new(245, 166, 35)
        view.line_width = 3
        view.line_stipple = "-" # Stipple nét đứt y hệt ảnh ABF
        view.draw(GL_LINES, joint[:line_pts])

        # 2. Vẽ các vòng tròn cam mô phỏng màu đỏ cam rực rỡ
        if joint[:cam_points] && !joint[:cam_points].empty?
          # Điểm tròn tâm
          view.draw_points(joint[:cam_points], 16, 2, Sketchup::Color.new(255, 69, 0)) # Red-Orange
          # Vòng tròn bao ngoài
          view.draw_points(joint[:cam_points], 26, 1, Sketchup::Color.new(255, 215, 0)) # Gold ring
        end
      end
    end

    # VẼ HUD NỔI TRÊN MÀN HÌNH 3D (GÓC TRÊN BÊN TRÁI)
    def draw_hud(view)
      x = 24
      y = 110

      # Tiêu đề
      view.draw_text(Geom::Point3d.new(x, y, 0), "🔩 CHẾ ĐỘ: LIÊN KẾT NGANG (CHUẨN ABF)", { color: Sketchup::Color.new(245, 166, 35), size: 14, bold: true })
      y += 24
      view.draw_text(Geom::Point3d.new(x, y, 0), "👉 Kích đúp chuột trái vào tấm ván để tạo liên kết dính mặt", { color: Sketchup::Color.new(255, 255, 255), size: 11 })
      y += 22
      
      flip_text = @flip_face ? "MẶT TRÊN" : "MẶT DƯỚI (Mặc định)"
      view.draw_text(Geom::Point3d.new(x, y, 0), "🔄 Phím [F] hoặc [Space]: Lật mặt cam -> #{flip_text}", { color: Sketchup::Color.new(52, 211, 153), size: 11, bold: true })
      y += 24

      # Danh sách mẫu chọn nhanh 1-5
      @presets_quick.each_with_index do |p, idx|
        is_active = (idx + 1 == @selected_preset_index)
        prefix = is_active ? "● " : "○ "
        color = is_active ? Sketchup::Color.new(245, 166, 35) : Sketchup::Color.new(156, 163, 175)
        text = "#{prefix}#{idx + 1}: #{p[:name]}"
        view.draw_text(Geom::Point3d.new(x, y, 0), text, { color: color, size: 11, bold: is_active })
        y += 19
      end

      y += 10
      view.draw_text(Geom::Point3d.new(x, y, 0), "(Phím 1-5: Chọn mẫu | Phím F: Lật mặt | ESC: Thoát)", { color: Sketchup::Color.new(140, 150, 165), size: 10 })
    end
  end
end
