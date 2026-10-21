# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Fitting Engine (Chuyên Gia Phụ Kiện: Cam Chốt & Bản Lề)
# Chưng cất tinh hoa từ ABF Solutions & Chuẩn hóa Châu Âu System 32
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module FittingEngine
    LAYER_CAM_15       = 'DRILL_CAM_15'.freeze
    LAYER_DOWEL_8      = 'DRILL_DOWEL_8'.freeze
    LAYER_PIN_5        = 'DRILL_PIN_5'.freeze
    LAYER_HINGE_35     = 'DRILL_HINGE_35'.freeze
    LAYER_HINGE_BASE_5 = 'DRILL_HINGE_BASE_5'.freeze

    PRESETS_FILE = File.expand_path(File.join(File.dirname(__FILE__), '..', 'knowledge_base', 'fitting_presets.json')).freeze

    def self.log_debug(msg)
      log_file = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'scratch', 'fitting_debug.log'))
      File.open(log_file, 'a:UTF-8') do |f|
        f.puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
      end
    rescue => _e
    end

    # Đọc danh sách cấu hình Preset từ JSON
    def self.load_presets
      return {} unless File.exist?(PRESETS_FILE)
      JSON.parse(File.read(PRESETS_FILE, encoding: 'UTF-8'))
    rescue => e
      puts "[Chill AI FittingEngine] Lỗi đọc presets: #{e.message}"
      {}
    end

    # Lưu danh sách cấu hình Preset vào JSON
    def self.save_presets(data)
      File.open(PRESETS_FILE, 'w:UTF-8') do |f|
        f.write(JSON.pretty_generate(data))
      end
      true
    rescue => e
      puts "[Chill AI FittingEngine] Lỗi lưu presets: #{e.message}"
      false
    end

    # Lấy Preset đang hoạt động
    def self.get_active_preset(params = nil)
      if params.is_a?(Hash) && (params['D'] || params[:D] || params['holes_face'])
        return params
      end
      data = load_presets
      return {} unless data['presets']
      active_id = (params && params['id']) || data['active_preset_id']
      found = data['presets'].find { |p| p['id'] == active_id }
      found || data['presets'].first || {}
    end

    # Thiết lập màu sắc đặc trưng chuẩn công nghiệp cho Layer
    def self.set_layer_default_color(layer, layer_name)
      return unless layer.respond_to?(:color=)
      case layer_name
      when /CAM_15|Drill_15/i
        layer.color = Sketchup::Color.new(235, 87, 87)  # Đỏ cam (Bầu cam 15)
      when /DOWEL|Drill_8/i
        layer.color = Sketchup::Color.new(39, 174, 96)   # Xanh lá cây (Chốt gỗ 8)
      when /PIN_5|Drill_5/i
        layer.color = Sketchup::Color.new(47, 128, 237)  # Xanh dương (Ty cam 5)
      when /HINGE_35/i
        layer.color = Sketchup::Color.new(242, 153, 74)  # Vàng cam (Chén bản lề 35)
      when /HINGE_BASE/i
        layer.color = Sketchup::Color.new(155, 81, 224)  # Tím (Vít đế bản lề)
      end
    rescue => _e
    end

    # 1. TỰ ĐỘNG TẠO / LẤY CÁC LAYER KHOAN LỖ CHO MÁY CNC / ASPIRE
    def self.ensure_layers(model)
      layers = {}
      [LAYER_CAM_15, LAYER_DOWEL_8, LAYER_PIN_5, LAYER_HINGE_35, LAYER_HINGE_BASE_5].each do |name|
        lyr = model.layers[name] || model.layers.add(name)
        set_layer_default_color(lyr, name)
        layers[name] = lyr
      end
      layers
    end

    # 2. BÓC TÁCH TOÀN BỘ CÁC TẤM VÁN TRONG VÙNG CHỌN
    def self.collect_panels(selection)
      panels = []
      selection.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          sub_entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          has_subs = false
          sub_entities.each do |sub|
            if sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
              next if sub.name =~ /Chill_AI_Fittings/i
              panels << { entity: sub, parent: entity }
              has_subs = true
            end
          end
          panels << { entity: entity, parent: nil } unless has_subs
        end
      end
      panels
    end

    # TÍNH TOÁN TOẠ ĐỘ WORLD BOUNDS CHUẨN XÁC 100% (KHÔNG NHÂN ĐÔI TRANSFORMATION, BIẾN ĐỔI CẢ 8 ĐỈNH)
    def self.get_world_bounds(entity, parent = nil)
      if parent.nil?
        return entity.bounds
      end
      p_trans = parent.transformation
      bbox = Geom::BoundingBox.new
      (0..7).each do |i|
        bbox.add(entity.bounds.corner(i).transform(p_trans))
      end
      bbox
    end

    # Phân loại hướng của tấm ván (Đứng - Vertical hay Ngang - Horizontal hay Hậu - FrontBack)
    def self.analyze_panel_orientation(panel_info)
      ent = panel_info[:entity]
      bb = ent.bounds
      dx = bb.width.to_m * 1000.0
      dy = bb.height.to_m * 1000.0
      dz = bb.depth.to_m * 1000.0

      dims = [{ axis: :x, val: dx }, { axis: :y, val: dy }, { axis: :z, val: dz }].sort_by { |d| d[:val] }
      thickness = dims[0][:val]
      length    = dims[2][:val]
      width     = dims[1][:val]
      thin_axis = dims[0][:axis]

      type = case thin_axis
             when :x then :vertical
             when :z then :horizontal
             when :y then :front_back
             else :unknown
             end

      {
        type: type,
        thickness: thickness,
        length: length,
        width: width,
        thin_axis: thin_axis,
        bounds_world: get_world_bounds(ent, panel_info[:parent])
      }
    end

    # ==========================================================================
    # 🌟 VẼ ĐƯỜNG TRÒN / MẶT TRÒN DÍNH TRỰC TIẾP TRÊN BỀ MẶT VÁN (CHUẨN ABF & CNC)
    # TỰ ĐỘNG CHIẾU CHUẨN XÁC VÀO FACE THỰC TẾ (COPLANAR PROJECTION)
    # ==========================================================================
    def self.add_circle_to_panel(panel_info, center_world, normal_world, radius, layer_name, depth = 0)
      return nil unless panel_info && panel_info[:entity]
      ent = panel_info[:entity]
      parent = panel_info[:parent]
      model = Sketchup.active_model

      target_layer = model.layers[layer_name] || model.layers.add(layer_name)
      set_layer_default_color(target_layer, layer_name)

      # 1. Tính toán ma trận biến đổi thế giới của tấm ván
      world_trans = parent.nil? ? ent.transformation : (parent.transformation * ent.transformation)
      inv_trans = world_trans.inverse

      # 2. Chuyển toạ độ tâm thế giới và vector pháp tuyến sang hệ toạ độ Local
      local_center = center_world.transform(inv_trans)
      local_normal = normal_world.transform(inv_trans)
      local_normal.normalize!

      # 3. Lấy entities của tấm ván (sau khi make_unique nếu là ComponentInstance)
      if ent.is_a?(Sketchup::ComponentInstance)
        ent.make_unique rescue nil
        target_entities = ent.definition.entities
      elsif ent.is_a?(Sketchup::Group)
        target_entities = ent.entities
      else
        return nil
      end

      # 4. CHIẾU CHUẨN XÁC VÀO FACE THỰC TẾ CỦA TẤM VÁN ĐỂ CHỐNG LỆCH CAO ĐỘ (COPLANAR PROJECTION)
      best_face = nil
      min_dist = 1000.0

      target_entities.grep(Sketchup::Face).each do |f|
        dot = f.normal.dot(local_normal)
        if dot > 0.85
          dist = (f.plane[0] * local_center.x + f.plane[1] * local_center.y + f.plane[2] * local_center.z + f.plane[3]).abs
          if dist < min_dist
            min_dist = dist
            best_face = f
          end
        end
      end

      if best_face && min_dist < 30.mm
        local_center = local_center.project_to_plane(best_face.plane)
        local_normal = best_face.normal
      end

      # 5. Vẽ đường tròn 24 cạnh chuẩn xác vào entities của tấm ván
      circle_edges = target_entities.add_circle(local_center, local_normal, radius, 24)
      return nil unless circle_edges && !circle_edges.empty?

      # 6. Gán Layer cho tất cả các đoạn cạnh của đường tròn
      circle_edges.each { |e| e.layer = target_layer }

      # 7. Tìm Face tròn đã tự động cắt trên bề mặt tấm ván, hoặc tạo Face mới
      radius_val = radius.to_f
      area_target = Math::PI * radius_val * radius_val
      face = circle_edges.first.faces.find { |f| (f.area - area_target).abs < 25.0 }
      face ||= target_entities.add_face(circle_edges) rescue nil
      face.layer = target_layer if face

      # 8. Gán thuộc tính kỹ thuật phục vụ Nesting / DXF
      curve = circle_edges.first.curve
      if curve
        dia_mm = (radius * 2.0).to_m * 1000.0
        depth_val = depth.to_f > 0 ? depth.to_m * 1000.0 : default_depth_for_layer(layer_name, radius)
        curve.set_attribute('chill_ai_drill', 'diameter', dia_mm)
        curve.set_attribute('chill_ai_drill', 'depth', depth_val)
        curve.set_attribute('chill_ai_drill', 'layer', layer_name)
        curve.set_attribute('chill_ai_drill', 'type', 'circle_face')
      end

      log_debug("  [OK Circle] #{layer_name} dia=#{radius*2.to_m*1000}mm at world=#{center_world} local=#{local_center} face=#{!face.nil?}")
      circle_edges
    rescue => e
      log_debug("  [ERR Circle] #{layer_name}: #{e.message}")
      puts "[Chill AI FittingEngine] Lỗi add_circle_to_panel: #{e.message}"
      nil
    end

    def self.default_depth_for_layer(layer_name, _radius)
      case layer_name
      when /CAM_15|Drill_15/i then 13.5
      when /DOWEL|Drill_8/i   then 25.0
      when /PIN_5|Drill_5/i    then 12.0
      when /HINGE_35/i        then 11.5
      else 12.0
      end
    end

    # ==========================================================================
    # NHẬN DIỆN VAI TRÒ 2 TẤM TIẾP XÚC VUÔNG GÓC: EDGE_PANEL vs FACE_PANEL
    # ==========================================================================
    def self.identify_joint_roles(panel_a, panel_b, axis, joint_coord)
      bb_a = get_world_bounds(panel_a[:entity], panel_a[:parent])
      bb_b = get_world_bounds(panel_b[:entity], panel_b[:parent])

      dim_a = case axis
              when :x then bb_a.max.x - bb_a.min.x
              when :y then bb_a.max.y - bb_a.min.y
              when :z then bb_a.max.z - bb_a.min.z
              end

      dim_b = case axis
              when :x then bb_b.max.x - bb_b.min.x
              when :y then bb_b.max.y - bb_b.min.y
              when :z then bb_b.max.z - bb_b.min.z
              end

      if dim_a >= dim_b
        edge_panel = panel_a
        face_panel = panel_b
        edge_bb    = bb_a
        face_bb    = bb_b
      else
        edge_panel = panel_b
        face_panel = panel_a
        edge_bb    = bb_b
        face_bb    = bb_a
      end

      dir_into_edge = 1
      case axis
      when :x
        dist_to_min = (joint_coord - edge_bb.min.x).abs
        dist_to_max = (joint_coord - edge_bb.max.x).abs
        dir_into_edge = (dist_to_min <= dist_to_max) ? 1 : -1
      when :y
        dist_to_min = (joint_coord - edge_bb.min.y).abs
        dist_to_max = (joint_coord - edge_bb.max.y).abs
        dir_into_edge = (dist_to_min <= dist_to_max) ? 1 : -1
      when :z
        dist_to_min = (joint_coord - edge_bb.min.z).abs
        dist_to_max = (joint_coord - edge_bb.max.z).abs
        dir_into_edge = (dist_to_min <= dist_to_max) ? 1 : -1
      end

      {
        edge_panel: edge_panel,
        face_panel: face_panel,
        edge_bb: edge_bb,
        face_bb: face_bb,
        dir_into_edge: dir_into_edge
      }
    end

    # ==========================================================================
    # 🎯 3. THI CÔNG KHOAN LIÊN KẾT CAM CHỐT DÍNH TRỰC TIẾP TRÊN 2 TẤM VÁN
    # TỰ ĐỘNG ĐẢO CHIỀU RẢI Ở ĐẦU CUỐI (CHỐNG TRÀO RA NGOÀI BIÊN VÁN)
    # ==========================================================================
    def self.apply_joint_pair(panel_a, panel_b, axis, run_axis, joint_coord, base_pts, preset, flip_face = false)
      roles = identify_joint_roles(panel_a, panel_b, axis, joint_coord)
      edge_panel    = roles[:edge_panel]
      face_panel    = roles[:face_panel]
      edge_bb       = roles[:edge_bb]
      face_bb       = roles[:face_bb]
      dir_into_edge = roles[:dir_into_edge]

      offset_L = (preset['L'] || 34.0).to_f.mm
      d_holes    = (preset['D'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      edge_holes = (preset['d'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      side_holes = (preset['Dside'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      n_dists    = (preset['n'] || []).map { |item| (item['val'] || 32.0).to_f.mm }

      if d_holes.empty?
        d_holes = [{ 'dia' => 15.0, 'depth' => 13.5, 'layer' => LAYER_CAM_15 }]
      end
      if edge_holes.empty?
        edge_holes = [{ 'dia' => 8.0, 'depth' => 34.0, 'layer' => LAYER_DOWEL_8 }]
      end
      if side_holes.empty?
        side_holes = [{ 'dia' => 5.0, 'depth' => 12.0, 'layer' => LAYER_PIN_5 }]
      end

      thick_axis = ([:x, :y, :z] - [axis, run_axis]).first
      mid_thick = case thick_axis
                  when :z then (edge_bb.min.z + edge_bb.max.z) / 2.0
                  when :y then (edge_bb.min.y + edge_bb.max.y) / 2.0
                  when :x then (edge_bb.min.x + edge_bb.max.x) / 2.0
                  end

      cam_face_coord = nil
      cam_face_normal = nil
      case thick_axis
      when :z
        if flip_face
          cam_face_coord = edge_bb.max.z
          cam_face_normal = Geom::Vector3d.new(0, 0, 1)
        else
          cam_face_coord = edge_bb.min.z
          cam_face_normal = Geom::Vector3d.new(0, 0, -1)
        end
      when :y
        cam_face_coord = flip_face ? edge_bb.max.y : edge_bb.min.y
        cam_face_normal = flip_face ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, -1, 0)
      when :x
        cam_face_coord = flip_face ? edge_bb.max.x : edge_bb.min.x
        cam_face_normal = flip_face ? Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(-1, 0, 0)
      end

      edge_drill_normal = case axis
                          when :x then Geom::Vector3d.new(-dir_into_edge, 0, 0)
                          when :y then Geom::Vector3d.new(0, -dir_into_edge, 0)
                          when :z then Geom::Vector3d.new(0, 0, -dir_into_edge)
                          end

      face_drill_normal = case axis
                          when :x then Geom::Vector3d.new(dir_into_edge, 0, 0)
                          when :y then Geom::Vector3d.new(0, dir_into_edge, 0)
                          when :z then Geom::Vector3d.new(0, 0, dir_into_edge)
                          end

      # Xác định giới hạn tiếp xúc theo trục run_axis
      run_min = [edge_bb.min.send(run_axis), face_bb.min.send(run_axis)].max
      run_max = [edge_bb.max.send(run_axis), face_bb.max.send(run_axis)].min

      count_applied = 0
      log_debug("--- BẮT ĐẦU LIÊN KẾT: axis=#{axis} run=#{run_axis} joint_coord=#{joint_coord} run_min=#{run_min} run_max=#{run_max} flip=#{flip_face}")

      base_pts.each_with_index do |base_pt, b_idx|
        base_run_val = base_pt.send(run_axis)

        # 🎯 XÁC ĐỊNH HƯỚNG CHẠY TIẾN/LÙI CỦA CỤM:
        # Nếu cụm nằm gần đầu cuối (run_max): run_dir = -1 (LÙI VÀO TRONG LÒNG, CHỐNG TRÀO RA BIÊN!)
        # Nếu cụm nằm gần đầu đầu (run_min): run_dir = +1 (TIẾN VÀO TRONG LÒNG VÁN)
        dist_to_min = (base_run_val - run_min).abs
        dist_to_max = (base_run_val - run_max).abs
        run_dir = (dist_to_max < dist_to_min) ? -1 : 1

        log_debug("  [Cụm #{b_idx+1}] base_run=#{base_run_val} run_dir=#{run_dir}")

        # ----------------------------------------------------------------------
        # 1. RẢI CÁC LỖ D (BẦU CAM TRÊN MẶT VÁN EDGE_PANEL)
        # ----------------------------------------------------------------------
        d_holes.each_with_index do |dh, idx|
          step_val = 0.mm
          (0...idx).each { |k| step_val += (n_dists[k] || 32.mm) }
          cur_run = base_run_val + (run_dir * step_val)

          cam_coord_axis = joint_coord + (dir_into_edge * offset_L)
          cam_world_center = case axis
                             when :x
                               if run_axis == :y
                                 Geom::Point3d.new(cam_coord_axis, cur_run, cam_face_coord)
                               else
                                 Geom::Point3d.new(cam_coord_axis, cam_face_coord, cur_run)
                               end
                             when :y
                               if run_axis == :x
                                 Geom::Point3d.new(cur_run, cam_coord_axis, cam_face_coord)
                               else
                                 Geom::Point3d.new(cam_face_coord, cam_coord_axis, cur_run)
                               end
                             when :z
                               if run_axis == :x
                                 Geom::Point3d.new(cur_run, cam_face_coord, cam_coord_axis)
                               else
                                 Geom::Point3d.new(cam_face_coord, cur_run, cam_coord_axis)
                               end
                             end

          dia = (dh['dia'] || 15.0).to_f.mm
          depth = (dh['depth'] || 13.5).to_f.mm
          layer_name = (dh['layer'] && !dh['layer'].empty?) ? dh['layer'] : LAYER_CAM_15

          res = add_circle_to_panel(edge_panel, cam_world_center, cam_face_normal, dia / 2.0, layer_name, depth)
          count_applied += 1 if res
        end

        # ----------------------------------------------------------------------
        # 2. RẢI CÁC LỖ d (KHOAN CẠNH ĐẦU VÁN EDGE_PANEL)
        # ----------------------------------------------------------------------
        edge_holes.each_with_index do |eh, idx|
          step_val = 0.mm
          (0...idx).each { |k| step_val += (n_dists[k] || 32.mm) }
          cur_run = base_run_val + (run_dir * step_val)

          edge_world_center = case axis
                              when :x
                                if run_axis == :y
                                  Geom::Point3d.new(joint_coord, cur_run, mid_thick)
                                else
                                  Geom::Point3d.new(joint_coord, mid_thick, cur_run)
                                end
                              when :y
                                if run_axis == :x
                                  Geom::Point3d.new(cur_run, joint_coord, mid_thick)
                                else
                                  Geom::Point3d.new(mid_thick, joint_coord, cur_run)
                                end
                              when :z
                                if run_axis == :x
                                  Geom::Point3d.new(cur_run, mid_thick, joint_coord)
                                else
                                  Geom::Point3d.new(mid_thick, cur_run, joint_coord)
                                end
                              end

          dia = (eh['dia'] || 8.0).to_f.mm
          depth = (eh['depth'] || 34.0).to_f.mm
          layer_name = (eh['layer'] && !eh['layer'].empty?) ? eh['layer'] : LAYER_DOWEL_8

          res = add_circle_to_panel(edge_panel, edge_world_center, edge_drill_normal, dia / 2.0, layer_name, depth)
          count_applied += 1 if res
        end

        # ----------------------------------------------------------------------
        # 3. RẢI CÁC LỖ Dside (KHOAN MẶT VÁCH FACE_PANEL ĐỐI DIỆN)
        # ----------------------------------------------------------------------
        side_holes.each_with_index do |sh, idx|
          step_val = 0.mm
          (0...idx).each { |k| step_val += (n_dists[k] || 32.mm) }
          cur_run = base_run_val + (run_dir * step_val)

          side_world_center = case axis
                              when :x
                                if run_axis == :y
                                  Geom::Point3d.new(joint_coord, cur_run, mid_thick)
                                else
                                  Geom::Point3d.new(joint_coord, mid_thick, cur_run)
                                end
                              when :y
                                if run_axis == :x
                                  Geom::Point3d.new(cur_run, joint_coord, mid_thick)
                                else
                                  Geom::Point3d.new(mid_thick, joint_coord, cur_run)
                                end
                              when :z
                                if run_axis == :x
                                  Geom::Point3d.new(cur_run, mid_thick, joint_coord)
                                else
                                  Geom::Point3d.new(mid_thick, cur_run, joint_coord)
                                end
                              end

          dia = (sh['dia'] || 5.0).to_f.mm
          depth = (sh['depth'] || 12.0).to_f.mm
          layer_name = (sh['layer'] && !sh['layer'].empty?) ? sh['layer'] : LAYER_PIN_5

          res = add_circle_to_panel(face_panel, side_world_center, face_drill_normal, dia / 2.0, layer_name, depth)
          count_applied += 1 if res
        end
      end

      count_applied
    end

    # ==========================================================================
    # 🎯 4. THUẬT TOÁN QUÉT TẤM VÁN & TỰ ĐỘNG KHOAN HÀNG LOẠT (TỪ DIALOG STUDIO)
    # ==========================================================================
    def self.apply_cam_locks(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Tủ Áo hoặc các Tấm Ván trong SketchUp để khoan liên kết!' }
      end

      preset = get_active_preset(params)
      preset_name = preset['name'] || "Cam Chốt Tiêu Chuẩn"

      model.start_operation("Chill AI: Khoan Liên Kết #{preset_name}", true)
      ensure_layers(model)

      panels_raw = collect_panels(selection)
      if panels_raw.empty?
        model.abort_operation
        return { status: 'warning', message: 'Không tìm thấy chi tiết tấm ván phù hợp trong vùng chọn.' }
      end

      analyzed = panels_raw.map do |p|
        info = analyze_panel_orientation(p)
        p.merge(info)
      end

      verticals   = analyzed.select { |p| p[:type] == :vertical }
      horizontals = analyzed.select { |p| p[:type] == :horizontal }

      total_applied = 0
      tol = 12.mm

      horizontals.each do |horiz|
        h_bb = horiz[:bounds_world]
        h_center_z = (h_bb.min.z + h_bb.max.z) / 2.0

        verticals.each do |vert|
          v_bb = vert[:bounds_world]

          touch_left  = (h_bb.min.x - v_bb.max.x).abs <= tol || (h_bb.min.x >= v_bb.min.x - tol && h_bb.min.x <= v_bb.max.x + tol)
          touch_right = (h_bb.max.x - v_bb.min.x).abs <= tol || (h_bb.max.x >= v_bb.min.x - tol && h_bb.max.x <= v_bb.max.x + tol)

          if touch_left || touch_right
            overlap_y = [h_bb.max.y, v_bb.max.y].min - [h_bb.min.y, v_bb.min.y].max
            if overlap_y > 100.mm && h_center_z >= (v_bb.min.z - tol) && h_center_z <= (v_bb.max.z + tol)
              contact_y_min = [h_bb.min.y, v_bb.min.y].max
              contact_y_max = [h_bb.max.y, v_bb.max.y].min
              contact_len = contact_y_max - contact_y_min

              joint_x = touch_left ? [h_bb.min.x, v_bb.max.x].max : [h_bb.max.x, v_bb.min.x].min

              offset_L = (preset['L'] || 34.0).to_f.mm
              offset_C = (preset['C'] || 34.0).to_f.mm

              base_pts = []
              base_pts << Geom::Point3d.new(joint_x, contact_y_min + offset_L, h_center_z)
              base_pts << Geom::Point3d.new(joint_x, contact_y_max - offset_C, h_center_z)
              if contact_len > 480.mm
                base_pts << Geom::Point3d.new(joint_x, contact_y_min + contact_len / 2.0, h_center_z)
              end

              cnt = apply_joint_pair(horiz, vert, :x, :y, joint_x, base_pts, preset, false)
              total_applied += cnt
            end
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_applied} lỗ liên kết [#{preset_name}] dính trực tiếp trên bề mặt cả 2 tấm ván theo chuẩn ABF!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onFittingsApplied) window.onFittingsApplied(#{ { total: total_applied, preset: preset_name, message: msg }.to_json });")
      end

      { status: 'success', total: total_applied, preset: preset_name, message: msg }
    rescue => e
      model.abort_operation rescue nil
      err_msg = "Lỗi khi tạo lỗ liên kết: #{e.message}"
      puts "[Chill AI FittingEngine Error] #{err_msg}\n#{e.backtrace.first(3).join("\n")}"
      UI.messagebox(err_msg)
      { status: 'error', message: err_msg }
    end

    # ==========================================================================
    # 🚪 5. THUẬT TOÁN ĐỤC LỖ BẢN LỀ GIẢM CHẤN CHÉN 35MM (DÍNH TRÊN CÁNH TỦ)
    # ==========================================================================
    def self.apply_hinges(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Cánh Tủ để đục lỗ chén bản lề 35mm!' }
      end

      model.start_operation("Chill AI: Khoan Bản Lề 35mm", true)
      ensure_layers(model)

      total_hinges = 0

      selection.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        panel_info = { entity: entity, parent: nil }
        bb = entity.bounds
        h = (bb.max.z - bb.min.z).to_m * 1000.0
        w = (bb.max.x - bb.min.x).to_m * 1000.0

        if h > 400.0
          count = if h <= 900.0 then 2
                  elsif h <= 1600.0 then 3
                  elsif h <= 2000.0 then 4
                  else 5
                  end

          margin_top = 100.mm
          margin_bottom = 100.mm

          z_positions = [bb.min.z + margin_bottom, bb.max.z - margin_top]
          if count >= 3
            z_positions << (bb.min.z + (bb.max.z - bb.min.z) / 2.0)
          end
          if count >= 4
            gap = (bb.max.z - bb.min.z - margin_top - margin_bottom) / (count - 1)
            z_positions = (0...count).map { |i| bb.min.z + margin_bottom + (i * gap) }
          end

          back_face_y = bb.min.y
          hinge_edge_x = bb.min.x + 22.5.mm
          normal = Geom::Vector3d.new(0, 1, 0)

          z_positions.each do |z_pos|
            cup_center = Geom::Point3d.new(hinge_edge_x, back_face_y, z_pos)
            add_circle_to_panel(panel_info, cup_center, normal, 17.5.mm, LAYER_HINGE_35, 11.5.mm)

            [-22.5.mm, 22.5.mm].each do |z_offset|
              screw_center = Geom::Point3d.new(hinge_edge_x + 9.5.mm, back_face_y, z_pos + z_offset)
              add_circle_to_panel(panel_info, screw_center, normal, 1.5.mm, LAYER_HINGE_BASE_5, 10.0.mm)
            end

            total_hinges += 1
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_hinges} chén bản lề 35mm dính trực tiếp trên mặt cánh tủ chuẩn Hafele/Blum!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onHingesApplied) window.onHingesApplied(#{ { hinges: total_hinges, message: msg }.to_json });")
      end

      { status: 'success', hinges: total_hinges, message: msg }
    rescue => e
      model.abort_operation rescue nil
      err_msg = "Lỗi khi tạo bản lề: #{e.message}"
      puts "[Chill AI FittingEngine Error] #{err_msg}"
      UI.messagebox(err_msg)
      { status: 'error', message: err_msg }
    end

    # ==========================================================================
    # 🧹 6. XÓA CÁC LỖ KHOAN PHỤ KIỆN (DỌN SẠCH CẢ KHỐI CŨ LẪN CIRCLE TRÊN MẶT VÁN)
    # ==========================================================================
    def self.clear_fittings(dialog = nil)
      model = Sketchup.active_model
      return unless model

      model.start_operation("Chill AI: Xóa Phụ Kiện Lỗ Khoan", true)
      deleted_groups = 0
      deleted_circles = 0

      model.active_entities.grep(Sketchup::Group).each do |g|
        if g.name =~ /^Chill_AI_Fittings_/i
          g.erase! rescue nil
          deleted_groups += 1
        end
      end

      drill_layer_names = [LAYER_CAM_15, LAYER_DOWEL_8, LAYER_PIN_5, LAYER_HINGE_35, LAYER_HINGE_BASE_5]
      
      clean_panel_entities = lambda do |entities|
        to_erase = []
        entities.each do |item|
          if item.is_a?(Sketchup::Edge)
            c = item.curve
            if c && (c.get_attribute('chill_ai_drill', 'diameter') || (item.layer && drill_layer_names.include?(item.layer.name)))
              to_erase << item
            end
          elsif item.is_a?(Sketchup::Face)
            if item.layer && drill_layer_names.include?(item.layer.name)
              to_erase << item
            end
          end
        end
        to_erase.uniq.each do |e|
          e.erase! rescue nil
          deleted_circles += 1
        end
      end

      model.definitions.each do |defn|
        clean_panel_entities.call(defn.entities)
      end
      clean_panel_entities.call(model.entities)

      model.commit_operation

      msg = "Đã dọn sạch #{deleted_circles} lỗ khoan và #{deleted_groups} cụm phụ kiện cũ để tối ưu tốc độ 3D!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onFittingsCleared) window.onFittingsCleared(#{ { deleted: deleted_circles + deleted_groups }.to_json });")
      end
      { status: 'success', deleted: deleted_circles + deleted_groups }
    end

    # Tương thích ngược: Hàm vẽ khối trụ cũ
    def self.create_cylinder_hole(entities, center, normal, radius, depth, layer, label)
      group = entities.add_group
      group.name = label
      group.layer = layer if layer
      edges = group.entities.add_circle(center, normal, radius, 24)
      face = group.entities.add_face(edges)
      if face
        face.reverse! if face.normal.dot(normal) > 0
        face.pushpull(-depth) rescue nil
      end
      group.set_attribute('chill_ai_drill', 'diameter', radius * 2.0.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'depth', depth.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'type', label)
      group
    rescue => _e
      nil
    end
  end
end
