# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Stretch Tool (Công Cụ Tương Tác 3D: Di Chuyển Chùm Điểm)
# Chuẩn hoá 100% theo phong cách tương tác ABF:
#   Bước 1: Giữ chuột trái kéo quét hình chữ nhật bao quanh chùm điểm (Vertices)
#           (Quét xuyên thấu sâu - Deep X-Ray Scan, chọn tất cả điểm dù nhìn trước hay bị ẩn phía sau!)
#   Bước 2: Các điểm quét được đánh dấu chấm đỏ rực rỡ, hiện mũi tên định hướng 3D tại tâm
#   Bước 3: Bấm 4 phím mũi tên bàn phím (Lên / Xuống / Trái / Phải) để chọn hướng co giãn
#           (Phím TAB để chuyển sang chiều sâu Y, phím Lên/Xuống bấm tiếp để đổi Z ⟷ Y)
#   Bước 4: Gõ số khoảng cách vào thanh VCB (đơn vị theo SketchUp, vd: 100mm) và bấm ENTER
#           Toàn bộ chùm điểm và các cạnh/vector dính theo sẽ được kéo dài hoặc thu ngắn chính xác!
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class StretchTool
    attr_accessor :current_distance, :current_direction, :direction_name

    def self.activate_tool(options = {})
      tool = new(options)
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(options = {})
      @dragging = false
      @drag_start = nil
      @drag_current = nil
      @drag_end = nil

      @selected_clusters = []
      @all_world_points = []
      @center_point = nil

      # Mặc định khoảng cách 100mm (hoặc theo options)
      default_dist = options['distance'] || options[:distance] || 100.0
      @current_distance = default_dist.to_f.mm rescue 100.mm

      @current_direction = Geom::Vector3d.new(0, 0, 1) # Z+
      @direction_name = "Trục Z (Lên trên)"
      @active_dir_key = :up

      @mouse_x = 0
      @mouse_y = 0
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      reset_selection
      update_status_bar

      puts "[Chill AI StretchTool] 🎯 Đã kích hoạt công cụ Di Chuyển Chùm Điểm (Chuẩn ABF)."
      AudioPlayer.play({ 'text' => "Đã kích hoạt Di chuyển chùm điểm. Mời anh Huy kéo chuột quét các điểm cần co giãn nhé." }) rescue nil if defined?(AudioPlayer)

      @view.invalidate
    end

    def deactivate(view)
      reset_selection
      view.invalidate rescue nil
    end

    def resume(view)
      update_status_bar
      view.invalidate rescue nil
    end

    def reset_selection
      @dragging = false
      @drag_start = nil
      @drag_current = nil
      @drag_end = nil
      @selected_clusters = []
      @all_world_points = []
      @center_point = nil
      @active_dir_key = :up
      update_status_bar
    end

    # ==========================================================================
    # CẬP NHẬT THANH TRẠNG THÁI & VCB
    # ==========================================================================
    def update_status_bar
      if @all_world_points.nil? || @all_world_points.empty?
        Sketchup.status_text = "Chill AI [Di Chuyển Chùm Điểm ABF] 👉 Kéo chuột quét hình chữ nhật bao quanh chùm điểm cần co giãn (Quét xuyên thấu toàn bộ mặt trước & mặt sau)"
      else
        pts_count = @all_world_points.length
        dist_str = @current_distance ? "#{@current_distance.to_mm.round(1)}mm" : "100.0mm"
        Sketchup.status_text = "Chill AI [Di Chuyển Chùm Điểm] 🎯 Đã bắt #{pts_count} điểm | ➡️ Hướng: #{@direction_name} | ⌨️ Bấm mũi tên (Lên/Xuống/Trái/Phải/Tab) | 📏 Gõ số khoảng cách rồi bấm ENTER (Hiện tại: #{dist_str}) | ESC: Quét lại"
        Sketchup.vcb_label = "Khoảng cách:"
        Sketchup.vcb_value = dist_str
      end
    end

    def enableVCB?
      true
    end

    def onUserText(text, view)
      return if @selected_clusters.nil? || @selected_clusters.empty?

      begin
        dist = text.to_l rescue nil
        if dist.nil? || dist == 0
          num = text.to_f
          dist = num.mm if num != 0
        end

        if dist && dist != 0
          @current_distance = dist
          Sketchup.vcb_value = "#{dist.to_mm.round(1)}mm"
          execute_stretch(dist)
        else
          Sketchup.status_text = "Chill AI: Vui lòng nhập khoảng cách hợp lệ (ví dụ: 100 hoặc 50mm)"
        end
      rescue => e
        puts "[Chill AI StretchTool onUserText Error]: #{e.message}"
      end
    end

    # ==========================================================================
    # SỰ KIỆN CHUỘT (QUÉT VÙNG HÌNH CHỮ NHẬT XUYÊN THẤU)
    # ==========================================================================
    def onLButtonDown(flags, x, y, view)
      @dragging = true
      @drag_start = [x, y]
      @drag_current = [x, y]
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      @mouse_x = x
      @mouse_y = y

      if @dragging
        @drag_current = [x, y]
        view.invalidate
      end
    end

    def onLButtonUp(flags, x, y, view)
      if @dragging
        @dragging = false
        @drag_end = [x, y]
        scan_clusters(view)
        view.invalidate
      end
    end

    # ==========================================================================
    # SỰ KIỆN BÀN PHÍM (CHỌN HƯỚNG MŨI TÊN & PHÍM TẮT)
    # ==========================================================================
    def onKeyDown(key, repeat, flags, view)
      # 1. Các phím mũi tên
      case key
      when 38, (defined?(VK_UP) ? VK_UP : 38)
        set_direction_by_key(:up, view)
        return true

      when 40, (defined?(VK_DOWN) ? VK_DOWN : 40)
        set_direction_by_key(:down, view)
        return true

      when 37, (defined?(VK_LEFT) ? VK_LEFT : 37)
        set_direction_by_key(:left, view)
        return true

      when 39, (defined?(VK_RIGHT) ? VK_RIGHT : 39)
        set_direction_by_key(:right, view)
        return true

      when 9 # Phím TAB
        set_direction_by_key(:tab, view)
        return true

      when 27 # Phím ESC: Quét lại
        reset_selection
        view.invalidate
        return true

      when 13 # Phím ENTER: Thực thi nếu đã có điểm
        if @selected_clusters && !@selected_clusters.empty?
          execute_stretch(@current_distance)
          return true
        end
      end

      false
    end

    # Đặt hướng di chuyển dựa trên phím bấm và góc nhìn Camera
    def set_direction_by_key(dir_key, view)
      cam = view.camera
      is_top_view = cam.direction.z < -0.85

      case dir_key
      when :up
        if is_top_view
          @current_direction = Geom::Vector3d.new(0, 1, 0)
          @direction_name = "Trục Y (Sâu vào trong)"
        else
          # Nếu đang ở Z+ bấm tiếp Up -> chuyển sang Y+ (chiều sâu)
          if @active_dir_key == :up && @current_direction == Geom::Vector3d.new(0, 0, 1)
            @current_direction = Geom::Vector3d.new(0, 1, 0)
            @direction_name = "Trục Y (Sâu vào trong)"
          else
            @current_direction = Geom::Vector3d.new(0, 0, 1)
            @direction_name = "Trục Z (Lên trên)"
          end
        end
        @active_dir_key = :up

      when :down
        if is_top_view
          @current_direction = Geom::Vector3d.new(0, -1, 0)
          @direction_name = "Trục Y (Kéo ra ngoài)"
        else
          # Nếu đang ở Z- bấm tiếp Down -> chuyển sang Y- (chiều sâu kéo ra ngoài)
          if @active_dir_key == :down && @current_direction == Geom::Vector3d.new(0, 0, -1)
            @current_direction = Geom::Vector3d.new(0, -1, 0)
            @direction_name = "Trục Y (Kéo ra ngoài)"
          else
            @current_direction = Geom::Vector3d.new(0, 0, -1)
            @direction_name = "Trục Z (Xuống dưới)"
          end
        end
        @active_dir_key = :down

      when :right
        cam_x = cam.xaxis
        if cam_x.x.abs >= cam_x.y.abs
          sign = cam_x.x >= 0 ? 1 : -1
          @current_direction = Geom::Vector3d.new(sign, 0, 0)
          @direction_name = sign > 0 ? "Trục X (Sang phải)" : "Trục X (Sang trái)"
        else
          sign = cam_x.y >= 0 ? 1 : -1
          @current_direction = Geom::Vector3d.new(0, sign, 0)
          @direction_name = sign > 0 ? "Trục Y (Sâu vào trong)" : "Trục Y (Kéo ra ngoài)"
        end
        @active_dir_key = :right

      when :left
        cam_x = cam.xaxis
        if cam_x.x.abs >= cam_x.y.abs
          sign = cam_x.x >= 0 ? -1 : 1
          @current_direction = Geom::Vector3d.new(sign, 0, 0)
          @direction_name = sign > 0 ? "Trục X (Sang phải)" : "Trục X (Sang trái)"
        else
          sign = cam_x.y >= 0 ? -1 : 1
          @current_direction = Geom::Vector3d.new(0, sign, 0)
          @direction_name = sign > 0 ? "Trục Y (Sâu vào trong)" : "Trục Y (Kéo ra ngoài)"
        end
        @active_dir_key = :left

      when :tab
        cycle_all_directions
      end

      update_status_bar
      view.invalidate
    end

    def cycle_all_directions
      dirs = [
        [Geom::Vector3d.new(0, 0, 1),  "Trục Z (Lên trên)"],
        [Geom::Vector3d.new(0, 0, -1), "Trục Z (Xuống dưới)"],
        [Geom::Vector3d.new(1, 0, 0),  "Trục X (Sang phải)"],
        [Geom::Vector3d.new(-1, 0, 0), "Trục X (Sang trái)"],
        [Geom::Vector3d.new(0, 1, 0),  "Trục Y (Sâu vào trong)"],
        [Geom::Vector3d.new(0, -1, 0), "Trục Y (Kéo ra ngoài)"]
      ]
      curr_idx = dirs.find_index { |d| d[0] == @current_direction } || 0
      next_idx = (curr_idx + 1) % dirs.length
      @current_direction = dirs[next_idx][0]
      @direction_name = dirs[next_idx][1]
      update_status_bar
    end

    # Khởi tạo hướng mặc định phù hợp với góc nhìn hiện tại
    def init_default_direction(view)
      cam = view.camera
      if cam.direction.z < -0.85
        @current_direction = Geom::Vector3d.new(0, 1, 0)
        @direction_name = "Trục Y (Sâu vào trong)"
        @active_dir_key = :up
      else
        @current_direction = Geom::Vector3d.new(0, 0, 1)
        @direction_name = "Trục Z (Lên trên)"
        @active_dir_key = :up
      end
    end

    # ==========================================================================
    # THU THẬP CHÙM ĐIỂM (QUÉT XUYÊN THẤU - DEEP X-RAY SELECTION)
    # ==========================================================================
    def scan_clusters(view)
      return unless @drag_start && @drag_end

      x1, y1 = @drag_start
      x2, y2 = @drag_end
      min_x = [x1, x2].min
      max_x = [x1, x2].max
      min_y = [y1, y2].min
      max_y = [y1, y2].max

      if (max_x - min_x) < 4 && (max_y - min_y) < 4
        # Click vô tình một điểm
        return
      end

      screen_box = [min_x, min_y, max_x, max_y]
      model = Sketchup.active_model

      # Nếu người dùng đã chọn sẵn đối tượng (ví dụ 1 cụm tủ cụ thể) -> Chỉ quét trong cụm đó
      # Nếu không chọn gì -> Quét toàn bộ mô hình (active_entities)
      root_ents = if model.selection && !model.selection.empty?
                    model.selection.to_a
                  else
                    model.active_entities.to_a
                  end

      @selected_clusters = []
      @all_world_points = []

      # Bắt đầu quét đệ quy xuyên thấu
      collect_from_entities(root_ents, Geom::Transformation.new, screen_box, view)

      if @all_world_points.empty?
        Sketchup.status_text = "Chill AI: Chưa quét trúng điểm nào. Mời anh Huy kéo chuột bao quanh chùm điểm cần co giãn."
        AudioPlayer.play({ 'text' => "Chưa quét trúng điểm nào, mời anh Huy quét lại nhé." }) rescue nil if defined?(AudioPlayer)
      else
        # Tính tâm 3D của toàn bộ chùm điểm
        total_x = 0.0
        total_y = 0.0
        total_z = 0.0
        @all_world_points.each do |pt|
          total_x += pt.x
          total_y += pt.y
          total_z += pt.z
        end
        n = @all_world_points.length.to_f
        @center_point = Geom::Point3d.new(total_x / n, total_y / n, total_z / n)

        init_default_direction(view)
        update_status_bar
        AudioPlayer.play({ 'text' => "Đã bắt được #{@all_world_points.length} điểm. Mời anh Huy chọn hướng và nhập khoảng cách nhé." }) rescue nil if defined?(AudioPlayer)
      end
    end

    def collect_from_entities(entities, parent_trans, screen_box, view)
      entities.each do |ent|
        next unless ent.valid?
        next if ent.hidden? || !ent.layer.visible?

        if ent.is_a?(Sketchup::Group)
          gname = ent.name.to_s
          # Bỏ qua các nhãn 3D hiển thị
          next if gname =~ /^(Chill_AI_Label|_ABF_LABEL|ABF_LABEL)/i

          sub_trans = parent_trans * ent.transformation
          has_mesh = ent.entities.any? { |c| c.is_a?(Sketchup::Edge) || c.is_a?(Sketchup::Face) }
          has_sub = ent.entities.any? { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }

          if has_mesh
            analyze_leaf_container(ent, ent.entities, sub_trans, screen_box, view, parent_trans)
          end
          if has_sub
            collect_from_entities(ent.entities, sub_trans, screen_box, view)
          end

        elsif ent.is_a?(Sketchup::ComponentInstance)
          cname = ent.name.to_s
          dname = ent.definition.name.to_s rescue ""
          next if cname =~ /^(Chill_AI_Label|_ABF_LABEL|ABF_LABEL)/i || dname =~ /^(Chill_AI_Label|_ABF_LABEL|ABF_LABEL)/i

          sub_trans = parent_trans * ent.transformation
          has_mesh = ent.definition.entities.any? { |c| c.is_a?(Sketchup::Edge) || c.is_a?(Sketchup::Face) }
          has_sub = ent.definition.entities.any? { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }

          if has_mesh
            analyze_leaf_container(ent, ent.definition.entities, sub_trans, screen_box, view, parent_trans)
          end
          if has_sub
            collect_from_entities(ent.definition.entities, sub_trans, screen_box, view)
          end
        end
      end
    end

    def analyze_leaf_container(container, entities_pool, total_trans, screen_box, view, parent_trans)
      min_x, min_y, max_x, max_y = screen_box

      all_edges = entities_pool.grep(Sketchup::Edge)
      all_verts = all_edges.map(&:vertices).flatten.uniq
      return if all_verts.empty?

      selected_local_pts = []
      selected_world_pts = []

      all_verts.each do |v|
        local_pt = v.position
        world_pt = total_trans * local_pt
        screen_pt = view.screen_coords(world_pt)

        # Điều kiện: Điểm nằm phía trước Camera (screen_pt.z > 0) và nằm trong khung quét màn hình
        if screen_pt.z > 0 && screen_pt.x >= min_x && screen_pt.x <= max_x && screen_pt.y >= min_y && screen_pt.y <= max_y
          selected_local_pts << local_pt
          selected_world_pts << world_pt
          @all_world_points << world_pt
        end
      end

      if !selected_local_pts.empty?
        # Kiểm tra xem 100% đỉnh của tấm ván có nằm trọn vẹn trong vùng quét không
        is_entire_panel = (selected_local_pts.length == all_verts.length)

        @selected_clusters << {
          container: container,
          entities_pool: entities_pool,
          total_trans: total_trans,
          parent_trans: parent_trans,
          local_points: selected_local_pts,
          world_points: selected_world_pts,
          total_vertices_count: all_verts.length,
          is_entire: is_entire_panel
        }
      end
    end

    # ==========================================================================
    # THỰC THI CO GIÃN HÌNH HỌC (STRETCH OPERATION)
    # ==========================================================================
    def execute_stretch(distance = nil)
      distance ||= @current_distance || 100.mm
      return if @selected_clusters.nil? || @selected_clusters.empty?

      model = Sketchup.active_model
      model.start_operation("Chill AI - Di Chuyển Chùm Điểm (Chuẩn ABF)", true)

      total_verts_moved = 0
      entire_panels_moved = 0
      affected_panels = []

      world_vector = @current_direction.clone
      world_vector.length = distance

      @selected_clusters.each do |cluster|
        container = cluster[:container]
        next unless container && container.valid?

        if cluster[:is_entire]
          # 🌟 TRƯỜNG HỢP 1: 100% ĐỈNH ĐƯỢC CHỌN (TẤM NÓC TỦ, ĐỢT TỦ, PHÀO...)
          # Dời nguyên khối để bảo toàn vị trí lỗ cam, rãnh ngàm và nhãn dán!
          parent_trans = cluster[:parent_trans] || Geom::Transformation.new
          local_move_vec = world_vector.transform(parent_trans.inverse)
          move_t = Geom::Transformation.translation(local_move_vec)
          container.transformation = move_t * container.transformation
          entire_panels_moved += 1
          affected_panels << container
        else
          # 🌟 TRƯỜNG HỢP 2: KÉO GIÃN HÌNH HỌC (HÔNG TỦ, VÁCH NGĂN, HẬU TỦ...)
          # Kéo dài/thu ngắn các cạnh và mặt nối với các đỉnh được chọn!
          if container.is_a?(Sketchup::ComponentInstance)
            container.make_unique if container.definition.count_instances > 1
            ents = container.definition.entities
          elsif container.is_a?(Sketchup::Group)
            ents = container.entities
          else
            next
          end

          total_trans = cluster[:total_trans]
          local_vec = world_vector.transform(total_trans.inverse)

          target_pts = cluster[:local_points]
          verts_to_move = []
          all_verts = ents.grep(Sketchup::Edge).map(&:vertices).flatten.uniq

          all_verts.each do |v|
            if target_pts.any? { |pt| v.position.distance(pt) < 0.001 }
              verts_to_move << v
            end
          end

          if !verts_to_move.empty?
            vectors = Array.new(verts_to_move.length, local_vec)
            ents.transform_by_vectors(verts_to_move, vectors)
            total_verts_moved += verts_to_move.length
            affected_panels << container
          end
        end
      end

      model.commit_operation

      # Cập nhật nhãn nếu có tấm ván nào mang nhãn 3D
      refresh_labels_after_stretch(affected_panels) rescue nil

      dist_str = distance.to_mm.round(1).to_s + "mm"
      dir_str = @direction_name || "hướng đã chọn"
      Sketchup.status_text = "Chill AI: ✅ Đã co giãn #{total_verts_moved} điểm và dời #{entire_panels_moved} tấm theo #{dir_str} một đoạn #{dist_str} thành công!"
      AudioPlayer.play({ 'text' => "Đã kéo giãn chùm điểm #{dist_str} thành công cho anh Huy rồi nhé!" }) rescue nil if defined?(AudioPlayer)

      # Hoàn tất: chuẩn bị cho lần quét tiếp theo
      reset_selection
      @view.invalidate
    end

    # Tự động cập nhật lại nhãn sau khi co giãn
    def refresh_labels_after_stretch(panels)
      return if panels.nil? || panels.empty?
      panels.uniq.each do |panel|
        next unless panel && panel.valid?
        # Nếu panel có nhãn cũ thì làm mới
        if defined?(LabelingEngine) && LabelingEngine.respond_to?(:clean_label_groups_recursive)
          has_label = false
          sub_ents = panel.is_a?(Sketchup::Group) ? panel.entities : panel.definition.entities rescue []
          sub_ents.grep(Sketchup::Group).each do |g|
            if g.name.to_s =~ /^(Chill_AI_Label|_ABF_LABEL|ABF_LABEL)/i
              has_label = true
              break
            end
          end
          if has_label
            # Nhãn tồn tại -> Người dùng có thể bấm Gắn Nhãn lại hoặc cập nhật
            puts "[Chill AI StretchTool] Tấm ván [#{panel.name}] đã được co giãn hình học thành công."
          end
        end
      end
    end

    # ==========================================================================
    # VẼ TRỰC QUAN TRÊN KHÔNG GIAN 3D (DRAW CALLBACK)
    # ==========================================================================
    def draw(view)
      # 1. Vẽ khung chữ nhật nét đứt khi kéo rê chuột
      if @dragging && @drag_start && @drag_current
        x1, y1 = @drag_start
        x2, y2 = @drag_current
        pts = [
          Geom::Point3d.new(x1, y1, 0),
          Geom::Point3d.new(x2, y1, 0),
          Geom::Point3d.new(x2, y2, 0),
          Geom::Point3d.new(x1, y2, 0)
        ]
        # Mặt mờ bán trong suốt
        view.drawing_color = Sketchup::Color.new(56, 189, 248, 60)
        view.draw2d(GL_POLYGON, pts) rescue nil
        # Viền nét đứt màu xanh dương
        view.drawing_color = Sketchup::Color.new(2, 132, 199)
        view.line_width = 2
        view.line_stipple = "-"
        view.draw2d(GL_LINE_LOOP, pts)
      end

      # 2. Vẽ các điểm đỏ tại vị trí các đỉnh được chọn
      if @all_world_points && !@all_world_points.empty?
        view.drawing_color = Sketchup::Color.new(239, 68, 68) # Đỏ rực #ef4444
        view.draw_points(@all_world_points, 8, 2, "red") # Style 2: square hình vuông
      end

      # 3. Vẽ hệ trục 3D định hướng tại tâm chùm điểm
      if @center_point && @current_direction
        draw_direction_gizmo(view)
      end
    end

    def draw_direction_gizmo(view)
      c = @center_point
      axis_len = view.pixels_to_model(85, c)
      return if axis_len <= 0

      # Trục X mờ (Đỏ)
      view.line_width = 1
      view.line_stipple = ""
      view.drawing_color = Sketchup::Color.new(239, 68, 68, 120)
      view.draw(GL_LINES, [c, c + Geom::Vector3d.new(axis_len * 0.7, 0, 0), c, c + Geom::Vector3d.new(-axis_len * 0.7, 0, 0)])

      # Trục Y mờ (Xanh lục)
      view.drawing_color = Sketchup::Color.new(34, 197, 94, 120)
      view.draw(GL_LINES, [c, c + Geom::Vector3d.new(0, axis_len * 0.7, 0), c, c + Geom::Vector3d.new(0, -axis_len * 0.7, 0)])

      # Trục Z mờ (Xanh lam)
      view.drawing_color = Sketchup::Color.new(59, 130, 246, 120)
      view.draw(GL_LINES, [c, c + Geom::Vector3d.new(0, 0, axis_len * 0.7), c, c + Geom::Vector3d.new(0, 0, -axis_len * 0.7)])

      # 🌟 MŨI TÊN HƯỚNG HIỆN TẠI (NỔI BẬT & RỰC RỠ)
      dir_vec = @current_direction.clone
      dir_vec.length = axis_len
      target_pt = c + dir_vec

      arrow_color = if @current_direction.z.abs > 0.8
                      Sketchup::Color.new(56, 189, 248) # Xanh dương sáng (Z)
                    elsif @current_direction.x.abs > 0.8
                      Sketchup::Color.new(248, 113, 113) # Đỏ cam sáng (X)
                    else
                      Sketchup::Color.new(74, 222, 128) # Xanh lục sáng (Y)
                    end

      # Thân mũi tên đậm
      view.line_width = 4
      view.drawing_color = arrow_color
      view.draw(GL_LINES, [c, target_pt])

      # Đầu mũi tên 3D (Arrowhead)
      head_len = axis_len * 0.28
      head_w = axis_len * 0.12
      back_vec = @current_direction.clone.reverse
      back_vec.length = head_len
      base_pt = target_pt + back_vec

      perp_axes = @current_direction.axes
      u = perp_axes[0].clone.tap { |v| v.length = head_w }
      v = perp_axes[1].clone.tap { |v| v.length = head_w }

      p1 = base_pt + u
      p2 = base_pt - u
      p3 = base_pt + v
      p4 = base_pt - v

      view.line_width = 3
      view.draw(GL_LINES, [
        target_pt, p1, target_pt, p2,
        target_pt, p3, target_pt, p4,
        p1, p3, p3, p2, p2, p4, p4, p1
      ])

      # Nhãn text chỉ hướng và khoảng cách
      dist_val = (@current_distance || 100.mm).to_mm.round(1)
      text_offset = @current_direction.clone.tap { |vec| vec.length = axis_len * 0.18 }
      text_pos = target_pt + text_offset
      label_text = "  #{@direction_name} (#{dist_val}mm)"
      view.draw_text(text_pos, label_text, { size: 12, bold: true, color: arrow_color })
    end
  end
end
