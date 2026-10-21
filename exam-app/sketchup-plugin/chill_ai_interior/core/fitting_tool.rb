# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Fitting Tool (Công Cụ Tương Tác 3D: Vị Trí Liên Kết Ngang)
# Chưng cất chuẩn xác cơ chế tương tác trực tiếp 3D của ABF Solutions
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class FittingTool
    attr_accessor :selected_preset_index, :active_preset

    # Khởi động công cụ trên màn hình 3D SketchUp
    def self.activate_tool(preset = nil)
      tool = new(preset)
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(preset = nil)
      @active_preset = preset || FittingEngine.get_active_preset rescue {}
      @selected_preset_index = 2 # Mặc định: CAM 2 LỖ
      @hover_panel = nil
      @hover_joints = []
      @all_panels = []
      @ip = Sketchup::InputPoint.new

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
      current_name = @presets_quick[@selected_preset_index - 1][:name] rescue "CAM 2 LỖ"
      msg = "Chill AI [Vị Trí Liên Kết Ngang: #{current_name}] 👉 Kích đúp chuột trái vào 1 tấm ván để kích hoạt liên kết | Phím 1-5 đổi mẫu | ESC để thoát"
      Sketchup.status_text = msg
    end

    def refresh_panel_cache
      return unless @model
      ents = @model.active_entities
      @all_panels = []
      ents.each do |e|
        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.name =~ /Chill_AI_Fittings/i
          # Kiểm tra nếu là tủ tổ hợp cha chứa nhiều tấm
          sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          has_subs = false
          sub_ents.each do |sub|
            if sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
              next if sub.name =~ /Chill_AI_Fittings/i
              @all_panels << { entity: sub, parent: e, transform: e.transformation * sub.transformation }
              has_subs = true
            end
          end
          @all_panels << { entity: e, parent: nil, transform: e.transformation } unless has_subs
        end
      end
    end

    # Tìm đối tượng tấm ván từ pick helper
    def find_panel_from_picked(picked)
      return nil unless picked
      # Tìm trong cache
      found = @all_panels.find { |p| p[:entity] == picked }
      return found if found

      # Tìm cha nếu pick trúng mặt hoặc cạnh bên trong
      @all_panels.find do |p|
        ent = p[:entity]
        if ent.is_a?(Sketchup::Group)
          ent.entities.include?(picked)
        elsif ent.is_a?(Sketchup::ComponentInstance)
          ent.definition.entities.include?(picked)
        else
          false
        end
      end
    end

    # TÍNH TOÁN CÁC MỐI NỐI TIẾP XÚC VUÔNG GÓC VỚI CÁC TẤM LÂN CẬN
    def calculate_joints_for_panel(panel_info)
      return [] unless panel_info && @all_panels
      ent_a = panel_info[:entity]
      bb_a = FittingEngine.get_world_bounds(ent_a, panel_info[:transform])

      joints = []

      @all_panels.each do |other_info|
        ent_b = other_info[:entity]
        next if ent_a == ent_b

        bb_b = FittingEngine.get_world_bounds(ent_b, other_info[:transform])

        # 1. KIỂM TRA TIẾP XÚC THEO TRỤC X (Mối nối hồi - đáy/đợt phổ biến nhất)
        touch_x_left  = (bb_a.min.x - bb_b.max.x).abs < 3.mm
        touch_x_right = (bb_a.max.x - bb_b.min.x).abs < 3.mm

        if touch_x_left || touch_x_right
          overlap_y = [bb_a.max.y, bb_b.max.y].min - [bb_a.min.y, bb_b.min.y].max
          overlap_z = [bb_a.max.z, bb_b.max.z].min - [bb_a.min.z, bb_b.min.z].max

          if overlap_y > 100.mm && overlap_z > 5.mm
            joint_x = touch_x_left ? bb_a.min.x : bb_a.max.x
            y_min = [bb_a.min.y, bb_b.min.y].max
            y_max = [bb_a.max.y, bb_b.max.y].min
            z_mid = (bb_a.min.z + bb_a.max.z) / 2.0

            line_pts = [
              Geom::Point3d.new(joint_x, y_min, z_mid),
              Geom::Point3d.new(joint_x, y_max, z_mid)
            ]

            # Tính các điểm đặt cam/chốt dọc theo cạnh tiếp xúc
            cam_pts = calculate_cam_points_on_line(joint_x, y_min, y_max, z_mid, :y, touch_x_left ? 1 : -1)

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :x,
              joint_coord: joint_x,
              line_pts: line_pts,
              cam_points: cam_pts,
              direction: touch_x_left ? 1 : -1,
              length: overlap_y
            }
          end
        end

        # 2. KIỂM TRA TIẾP XÚC THEO TRỤC Y (Mối nối mặt trước / hậu)
        touch_y_front = (bb_a.min.y - bb_b.max.y).abs < 3.mm
        touch_y_back  = (bb_a.max.y - bb_b.min.y).abs < 3.mm

        if touch_y_front || touch_y_back
          overlap_x = [bb_a.max.x, bb_b.max.x].min - [bb_a.min.x, bb_b.min.x].max
          overlap_z = [bb_a.max.z, bb_b.max.z].min - [bb_a.min.z, bb_b.min.z].max

          if overlap_x > 100.mm && overlap_z > 5.mm
            joint_y = touch_y_front ? bb_a.min.y : bb_a.max.y
            x_min = [bb_a.min.x, bb_b.min.x].max
            x_max = [bb_a.max.x, bb_b.max.x].min
            z_mid = (bb_a.min.z + bb_a.max.z) / 2.0

            line_pts = [
              Geom::Point3d.new(x_min, joint_y, z_mid),
              Geom::Point3d.new(x_max, joint_y, z_mid)
            ]

            cam_pts = calculate_cam_points_on_line(joint_y, x_min, x_max, z_mid, :x, touch_y_front ? 1 : -1)

            joints << {
              panel_a: panel_info,
              panel_b: other_info,
              axis: :y,
              joint_coord: joint_y,
              line_pts: line_pts,
              cam_points: cam_pts,
              direction: touch_y_front ? 1 : -1,
              length: overlap_x
            }
          end
        end
      end

      joints
    end

    # TÍNH CÁC ĐIỂM CAM/CHỐT DỌC THEO CẠNH TIẾP XÚC
    def calculate_cam_points_on_line(fixed_val, min_val, max_val, z_mid, running_axis, _dir)
      len = max_val - min_val
      return [] if len < 100.mm

      pts = []
      offset_L = 34.mm
      offset_C = 34.mm

      if running_axis == :y
        pts << Geom::Point3d.new(fixed_val, min_val + offset_L, z_mid)
        pts << Geom::Point3d.new(fixed_val, max_val - offset_C, z_mid)
        if len > 450.mm
          pts << Geom::Point3d.new(fixed_val, min_val + (len / 2.0), z_mid)
        end
      else
        pts << Geom::Point3d.new(min_val + offset_L, fixed_val, z_mid)
        pts << Geom::Point3d.new(max_val - offset_C, fixed_val, z_mid)
        if len > 450.mm
          pts << Geom::Point3d.new(min_val + (len / 2.0), fixed_val, z_mid)
        end
      end

      pts
    end

    # ==========================================================================
    # CÁC SỰ KIỆN CHUỘT & BÀN PHÍM
    # ==========================================================================

    def onMouseMove(_flags, x, y, view)
      ph = view.pick_helper(x, y)
      picked = ph.best_picked
      panel = find_panel_from_picked(picked)

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

    # KÍCH ĐÚP CHUỘT TRÁI (DOUBLE CLICK) -> KÍCH HOẠT LIÊN KẾT NGANG!
    def onLButtonDoubleClick(_flags, x, y, view)
      ph = view.pick_helper(x, y)
      panel = find_panel_from_picked(ph.best_picked)

      unless panel
        UI.messagebox("Vui lòng click đúp vào 1 tấm ván mộc để đục lỗ liên kết.")
        return
      end

      joints = calculate_joints_for_panel(panel)
      if joints.empty?
        UI.messagebox("Tấm ván này không có cạnh nào tiếp xúc vuông góc với các tấm ván lân cận.")
        return
      end

      apply_joints_to_panel(panel, joints)
      view.invalidate
    end

    def onLButtonDown(_flags, _x, _y, view)
      # Cho phép click đơn để chọn nếu cần
      view.invalidate
    end

    # ĐỔI PRESET NHANH QUA BÀN PHÍM (PHÍM 1, 2, 3, 4, 5)
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
      when 27 # Phím ESC -> Thoát chế độ tool
        Sketchup.send_action("selectSelectionTool:")
      end
    end

    # THI CÔNG ĐỤC LỖ LIÊN KẾT VÀO SKETCHUP
    def apply_joints_to_panel(panel, joints)
      model = Sketchup.active_model
      preset_info = @presets_quick[@selected_preset_index - 1] || @presets_quick[1]

      model.start_operation("Chill AI: Kích Hoạt Liên Kết Ngang (#{preset_info[:name]})", true)

      layer_cam = model.layers[FittingEngine::LAYER_CAM_15] || model.layers.add(FittingEngine::LAYER_CAM_15)
      layer_dowel = model.layers[FittingEngine::LAYER_DOWEL_8] || model.layers.add(FittingEngine::LAYER_DOWEL_8)
      layer_pin = model.layers[FittingEngine::LAYER_PIN_5] || model.layers.add(FittingEngine::LAYER_PIN_5)

      fittings_group = model.active_entities.add_group
      fittings_group.name = "Chill_AI_Fittings_Interactive_#{Time.now.strftime('%H%M%S')}"

      total_fittings = 0

      joints.each do |joint|
        cam_direction = joint[:direction]
        joint_x = joint[:joint_coord]

        joint[:cam_points].each do |pt|
          # 1. Bầu cam 15mm trên mặt tấm ngang
          cam_center_x = pt.x + (cam_direction * 34.mm)
          cam_center = Geom::Point3d.new(cam_center_x, pt.y, pt.z - 8.mm)

          FittingEngine.create_cylinder_hole(
            fittings_group.entities,
            cam_center,
            Geom::Vector3d.new(0, 0, 1),
            7.5.mm,
            13.5.mm,
            layer_cam,
            "Cam_15_Depth13.5"
          )
          total_fittings += 1

          # 2. Chốt gỗ 8mm (nếu là preset 2 lỗ hoặc cam+chốt)
          if preset_info[:d_count] >= 2
            dowel_y = pt.y + 32.mm
            dowel_center = Geom::Point3d.new(pt.x + (cam_direction * 9.5.mm), dowel_y, pt.z)

            FittingEngine.create_cylinder_hole(
              fittings_group.entities,
              dowel_center,
              Geom::Vector3d.new(cam_direction, 0, 0),
              4.0.mm,
              25.0.mm,
              layer_dowel,
              "Dowel_8_Depth25"
            )
            total_fittings += 1
          end

          # 3. Ty cam 5mm trên vách hồi
          pin_center = Geom::Point3d.new(pt.x, pt.y, pt.z)
          FittingEngine.create_cylinder_hole(
            fittings_group.entities,
            pin_center,
            Geom::Vector3d.new(-cam_direction, 0, 0),
            2.5.mm,
            12.0.mm,
            layer_pin,
            "Pin_5_Depth12"
          )
          total_fittings += 1
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã kích hoạt thành công #{total_fittings} lỗ #{preset_info[:name]} cho tấm ván!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingTool] #{msg}"

      AudioPlayer.play({ 'text' => "Đã kích hoạt liên kết #{preset_info[:name]} cho tấm ván rồi anh Huy nhé!" }) rescue nil if defined?(AudioPlayer)

      # Refresh joints
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
      view.draw_text(Geom::Point3d.new(x, y, 0), "🔩 CHẾ ĐỘ: LIÊN KẾT NGANG", { color: Sketchup::Color.new(245, 166, 35), size: 14, bold: true })
      y += 24
      view.draw_text(Geom::Point3d.new(x, y, 0), "👉 Kích đúp chuột trái vào tấm ván để tạo liên kết", { color: Sketchup::Color.new(255, 255, 255), size: 11 })
      y += 22
      view.draw_text(Geom::Point3d.new(x, y, 0), "[ ] Đối xứng ↔ (giữ Shift)", { color: Sketchup::Color.new(180, 185, 195), size: 11 })
      y += 18
      view.draw_text(Geom::Point3d.new(x, y, 0), "[x] Đối xứng ↕ (giữ Ctrl)", { color: Sketchup::Color.new(52, 211, 153), size: 11 })
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
      view.draw_text(Geom::Point3d.new(x, y, 0), "(Bấm phím 1-5 để đổi mẫu | ESC để thoát)", { color: Sketchup::Color.new(120, 130, 145), size: 10 })
    end
  end
end
