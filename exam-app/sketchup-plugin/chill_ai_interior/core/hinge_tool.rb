# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Hinge Tool (Công Cụ Tương Tác 3D: Khoan Bản Lề Chuẩn ABF)
# Chuẩn hoá 100% theo quy trình 2 bước tương tác giữa TẤM CÁNH và TẤM TỦ của ABF:
#   Bước 1: Kích chuột chọn TẤM CÁNH (Tấm cánh được viền xanh dương nổi bật)
#   Bước 2: Rê chuột vào TẤM TỦ -> Hiện GẠCH ĐỊNH VỊ LIỀN MẠCH vị trí giữa 2 tấm
#   Bước 3: Kích chọn TẤM TỦ -> Đục khoanh tròn chén lề Ø35mm trên Cánh và vít đế trên Tủ!
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class HingeTool
    attr_accessor :hinge_count, :margin, :hinge_type, :flip_face

    # Khởi động công cụ trên màn hình 3D SketchUp
    def self.activate_tool(options = {})
      tool = new(options)
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(options = {})
      @ip = nil
      @all_panels = []

      # Trạng thái tương tác 2 tấm: Tấm Cánh (Door) & Tấm Tủ (Cabinet)
      @selected_door = nil
      @hover_panel = nil
      @seamless_ticks = []

      # Lưu lại kết quả sau khi đã khoan thành công
      @applied_door = nil
      @applied_cab = nil
      @applied_ticks = []

      @hinge_count = (options[:count] || options['count'] || 2).to_i
      @hinge_count = 2 if @hinge_count < 2
      @hinge_count = 7 if @hinge_count > 7

      @margin = (options[:margin] || options['margin'] || 100).to_f.mm
      @hinge_type = (options[:type] || options['type'] || 'A').to_s # 'A': Trùm ngoài, 'B': Trùm nửa, 'C': Lọt lòng
      @flip_face = false

      @mouse_x = 0
      @mouse_y = 0
      @mouse_pt_3d = nil
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      @ip = Sketchup::InputPoint.new rescue nil
      refresh_panel_cache
      update_status_bar
      @view.invalidate
    end

    def deactivate(view)
      view.invalidate rescue nil
    end

    def resume(view)
      @ip = Sketchup::InputPoint.new rescue nil
      refresh_panel_cache
      update_status_bar
      view.invalidate rescue nil
    end

    # Cập nhật thanh trạng thái dưới chân màn hình SketchUp theo từng bước tương tác ABF
    def update_status_bar
      if @selected_door.nil?
        # BƯỚC 1: Chưa chọn tấm nào
        msg = "Chill AI [Khoan Bản Lề ABF] 👉 BƯỚC 1: Kích chuột trái chọn TẤM CÁNH CỬA (hoặc Tấm 1) | Phím 2-7: Số lượng (#{@hinge_count}) | Gõ số: Đổi mép (#{@margin.to_mm.round}mm)"
      elsif @hover_panel && @hover_panel[:entity] != @selected_door[:entity] && !@seamless_ticks.empty?
        # BƯỚC 2: Đang rê chuột vào tấm tủ kề cận -> Đã khớp gạch định vị liền mạch
        door_name = get_panel_display_name(@selected_door)
        cab_name = get_panel_display_name(@hover_panel)
        msg = "Chill AI [Khoan Bản Lề ABF] 👉 BƯỚC 2: Đã khớp liên kết [#{door_name}] ⟷ [#{cab_name}] -> KÍCH CHUỘT ĐỂ ĐỤC LỀ CẢ 2 TẤM | ESC: Hủy chọn | Phím F: Đảo bên"
      else
        # Đã chọn tấm cánh, đang tìm tấm tủ
        door_name = get_panel_display_name(@selected_door)
        msg = "Chill AI [Khoan Bản Lề ABF] ✅ ĐÃ CHỌN CÁNH [#{door_name}] (Viền xanh) 👉 BƯỚC 2: Rê chuột và kích chọn TẤM TỦ kề cận | ESC: Hủy chọn cánh"
      end
      Sketchup.status_text = msg
    end

    def get_panel_display_name(panel_info)
      return "Tấm ván" unless panel_info && panel_info[:entity]
      ent = panel_info[:entity]
      name = ent.name.to_s.strip
      if name.empty? && ent.respond_to?(:definition)
        name = ent.definition.name.to_s.strip
      end
      name.empty? ? "Tấm ván" : name
    end

    # Nạp toàn bộ danh sách tấm ván mộc trong mô hình (Chuẩn cơ chế FittingTool)
    def refresh_panel_cache
      return unless @model
      @all_panels = []
      ents = @model.active_entities

      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.name =~ /Chill_AI_Fittings|Chill_AI_Label|Chill_AI_Hinges|ABF_NESTING/i

        sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        has_subs = false
        sub_ents.each do |sub|
          next unless sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
          next if sub.name =~ /Chill_AI_Fittings|Chill_AI_Label|Chill_AI_Hinges|ABF_NESTING/i
          @all_panels << { entity: sub, parent: e }
          has_subs = true
        end

        @all_panels << { entity: e, parent: nil } unless has_subs
      end
    end

    # Bắt tấm ván chuẩn xác 100% bằng PickHelper
    def get_picked_panel(x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)

      # 1. Quét từ path phân cấp sâu nhất lên gốc
      (0...ph.count).each do |idx|
        path = ph.path_at(idx)
        next unless path
        path.reverse_each do |item|
          found = @all_panels.find { |p| p[:entity] == item }
          return found if found
        end
      end

      # 2. Quét all_picked
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
    # 🌟 TỰ ĐỘNG XÁC ĐỊNH 2 MẶT TIẾP XÚC ĐỐI DIỆN NHAU GIỮA CÁNH VÀ TỦ ĐỂ BẮT BẢN LỀ
    # Tuyệt đối không phụ thuộc vào mặt nhãn dán hay lật mặt CNC!
    # Thợ mộc chỉ quan tâm 2 mặt nhìn vào nhau trong lòng tủ để bắt vít chén & đế lề.
    # ==========================================================================
    def detect_opposing_hinge_faces(bb_door, bb_cab)
      # Tâm thế giới của 2 tấm
      d_center = Geom::Point3d.new(
        (bb_door.min.x + bb_door.max.x) / 2.0,
        (bb_door.min.y + bb_door.max.y) / 2.0,
        (bb_door.min.z + bb_door.max.z) / 2.0
      )
      c_center = Geom::Point3d.new(
        (bb_cab.min.x + bb_cab.max.x) / 2.0,
        (bb_cab.min.y + bb_cab.max.y) / 2.0,
        (bb_cab.min.z + bb_cab.max.z) / 2.0
      )

      # 1. Tìm trục độ dày của Tấm Cánh (trục có kích thước mỏng nhất ~17-18mm)
      d_size_x = bb_door.max.x - bb_door.min.x
      d_size_y = bb_door.max.y - bb_door.min.y
      d_size_z = bb_door.max.z - bb_door.min.z

      d_thick_axis = :z
      if d_size_x <= d_size_y && d_size_x <= d_size_z
        d_thick_axis = :x
      elsif d_size_y <= d_size_x && d_size_y <= d_size_z
        d_thick_axis = :y
      else
        d_thick_axis = :z
      end

      # Mặt đối diện của Tấm Cánh là mặt phẳng lớn nhìn về phía Tấm Tủ (lòng tủ)
      door_normal = nil
      door_face_coord = 0.0

      case d_thick_axis
      when :x
        if c_center.x >= d_center.x
          door_normal = Geom::Vector3d.new(1, 0, 0)
          door_face_coord = bb_door.max.x
        else
          door_normal = Geom::Vector3d.new(-1, 0, 0)
          door_face_coord = bb_door.min.x
        end
      when :y
        if c_center.y >= d_center.y
          door_normal = Geom::Vector3d.new(0, 1, 0)
          door_face_coord = bb_door.max.y
        else
          door_normal = Geom::Vector3d.new(0, -1, 0)
          door_face_coord = bb_door.min.y
        end
      when :z
        if c_center.z >= d_center.z
          door_normal = Geom::Vector3d.new(0, 0, 1)
          door_face_coord = bb_door.max.z
        else
          door_normal = Geom::Vector3d.new(0, 0, -1)
          door_face_coord = bb_door.min.z
        end
      end

      # 2. Tìm trục độ dày của Tấm Tủ (trục mỏng nhất của Hồi tủ ~17-18mm)
      c_size_x = bb_cab.max.x - bb_cab.min.x
      c_size_y = bb_cab.max.y - bb_cab.min.y
      c_size_z = bb_cab.max.z - bb_cab.min.z

      c_thick_axis = :x
      if c_size_x <= c_size_y && c_size_x <= c_size_z
        c_thick_axis = :x
      elsif c_size_y <= c_size_x && c_size_y <= c_size_z
        c_thick_axis = :y
      else
        c_thick_axis = :z
      end

      # Mặt đối diện của Tấm Tủ là mặt phẳng lớn nhìn về phía Tấm Cánh (lòng tủ)
      cab_normal = nil
      cab_face_coord = 0.0

      case c_thick_axis
      when :x
        if d_center.x >= c_center.x
          cab_normal = Geom::Vector3d.new(1, 0, 0)
          cab_face_coord = bb_cab.max.x
        else
          cab_normal = Geom::Vector3d.new(-1, 0, 0)
          cab_face_coord = bb_cab.min.x
        end
      when :y
        if d_center.y >= c_center.y
          cab_normal = Geom::Vector3d.new(0, 1, 0)
          cab_face_coord = bb_cab.max.y
        else
          cab_normal = Geom::Vector3d.new(0, -1, 0)
          cab_face_coord = bb_cab.min.y
        end
      when :z
        if d_center.z >= c_center.z
          cab_normal = Geom::Vector3d.new(0, 0, 1)
          cab_face_coord = bb_cab.max.z
        else
          cab_normal = Geom::Vector3d.new(0, 0, -1)
          cab_face_coord = bb_cab.min.z
        end
      end

      {
        door_thick_axis: d_thick_axis,
        door_face_coord: door_face_coord,
        door_normal: door_normal,
        cab_thick_axis: c_thick_axis,
        cab_face_coord: cab_face_coord,
        cab_normal: cab_normal,
        door_center: d_center,
        cab_center: c_center
      }
    end

    # ==========================================================================
    # 🌟 TÍNH TOÁN LIÊN KẾT LIỀN MẠCH GIỮA TẤM CÁNH (DOOR) VÀ TẤM TỦ (CABINET)
    # Tự động xác định khe tiếp giáp (seam) giữa 2 tấm để vẽ gạch định vị chuẩn xác
    # ==========================================================================
    def calculate_seamless_hinges(door_info, cab_info)
      return [] unless door_info && cab_info && door_info[:entity].valid? && cab_info[:entity].valid?
      return [] if door_info[:entity] == cab_info[:entity]

      # Nếu người dùng bấm phím F để đảo bên: Hoán đổi vai trò Cánh <-> Tủ
      d_info = @flip_face ? cab_info : door_info
      c_info = @flip_face ? door_info : cab_info

      bb_door = FittingEngine.get_world_bounds(d_info[:entity], d_info[:parent])
      bb_cab  = FittingEngine.get_world_bounds(c_info[:entity], c_info[:parent])

      margin = @margin || 100.mm
      margin = 100.mm if margin < 20.mm
      count = [@hinge_count || 2, 2].max
      count = 7 if count > 7

      tol = 60.mm # Dung sai khe hở tiếp giáp

      # Xác định 2 mặt đối diện tiếp xúc thực tế
      faces = detect_opposing_hinge_faces(bb_door, bb_cab)

      ox_min = [bb_door.min.x, bb_cab.min.x].max
      ox_max = [bb_door.max.x, bb_cab.max.x].min
      len_x  = ox_max - ox_min

      oy_min = [bb_door.min.y, bb_cab.min.y].max
      oy_max = [bb_door.max.y, bb_cab.max.y].min
      len_y  = oy_max - oy_min

      oz_min = [bb_door.min.z, bb_cab.min.z].max
      oz_max = [bb_door.max.z, bb_cab.max.z].min
      len_z  = oz_max - oz_min

      dist_x = [0.0, [bb_door.min.x - bb_cab.max.x, bb_cab.min.x - bb_door.max.x].max].max
      dist_y = [0.0, [bb_door.min.y - bb_cab.max.y, bb_cab.min.y - bb_door.max.y].max].max
      dist_z = [0.0, [bb_door.min.z - bb_cab.max.z, bb_cab.min.z - bb_door.max.z].max].max

      # Xác định trục tiếp giáp chính (Z: đứng, Y: sâu, hoặc X: ngang)
      candidates = []
      candidates << [:z, len_z, oz_min, oz_max] if len_z > 50.mm && dist_x <= tol && dist_y <= tol
      candidates << [:y, len_y, oy_min, oy_max] if len_y > 50.mm && dist_x <= tol && dist_z <= tol
      candidates << [:x, len_x, ox_min, ox_max] if len_x > 50.mm && dist_y <= tol && dist_z <= tol

      if candidates.empty?
        spans = [[:z, len_z, oz_min, oz_max], [:y, len_y, oy_min, oy_max], [:x, len_x, ox_min, ox_max]]
        candidates = spans.sort_by { |c| c[1] }.reverse
      end

      axis, seam_len, span_min, span_max = candidates.first
      return [] if seam_len < 40.mm

      pos_list = if count == 2
                   [span_min + margin, span_max - margin]
                 elsif count == 3
                   [span_min + margin, (span_min + span_max) / 2.0, span_max - margin]
                 else
                   gap = (span_max - span_min - 2.0 * margin) / (count - 1)
                   (0...count).map { |i| span_min + margin + i * gap }
                 end

      door_normal     = faces[:door_normal]
      door_face_coord = faces[:door_face_coord]
      cab_normal      = faces[:cab_normal]
      cab_face_coord  = faces[:cab_face_coord]
      door_center     = faces[:door_center]
      cab_center      = faces[:cab_center]

      ticks = []

      case axis
      when :z
        # ----------------------------------------------------------------------
        # THẾ 1: TIẾP GIÁP THEO TRỤC Z (Chiều cao đứng) - Cửa tủ áo & Hồi đứng chuẩn
        # ----------------------------------------------------------------------
        # Xác định mép tiếp giáp bên trái hay bên phải cánh
        touch_left = (bb_door.min.x - cab_face_coord).abs < (bb_door.max.x - cab_face_coord).abs
        seam_x = touch_left ? bb_door.min.x : bb_door.max.x
        door_in_x = touch_left ? 1.0 : -1.0

        # Mép trước của tủ kề với mặt trong cánh
        seam_y = door_face_coord
        cab_depth_y = (cab_center.y >= seam_y) ? 1.0 : -1.0

        pos_list.each do |z|
          cup_center   = Geom::Point3d.new(seam_x + (door_in_x * 21.5.mm), door_face_coord, z)
          seam_pt      = Geom::Point3d.new(seam_x, seam_y, z)
          plate_center = Geom::Point3d.new(cab_face_coord, seam_y + (cab_depth_y * 37.mm), z)

          cup_screws = [
            Geom::Point3d.new(cup_center.x + (door_in_x * 6.mm), door_face_coord, z + 24.mm),
            Geom::Point3d.new(cup_center.x + (door_in_x * 6.mm), door_face_coord, z - 24.mm)
          ]

          plate_screws = [
            Geom::Point3d.new(cab_face_coord, plate_center.y, z + 16.mm),
            Geom::Point3d.new(cab_face_coord, plate_center.y, z - 16.mm)
          ]

          tick_pt_1 = Geom::Point3d.new(seam_x + (door_in_x * 35.mm), seam_y, z)
          tick_pt_2 = Geom::Point3d.new(seam_x, seam_y + (cab_depth_y * 35.mm), z)

          circle_pts = generate_circle_points_by_normal(cup_center, door_normal, 17.5.mm, 24)

          ticks << {
            axis: :z,
            seam_pt: seam_pt,
            tick_line: [tick_pt_1, tick_pt_2],
            cup_center: cup_center,
            cup_normal: door_normal,
            cup_radius: 17.5.mm,
            cup_screws: cup_screws,
            circle_pts: circle_pts,
            plate_center: plate_center,
            plate_normal: cab_normal,
            plate_screws: plate_screws,
            seamless_line: [cup_center, seam_pt, plate_center],
            door_info: d_info,
            cab_info: c_info
          }
        end

      when :y
        # ----------------------------------------------------------------------
        # THẾ 2: TIẾP GIÁP THEO TRỤC Y (Chiều sâu) - Như Đáy ván & Hồi đứng của anh Huy
        # ----------------------------------------------------------------------
        touch_left = (bb_door.min.x - cab_face_coord).abs < (bb_door.max.x - cab_face_coord).abs
        seam_x = touch_left ? bb_door.min.x : bb_door.max.x
        door_in_x = touch_left ? 1.0 : -1.0

        seam_z = door_face_coord
        cab_up_z = (cab_center.z >= seam_z) ? 1.0 : -1.0

        pos_list.each do |y|
          cup_center   = Geom::Point3d.new(seam_x + (door_in_x * 21.5.mm), y, door_face_coord)
          seam_pt      = Geom::Point3d.new(seam_x, y, seam_z)
          plate_center = Geom::Point3d.new(cab_face_coord, y, seam_z + (cab_up_z * 37.mm))

          cup_screws = [
            Geom::Point3d.new(cup_center.x + (door_in_x * 6.mm), y + 24.mm, door_face_coord),
            Geom::Point3d.new(cup_center.x + (door_in_x * 6.mm), y - 24.mm, door_face_coord)
          ]

          plate_screws = [
            Geom::Point3d.new(cab_face_coord, y + 16.mm, plate_center.z),
            Geom::Point3d.new(cab_face_coord, y - 16.mm, plate_center.z)
          ]

          tick_pt_1 = Geom::Point3d.new(seam_x + (door_in_x * 35.mm), y, seam_z)
          tick_pt_2 = Geom::Point3d.new(seam_x, y, seam_z + (cab_up_z * 35.mm))

          circle_pts = generate_circle_points_by_normal(cup_center, door_normal, 17.5.mm, 24)

          ticks << {
            axis: :y,
            seam_pt: seam_pt,
            tick_line: [tick_pt_1, tick_pt_2],
            cup_center: cup_center,
            cup_normal: door_normal,
            cup_radius: 17.5.mm,
            cup_screws: cup_screws,
            circle_pts: circle_pts,
            plate_center: plate_center,
            plate_normal: cab_normal,
            plate_screws: plate_screws,
            seamless_line: [cup_center, seam_pt, plate_center],
            door_info: d_info,
            cab_info: c_info
          }
        end

      when :x
        # ----------------------------------------------------------------------
        # THẾ 3: TIẾP GIÁP THEO TRỤC X (Chiều ngang) - Cánh mở lật lên hoặc tủ xoay
        # ----------------------------------------------------------------------
        touch_front = (bb_door.min.y - cab_face_coord).abs < (bb_door.max.y - cab_face_coord).abs
        seam_y = touch_front ? bb_door.min.y : bb_door.max.y
        door_in_y = touch_front ? 1.0 : -1.0

        seam_z = door_face_coord
        cab_up_z = (cab_center.z >= seam_z) ? 1.0 : -1.0

        pos_list.each do |x|
          cup_center   = Geom::Point3d.new(x, seam_y + (door_in_y * 21.5.mm), door_face_coord)
          seam_pt      = Geom::Point3d.new(x, seam_y, seam_z)
          plate_center = Geom::Point3d.new(x, cab_face_coord, seam_z + (cab_up_z * 37.mm))

          cup_screws = [
            Geom::Point3d.new(x + 24.mm, cup_center.y + (door_in_y * 6.mm), door_face_coord),
            Geom::Point3d.new(x - 24.mm, cup_center.y + (door_in_y * 6.mm), door_face_coord)
          ]

          plate_screws = [
            Geom::Point3d.new(x + 16.mm, cab_face_coord, plate_center.z),
            Geom::Point3d.new(x - 16.mm, cab_face_coord, plate_center.z)
          ]

          tick_pt_1 = Geom::Point3d.new(x, seam_y + (door_in_y * 35.mm), seam_z)
          tick_pt_2 = Geom::Point3d.new(x, seam_y, seam_z + (cab_up_z * 35.mm))

          circle_pts = generate_circle_points_by_normal(cup_center, door_normal, 17.5.mm, 24)

          ticks << {
            axis: :x,
            seam_pt: seam_pt,
            tick_line: [tick_pt_1, tick_pt_2],
            cup_center: cup_center,
            cup_normal: door_normal,
            cup_radius: 17.5.mm,
            cup_screws: cup_screws,
            circle_pts: circle_pts,
            plate_center: plate_center,
            plate_normal: cab_normal,
            plate_screws: plate_screws,
            seamless_line: [cup_center, seam_pt, plate_center],
            door_info: d_info,
            cab_info: c_info
          }
        end
      end

      ticks
    end

    # ==========================================================================
    # CÁC HÀM TẠO TẬP ĐIỂM VÒNG TRÒN 3D CHUẨN XÁC THEO VECTOR PHÁP TUYẾN
    # ==========================================================================
    def generate_circle_points_by_normal(center, normal, radius, segs = 24)
      norm = normal.normalize
      ref = (norm.z.abs > 0.85) ? Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(0, 0, 1)
      u = norm.cross(ref).normalize
      v = norm.cross(u).normalize

      pts = []
      (0...segs).each do |i|
        a = (2.0 * Math::PI * i) / segs
        pt = Geom::Point3d.new(
          center.x + (u.x * Math.cos(a) + v.x * Math.sin(a)) * radius,
          center.y + (u.y * Math.cos(a) + v.y * Math.sin(a)) * radius,
          center.z + (u.z * Math.cos(a) + v.z * Math.sin(a)) * radius
        )
        pts << pt
      end
      pts
    end

    # ==========================================================================
    # CÁC HÀM TẠO TẬP ĐIỂM VÒNG TRÒN 3D CHUẨN XÁC
    # ==========================================================================
    def generate_circle_points_xy(center, radius, segs = 24)
      pts = []
      (0...segs).each do |i|
        a = (2.0 * Math::PI * i) / segs
        pts << Geom::Point3d.new(center.x + Math.cos(a) * radius, center.y + Math.sin(a) * radius, center.z)
      end
      pts
    end

    def generate_circle_points_xz(center, radius, segs = 24)
      pts = []
      (0...segs).each do |i|
        a = (2.0 * Math::PI * i) / segs
        pts << Geom::Point3d.new(center.x + Math.cos(a) * radius, center.y, center.z + Math.sin(a) * radius)
      end
      pts
    end

    def generate_circle_points_yz(center, radius, segs = 24)
      pts = []
      (0...segs).each do |i|
        a = (2.0 * Math::PI * i) / segs
        pts << Geom::Point3d.new(center.x, center.y + Math.cos(a) * radius, center.z + Math.sin(a) * radius)
      end
      pts
    end

    # Lấy 12 cạnh wireframe của BoundingBox để vẽ highlight viền nổi bật
    def get_bb_wireframe_lines(bb)
      corners = (0..7).map { |i| bb.corner(i) }
      lines = []
      pairs = [
        [0, 1], [1, 3], [3, 2], [2, 0], # 4 cạnh đáy
        [4, 5], [5, 7], [7, 6], [6, 4], # 4 cạnh đỉnh
        [0, 4], [1, 5], [2, 6], [3, 7]  # 4 cạnh đứng
      ]
      pairs.each do |i, j|
        lines << corners[i]
        lines << corners[j]
      end
      lines
    end

    # ==========================================================================
    # 🎯 BƯỚC 3: THI CÔNG ĐỤC KHOANH TRÒN LỀ DÍNH TRÊN CẢ 2 TẤM (CÁNH & TỦ)
    # ==========================================================================
    def apply_seamless_hinges(door_info, cab_info, ticks)
      return unless door_info && cab_info && ticks && !ticks.empty?
      model = Sketchup.active_model
      return unless model

      model.start_operation("Chill AI: Khoan Bản Lề Chuẩn ABF (Cánh & Tủ)", true)
      FittingEngine.ensure_layers(model)

      actual_door = ticks.first[:door_info] || door_info
      actual_cab  = ticks.first[:cab_info]  || cab_info

      # 1. ĐỤC TRÊN TẤM CÁNH: Group Chill_AI_Hinges_35 (Chén lề Ø35mm + 2 vít chén)
      ent_door = actual_door[:entity]
      door_ents = ent_door.is_a?(Sketchup::Group) ? ent_door.entities : (ent_door.make_unique rescue nil; ent_door.definition.entities)
      door_ents.grep(Sketchup::Group).select { |g| g.name =~ /^Chill_AI_Hinges/i }.each { |g| g.erase! rescue nil }

      door_hinge_grp = door_ents.add_group
      door_hinge_grp.name = "Chill_AI_Hinges_35"

      # 2. ĐỤC TRÊN TẤM TỦ: Group Chill_AI_Hinge_Base_5 (2 Lỗ vít đế Ø5mm)
      ent_cab = actual_cab[:entity]
      cab_ents = ent_cab.is_a?(Sketchup::Group) ? ent_cab.entities : (ent_cab.make_unique rescue nil; ent_cab.definition.entities)
      cab_ents.grep(Sketchup::Group).select { |g| g.name =~ /^Chill_AI_Hinge_Base/i }.each { |g| g.erase! rescue nil }

      cab_plate_grp = cab_ents.add_group
      cab_plate_grp.name = "Chill_AI_Hinge_Base_5"

      total_cups = 0

      ticks.each do |tk|
        # a. Khoanh tròn chén bản lề Ø35mm trên Cánh
        FittingEngine.add_circle_to_panel(
          actual_door,
          tk[:cup_center],
          tk[:cup_normal],
          tk[:cup_radius],
          FittingEngine::LAYER_HINGE_35,
          11.5.mm,
          door_hinge_grp
        )

        # 2 Lỗ vít chén Ø3mm trên Cánh
        if tk[:cup_screws]
          tk[:cup_screws].each do |sc|
            FittingEngine.add_circle_to_panel(
              actual_door,
              sc,
              tk[:cup_normal],
              1.5.mm,
              FittingEngine::LAYER_HINGE_BASE_5,
              10.0.mm,
              door_hinge_grp
            )
          end
        end

        # b. 2 Lỗ vít đế bản lề Ø5mm trên Tủ
        if tk[:plate_screws]
          tk[:plate_screws].each do |psc|
            FittingEngine.add_circle_to_panel(
              actual_cab,
              psc,
              tk[:plate_normal],
              2.5.mm,
              FittingEngine::LAYER_HINGE_BASE_5,
              12.0.mm,
              cab_plate_grp
            )
          end
        end

        total_cups += 1
      end

      model.commit_operation

      @applied_door = actual_door
      @applied_cab = actual_cab
      @applied_ticks = ticks

      door_pname = get_panel_display_name(actual_door)
      cab_pname = get_panel_display_name(actual_cab)
      puts "[Chill AI HingeTool] ✅ Đã tạo thành công #{total_cups} bộ bản lề liền mạch giữa Cánh [#{door_pname}] và Tủ [#{cab_pname}]!"

      AudioPlayer.play({ 'text' => "Đã tạo bản lề liền mạch giữa cánh và tủ thành công cho anh Huy rồi nhé!" }) rescue nil if defined?(AudioPlayer)

      # Đặt lại trạng thái để người dùng sẵn sàng khoan tiếp cặp cánh khác
      @selected_door = nil
      @hover_panel = nil
      @seamless_ticks = []
      update_status_bar
    rescue => e
      model.abort_operation rescue nil
      puts "[Chill AI HingeTool Error] #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      UI.messagebox("Lỗi khi tạo khoanh tròn bản lề: #{e.message}")
    end

    # ==========================================================================
    # CÁC SỰ KIỆN CHUỘT & BÀN PHÍM (CHUẨN ABF WORKFLOW)
    # ==========================================================================

    def onMouseMove(_flags, x, y, view)
      @mouse_x = x
      @mouse_y = y

      if @ip
        @ip.pick(view, x, y)
        @mouse_pt_3d = @ip.position
      end

      picked = get_picked_panel(x, y, view)

      if @selected_door.nil?
        # BƯỚC 1: Đang rê chuột tìm Tấm Cánh (hoặc Tấm 1)
        if picked != @hover_panel
          @hover_panel = picked
          update_status_bar
          view.invalidate
        end
      else
        # BƯỚC 2: Đã có Tấm Cánh, đang rê chuột tìm Tấm Tủ kề cận
        if picked && picked[:entity] != @selected_door[:entity]
          if picked != @hover_panel
            @hover_panel = picked
            @seamless_ticks = calculate_seamless_hinges(@selected_door, @hover_panel)
            update_status_bar
            view.invalidate
          end
        elsif @hover_panel
          @hover_panel = nil
          @seamless_ticks = []
          update_status_bar
          view.invalidate
        end
      end
    rescue => e
      puts "[Chill AI HingeTool onMouseMove Error]: #{e.message}"
    end

    # XỬ LÝ CLICK CHUỘT TRÁI CHUẨN ABF:
    #   Lần 1: Chọn Tấm Cánh (Khóa viền xanh dương)
    #   Lần 2: Chọn Tấm Tủ -> Đục lề liền mạch ngay lập tức!
    def onLButtonDown(_flags, x, y, view)
      if @ip
        @ip.pick(view, x, y)
        @mouse_pt_3d = @ip.position
      end

      picked = get_picked_panel(x, y, view)

      if @selected_door.nil?
        # BƯỚC 1: Kích chọn Tấm Cánh (Tấm 1)
        if picked
          @selected_door = picked
          pname = get_panel_display_name(@selected_door)
          update_status_bar
          view.invalidate
          AudioPlayer.play({ 'text' => "Đã chọn tấm cánh #{pname}. Mời anh Huy kích chọn tấm tủ." }) rescue nil if defined?(AudioPlayer)
        else
          UI.messagebox("Vui lòng kích chọn vào một tấm ván mộc để làm TẤM CÁNH CỬA.")
        end
      else
        # BƯỚC 2: Kích chọn Tấm Tủ (Tấm 2)
        if picked && picked[:entity] != @selected_door[:entity]
          ticks = calculate_seamless_hinges(@selected_door, picked)
          if ticks && !ticks.empty?
            apply_seamless_hinges(@selected_door, picked, ticks)
            view.invalidate
          else
            UI.messagebox("Hai tấm ván này không có cạnh tiếp giáp hoặc khoảng cách vượt quá dung sai bản lề.")
          end
        elsif picked && picked[:entity] == @selected_door[:entity]
          # Kích lại vào chính tấm cánh -> Hủy chọn để chọn lại tấm khác
          @selected_door = nil
          @seamless_ticks = []
          update_status_bar
          view.invalidate
        else
          # Kích ra khoảng trống ngoài -> Hủy chọn
          @selected_door = nil
          @seamless_ticks = []
          update_status_bar
          view.invalidate
        end
      end
    rescue => e
      puts "[Chill AI HingeTool onLButtonDown Error]: #{e.message}"
    end

    # Phím tắt bàn phím
    def onKeyDown(key, _repeat, _flags, view)
      case key
      when 27, 32 # Phím ESC hoặc Phím Space (Phím cách)
        if @selected_door
          # Nếu đã chọn cánh -> Hủy chọn cánh để chọn lại
          @selected_door = nil
          @hover_panel = nil
          @seamless_ticks = []
          update_status_bar
          view.invalidate
        else
          # Chưa chọn cánh -> Thoát tool
          Sketchup.send_action("selectSelectionTool:")
        end

      when 50..55 # Phím '2' đến '7'
        new_count = key - 48
        if new_count != @hinge_count
          @hinge_count = new_count
          if @selected_door && @hover_panel
            @seamless_ticks = calculate_seamless_hinges(@selected_door, @hover_panel)
          end
          update_status_bar
          view.invalidate
        end

      when 70, 102 # Phím 'F', 'f' -> Đảo bên (Hoán đổi vị trí Chén <-> Đế giữa 2 tấm)
        @flip_face = !@flip_face
        if @selected_door && @hover_panel
          @seamless_ticks = calculate_seamless_hinges(@selected_door, @hover_panel)
        end
        update_status_bar
        view.invalidate

      when 65, 97 # Phím 'A', 'a' -> Trùm ngoài
        @hinge_type = 'A'
        view.invalidate

      when 66, 98 # Phím 'B', 'b' -> Trùm nửa
        @hinge_type = 'B'
        view.invalidate

      when 67, 99 # Phím 'C', 'c' -> Lọt trong
        @hinge_type = 'C'
        view.invalidate
      end
    end

    def enableVCB?
      true
    end

    def onUserText(text, view)
      val = text.to_f
      if val >= 20.0 && val <= 500.0
        @margin = val.mm
        if @selected_door && @hover_panel
          @seamless_ticks = calculate_seamless_hinges(@selected_door, @hover_panel)
        end
        update_status_bar
        view.invalidate
      else
        UI.messagebox("Khoảng cách mép bản lề hợp lệ từ 20mm đến 500mm.")
      end
    rescue => e
      UI.messagebox("Giá trị không hợp lệ: #{e.message}")
    end

    # ==========================================================================
    # VẼ TOÀN BỘ PREVIEW & TƯƠNG TÁC 3D TRÊN VIEWPORT
    # ==========================================================================
    def draw(view)
      draw_hud(view) rescue nil
      draw_cursor_tooltip(view) rescue nil

      # 1. NỔI BẬT TẤM CÁNH ĐÃ CHỌN (Khung viền màu xanh dương sáng `#0077ff` chuẩn ABF)
      if @selected_door && @selected_door[:entity].valid?
        bb = FittingEngine.get_world_bounds(@selected_door[:entity], @selected_door[:parent])
        wire_lines = get_bb_wireframe_lines(bb)
        view.drawing_color = Sketchup::Color.new(0, 119, 255) # Blue neon ABF
        view.line_width = 3
        view.line_stipple = ""
        view.draw(GL_LINES, wire_lines)
      elsif @hover_panel && @hover_panel[:entity].valid?
        # Highlight nhẹ tấm đang hover ở Bước 1
        bb = FittingEngine.get_world_bounds(@hover_panel[:entity], @hover_panel[:parent])
        wire_lines = get_bb_wireframe_lines(bb)
        view.drawing_color = Sketchup::Color.new(245, 158, 11) # Orange preview
        view.line_width = 2
        view.line_stipple = "-"
        view.draw(GL_LINES, wire_lines)
      end

      # 2. VẼ GẠCH ĐỊNH VỊ LIỀN MẠCH VỊ TRÍ GIỮA 2 TẤM KHI ĐANG RÊ CHUỘT (BƯỚC 2)
      if @seamless_ticks && !@seamless_ticks.empty?
        draw_seamless_ticks(view, @seamless_ticks, true)
      end

      # 3. VẼ KẾT QUẢ ĐÃ THI CÔNG KHOAN DÍNH TRÊN CẢ 2 TẤM
      if @applied_ticks && !@applied_ticks.empty?
        draw_seamless_ticks(view, @applied_ticks, false)
      end
    rescue => e
      puts "[Chill AI HingeTool Draw Error]: #{e.message}"
    end

    # Vẽ các gạch định vị liền mạch nối qua khe tiếp giáp giữa Tấm Cánh và Tấm Tủ
    def draw_seamless_ticks(view, ticks, is_preview)
      color_seam_line = Sketchup::Color.new(245, 158, 11) # Cam vàng nổi bật
      color_cup       = is_preview ? Sketchup::Color.new(239, 68, 68) : Sketchup::Color.new(34, 197, 94) # Đỏ cam / Xanh lá
      color_plate     = is_preview ? Sketchup::Color.new(16, 185, 129) : Sketchup::Color.new(5, 150, 105) # Xanh ngọc
      color_screws    = Sketchup::Color.new(168, 85, 247) # Tím

      ticks.each do |tk|
        # a. ĐƯỜNG NÉT ĐỨT LIỀN MẠCH NỐI GIỮA 2 TẤM (Từ Chén Cửa -> Khe giao -> Đế Tủ)
        if tk[:seamless_line] && tk[:seamless_line].length >= 3
          p_cup   = tk[:seamless_line][0]
          p_seam  = tk[:seamless_line][1]
          p_plate = tk[:seamless_line][2]

          view.drawing_color = color_seam_line
          view.line_width = 4
          view.line_stipple = "-" # Nét đứt liền mạch chuẩn ABF
          view.draw(GL_LINES, [p_cup, p_seam, p_seam, p_plate])
        end

        # b. GẠCH ĐỊNH VỊ VUÔNG GÓC TẠI KHE TIẾP GIÁP (Tick mark ABF)
        if tk[:tick_line]
          view.drawing_color = color_seam_line
          view.line_width = 4
          view.line_stipple = "-"
          view.draw(GL_LINES, tk[:tick_line])
          view.draw_points([tk[:seam_pt]], 14, 1, color_seam_line)
        end

        # c. VÒNG TRÒN CHÉN BẢN LỀ Ø35mm TRÊN TẤM CÁNH
        if tk[:circle_pts] && !tk[:circle_pts].empty?
          draw_circle_lines(view, tk[:circle_pts], color_cup, is_preview ? 2 : 3)
          # Tâm chén lề
          view.draw_points([tk[:cup_center]], 14, 2, color_cup)
        end

        # d. 2 LỖ VÍT CHÉN TRÊN TẤM CÁNH
        if tk[:cup_screws] && !tk[:cup_screws].empty?
          view.draw_points(tk[:cup_screws], 8, 1, color_screws)
        end

        # e. 2 LỖ VÍT ĐẾ TRÊN TẤM TỦ
        if tk[:plate_screws] && !tk[:plate_screws].empty?
          view.draw_points(tk[:plate_screws], 10, 2, color_plate)
        end
      end
    end

    # Vẽ vòng tròn an toàn 100% bằng mảng cặp đoạn GL_LINES
    def draw_circle_lines(view, pts, color, width = 2)
      return if pts.nil? || pts.length < 2
      lines = []
      len = pts.length
      (0...len).each do |i|
        lines << pts[i]
        lines << pts[(i + 1) % len]
      end
      view.drawing_color = color
      view.line_width = width
      view.line_stipple = ""
      view.draw(GL_LINES, lines)
    end

    # Tooltip chữ bám theo con trỏ chuột
    def draw_cursor_tooltip(view)
      return if @mouse_x == 0 && @mouse_y == 0
      pt = Geom::Point3d.new(@mouse_x + 18, @mouse_y + 18, 0)

      if @selected_door.nil?
        if @hover_panel
          pname = get_panel_display_name(@hover_panel)
          view.draw_text(pt, "👉 Kích chuột để chọn [#{pname}] làm TẤM CÁNH", { color: Sketchup::Color.new(0, 150, 255), size: 12, bold: true })
        else
          view.draw_text(pt, "👉 BƯỚC 1: Kích chuột chọn TẤM CÁNH CỬA", { color: Sketchup::Color.new(200, 210, 225), size: 11 })
        end
      else
        door_name = get_panel_display_name(@selected_door)
        if @hover_panel && @hover_panel[:entity] != @selected_door[:entity] && !@seamless_ticks.empty?
          cab_name = get_panel_display_name(@hover_panel)
          view.draw_text(pt, "👉 BƯỚC 2: Kích chuột chọn [#{cab_name}] để khoan lề liền mạch!", { color: Sketchup::Color.new(245, 158, 11), size: 12, bold: true })
        else
          view.draw_text(pt, "👉 BƯỚC 2: Rê chuột và kích chọn TẤM TỦ (Đã chọn cánh [#{door_name}])", { color: Sketchup::Color.new(52, 211, 153), size: 11 })
        end
      end
    end

    # ==========================================================================
    # BẢNG HUD NỔI TRÊN MÀN HÌNH 3D (GÓC TRÊN BÊN TRÁI)
    # ==========================================================================
    def draw_hud(view)
      x = 24
      y = 110

      # Tiêu đề chính
      view.draw_text(Geom::Point3d.new(x, y, 0), "🚪 KHOAN BẢN LÈ (CHUẨN TƯƠNG TÁC ABF)", { color: Sketchup::Color.new(245, 158, 11), size: 14, bold: true })
      y += 24

      # Dòng trạng thái chọn tấm
      if @selected_door
        door_name = get_panel_display_name(@selected_door)
        view.draw_text(Geom::Point3d.new(x, y, 0), "🚪 Cánh đã chọn: [ #{door_name} ] (Viền xanh) | ESC: Hủy chọn | Phím F: Đảo bên", { color: Sketchup::Color.new(56, 189, 248), size: 11, bold: true })
      else
        view.draw_text(Geom::Point3d.new(x, y, 0), "👉 Bước 1: Kích chuột trái chọn TẤM CÁNH CỬA", { color: Sketchup::Color.new(250, 204, 21), size: 11, bold: true })
      end
      y += 22

      # Số lượng bản lề: [ 2 ] [ 3 ] [ 4 ] [ 5 ] [ 6 ] [ 7 ] vị trí
      view.draw_text(Geom::Point3d.new(x, y, 0), "Số lượng: ", { color: Sketchup::Color.new(200, 210, 225), size: 11 })
      cx = x + 65
      (2..7).each do |cnt|
        is_sel = (cnt == @hinge_count)
        btn_txt = is_sel ? "[ #{cnt} ]" : "  #{cnt}  "
        col = is_sel ? Sketchup::Color.new(245, 158, 11) : Sketchup::Color.new(140, 150, 165)
        view.draw_text(Geom::Point3d.new(cx, y, 0), btn_txt, { color: col, size: 11, bold: is_sel })
        cx += 34
      end
      view.draw_text(Geom::Point3d.new(cx + 8, y, 0), "vị trí (Phím 2-7)", { color: Sketchup::Color.new(140, 150, 165), size: 11 })
      y += 22

      # Kiểu bản lề A/B/C
      type_desc = case @hinge_type
                  when 'A' then "Bản Lề Trùm Ngoài (A)"
                  when 'B' then "Bản Lề Trùm Nửa (B)"
                  when 'C' then "Bản Lề Lọt Trong (C)"
                  else "Bản Lề Trùm Ngoài (A)"
                  end
      view.draw_text(Geom::Point3d.new(x, y, 0), "● #{type_desc} [Phím A / B / C]", { color: Sketchup::Color.new(165, 180, 252), size: 11, bold: true })
      y += 22

      # Khoảng cách mép (VCB)
      margin_mm = @margin.to_mm.round
      view.draw_text(Geom::Point3d.new(x, y, 0), "📏 Vị trí Bản Lề: #{margin_mm} mm (Gõ số + Enter để đổi)", { color: Sketchup::Color.new(255, 255, 255), size: 11 })
      y += 24

      # 3 bước hướng dẫn trực quan
      step1_col = @selected_door ? Sketchup::Color.new(100, 116, 139) : Sketchup::Color.new(250, 204, 21)
      step2_col = @selected_door ? Sketchup::Color.new(56, 189, 248) : Sketchup::Color.new(100, 116, 139)
      view.draw_text(Geom::Point3d.new(x, y, 0), "1️⃣ Kích chọn Tấm Cánh Cửa (Viền xanh)", { color: step1_col, size: 10, bold: @selected_door.nil? })
      y += 18
      view.draw_text(Geom::Point3d.new(x, y, 0), "2️⃣ Rê chuột vào Tấm Tủ -> Thấy gạch định vị liền mạch", { color: step2_col, size: 10, bold: !@selected_door.nil? })
      y += 18
      view.draw_text(Geom::Point3d.new(x, y, 0), "3️⃣ Kích chọn Tấm Tủ -> Đục lề dính mặt cả 2 tấm!", { color: Sketchup::Color.new(74, 222, 128), size: 10 })
    end
  end
end
