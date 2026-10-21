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

    # 1. TỰ ĐỘNG TẠO / LẤY CÁC LAYER KHOAN LỖ CHO MÁY CNC / ASPIRE
    def self.ensure_layers(model)
      layers = {}
      [LAYER_CAM_15, LAYER_DOWEL_8, LAYER_PIN_5, LAYER_HINGE_35, LAYER_HINGE_BASE_5].each do |name|
        layers[name] = model.layers[name] || model.layers.add(name)
      end
      layers
    end

    # 2. BÓC TÁCH TOÀN BỘ CÁC TẤM VÁN TRONG VÙNG CHỌN
    def self.collect_panels(selection)
      panels = []
      selection.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # Nếu đây là tổ hợp tủ cha (Root Cabinet), duyệt các tấm con bên trong
          sub_entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          has_subs = false
          sub_entities.each do |sub|
            if sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
              # Bỏ qua các group lỗ khoan cũ nếu có
              next if sub.name =~ /Chill_AI_Fittings/i
              panels << { entity: sub, parent: entity, transform: entity.transformation * sub.transformation }
              has_subs = true
            end
          end
          # Nếu là tấm ván đơn lẻ
          panels << { entity: entity, parent: nil, transform: entity.transformation } unless has_subs
        end
      end
      panels
    end

    # Phân loại hướng của tấm ván (Đứng - Vertical hay Ngang - Horizontal)
    def self.analyze_panel_orientation(panel_info)
      ent = panel_info[:entity]
      bb = ent.bounds
      # Kích thước theo toạ độ địa phương (mm)
      dx = bb.width.to_m * 1000.0
      dy = bb.height.to_m * 1000.0
      dz = bb.depth.to_m * 1000.0

      # Tìm trục có độ dày mỏng nhất (15mm - 25mm)
      dims = [{ axis: :x, val: dx }, { axis: :y, val: dy }, { axis: :z, val: dz }].sort_by { |d| d[:val] }
      thickness = dims[0][:val]
      length    = dims[2][:val]
      width     = dims[1][:val]
      thin_axis = dims[0][:axis]

      # Phân loại:
      # thin_axis == :x -> Tấm Hồi Đứng (Vách trái, vách phải, vách giữa)
      # thin_axis == :z -> Tấm Ngang (Đáy, Nóc, Đợt tầng)
      # thin_axis == :y -> Tấm Hậu hoặc Cánh Cửa
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
        bounds_world: get_world_bounds(ent, panel_info[:transform])
      }
    end

    def self.get_world_bounds(entity, transform)
      bb = entity.bounds
      pts = [
        Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
        Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
      ].map { |p| p.transform(transform) }
      Geom::BoundingBox.new.add(pts)
    end

    # ==========================================================================
    # 🎯 3. THUẬT TOÁN ĐỤC LỖ LIÊN KẾT CAM CHỐT ĐỘNG THEO PRESET (ABF FITTING MATRIX)
    # ==========================================================================
    def self.apply_cam_locks(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Tủ Áo hoặc các Tấm Ván trong SketchUp để khoan liên kết!' }
      end

      # Nạp Preset cấu hình
      preset = get_active_preset(params)
      preset_name = preset['name'] || "Cam Chốt Tiêu Chuẩn"

      offset_L = (preset['L'] || 34.0).to_f.mm
      offset_C = (preset['C'] || 34.0).to_f.mm

      d_holes    = (preset['D'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      edge_holes = (preset['d'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      side_holes = (preset['Dside'] || []).select { |h| h['active'] && h['dia'].to_f > 0 }
      n_dists    = (preset['n'] || []).map { |item| (item['val'] || 32.0).to_f.mm }

      model.start_operation("Chill AI: Khoan Liên Kết #{preset_name}", true)

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

      total_holes = 0

      fittings_group = model.active_entities.add_group
      fittings_group.name = "Chill_AI_Fittings_#{preset['id'] || 'Custom'}_#{Time.now.strftime('%H%M%S')}"

      horizontals.each do |horiz|
        h_bb = horiz[:bounds_world]
        h_center_z = (h_bb.min.z + h_bb.max.z) / 2.0

        verticals.each do |vert|
          v_bb = vert[:bounds_world]

          touch_left  = (h_bb.min.x - v_bb.max.x).abs < 0.1.m
          touch_right = (h_bb.max.x - v_bb.min.x).abs < 0.1.m

          if touch_left || touch_right
            overlap_y = [h_bb.max.y, v_bb.max.y].min - [h_bb.min.y, v_bb.min.y].max
            if overlap_y > 150.mm && h_center_z >= (v_bb.min.z - 10.mm) && h_center_z <= (v_bb.max.z + 10.mm)
              contact_y_min = [h_bb.min.y, v_bb.min.y].max
              contact_y_max = [h_bb.max.y, v_bb.max.y].min
              contact_len = contact_y_max - contact_y_min

              joint_x = touch_left ? h_bb.min.x : h_bb.max.x
              cam_direction = touch_left ? 1 : -1

              anchor_y_list = []
              anchor_y_list << (contact_y_min + offset_L)
              anchor_y_list << (contact_y_max - offset_C)
              if contact_len > 480.mm
                anchor_y_list << (contact_y_min + contact_len / 2.0)
              end

              anchor_y_list.each do |base_y|
                # 1. RẢI CÁC LỖ D (MẶT VÁN)
                d_holes.each do |dh|
                  d_idx = dh['id'].to_s.sub('D', '').to_i - 1
                  step_y = 0.mm
                  (0...d_idx).each { |k| step_y += (n_dists[k] || 32.mm) }
                  cur_y = (base_y + step_y <= contact_y_max - 10.mm) ? (base_y + step_y) : (base_y - step_y)

                  dia = dh['dia'].to_f.mm
                  depth = dh['depth'].to_f.mm
                  layer_name = (dh['layer'] && !dh['layer'].empty?) ? dh['layer'] : LAYER_CAM_15
                  target_layer = model.layers[layer_name] || model.layers.add(layer_name)

                  cam_cx = joint_x + (cam_direction * offset_L)
                  cam_center = Geom::Point3d.new(cam_cx, cur_y, h_bb.min.z)

                  create_cylinder_hole(
                    fittings_group.entities,
                    cam_center,
                    Geom::Vector3d.new(0, 0, 1),
                    dia / 2.0,
                    depth,
                    target_layer,
                    "#{layer_name}_Dia#{dh['dia']}_D#{depth.to_m*1000}"
                  )
                  total_holes += 1
                end

                # 2. RẢI CÁC LỖ d (CẠNH ĐẦU VÁN)
                edge_holes.each do |eh|
                  d_idx = eh['id'].to_s.sub('d', '').to_i - 1
                  step_y = 0.mm
                  (0...d_idx).each { |k| step_y += (n_dists[k] || 32.mm) }
                  cur_y = (base_y + step_y <= contact_y_max - 10.mm) ? (base_y + step_y) : (base_y - step_y)

                  dia = eh['dia'].to_f.mm
                  depth = eh['depth'].to_f.mm
                  layer_name = (eh['layer'] && !eh['layer'].empty?) ? eh['layer'] : LAYER_DOWEL_8
                  target_layer = model.layers[layer_name] || model.layers.add(layer_name)

                  edge_cx = joint_x + (cam_direction * (dia / 2.0))
                  edge_center = Geom::Point3d.new(edge_cx, cur_y, h_center_z)

                  create_cylinder_hole(
                    fittings_group.entities,
                    edge_center,
                    Geom::Vector3d.new(cam_direction, 0, 0),
                    dia / 2.0,
                    depth,
                    target_layer,
                    "#{layer_name}_Dia#{eh['dia']}_D#{depth.to_m*1000}"
                  )
                  total_holes += 1
                end

                # 3. RẢI CÁC LỖ Dside (MẶT VÁCH HỒI ĐỐI DIỆN)
                side_holes.each do |sh|
                  d_idx = sh['id'].to_s.sub('Dside', '').to_i - 1
                  step_y = 0.mm
                  (0...d_idx).each { |k| step_y += (n_dists[k] || 32.mm) }
                  cur_y = (base_y + step_y <= contact_y_max - 10.mm) ? (base_y + step_y) : (base_y - step_y)

                  dia = sh['dia'].to_f.mm
                  depth = sh['depth'].to_f.mm
                  layer_name = (sh['layer'] && !sh['layer'].empty?) ? sh['layer'] : LAYER_PIN_5
                  target_layer = model.layers[layer_name] || model.layers.add(layer_name)

                  side_center = Geom::Point3d.new(joint_x, cur_y, h_center_z)

                  create_cylinder_hole(
                    fittings_group.entities,
                    side_center,
                    Geom::Vector3d.new(-cam_direction, 0, 0),
                    dia / 2.0,
                    depth,
                    target_layer,
                    "#{layer_name}_Dia#{sh['dia']}_D#{depth.to_m*1000}"
                  )
                  total_holes += 1
                end
              end
            end
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_holes} lỗ liên kết [#{preset_name}] chuẩn xác và gán đúng các Layer CNC!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onFittingsApplied) window.onFittingsApplied(#{ { total: total_holes, preset: preset_name, message: msg }.to_json });")
      end

      { status: 'success', total: total_holes, preset: preset_name, message: msg }
    rescue => e
      model.abort_operation rescue nil
      err_msg = "Lỗi khi tạo lỗ liên kết: #{e.message}"
      puts "[Chill AI FittingEngine Error] #{err_msg}\n#{e.backtrace.first(3).join("\n")}"
      UI.messagebox(err_msg)
      { status: 'error', message: err_msg }
    end

    # ==========================================================================
    # 🚪 4. THUẬT TOÁN ĐỤC LỖ BẢN LỀ GIẢM CHẤN CHÉN 35MM
    # ==========================================================================
    def self.apply_hinges(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Cánh Tủ để đục lỗ chén bản lề 35mm!' }
      end

      model.start_operation("Chill AI: Khoan Bản Lề 35mm", true)
      layers = ensure_layers(model)

      total_hinges = 0
      fittings_group = model.active_entities.add_group
      fittings_group.name = "Chill_AI_Fittings_Hinges_#{Time.now.strftime('%H%M%S')}"

      selection.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        bb = entity.bounds
        h = (bb.max.z - bb.min.z).to_m * 1000.0 # Chiều cao cánh (mm)
        w = (bb.max.x - bb.min.x).to_m * 1000.0 # Chiều rộng cánh (mm)

        # Kiểm tra đây có phải là cánh tủ không (Chiều cao lớn hơn 400mm)
        if h > 400.0
          # Xác định số lượng bản lề theo chiều cao cánh
          count = if h <= 900.0
                    2
                  elsif h <= 1600.0
                    3
                  elsif h <= 2000.0
                    4
                  else
                    5
                  end

          # Tính toán vị trí rải bản lề theo chiều cao Z
          z_positions = []
          margin_top = 100.mm
          margin_bottom = 100.mm

          z_positions << (bb.min.z + margin_bottom) # Bản lề đáy
          z_positions << (bb.max.z - margin_top)    # Bản lề đỉnh

          if count >= 3
            z_positions << (bb.min.z + (bb.max.z - bb.min.z) / 2.0) # Bản lề giữa
          end
          if count >= 4
            gap = (bb.max.z - bb.min.z - margin_top - margin_bottom) / (count - 1)
            z_positions = (0...count).map { |i| bb.min.z + margin_bottom + (i * gap) }
          end

          # Mặt sau cánh tủ (nơi khoét chén bản lề)
          back_face_y = bb.min.y
          # Cạnh bắt bản lề (Mép trái của cánh)
          hinge_edge_x = bb.min.x + 22.5.mm # Tâm chén cách mép đúng 22.5mm (Biên K=5mm)

          z_positions.each do |z_pos|
            cup_center = Geom::Point3d.new(hinge_edge_x, back_face_y, z_pos)

            # 1. CHÉN BẢN LỀ PHI 35MM (Sâu 11.5mm)
            create_cylinder_hole(
              fittings_group.entities,
              cup_center,
              Geom::Vector3d.new(0, 1, 0),
              17.5.mm,  # Bán kính 17.5mm -> Phi 35mm
              11.5.mm,  # Sâu 11.5mm
              layers[LAYER_HINGE_35],
              "Hinge_Cup_35_Depth11.5"
            )

            # 2. HAI LỖ BẮT VÍT TAI BẢN LỀ (Khoảng cách tâm 45mm, cách tâm chén 9.5mm)
            [-22.5.mm, 22.5.mm].each do |z_offset|
              screw_center = Geom::Point3d.new(hinge_edge_x + 9.5.mm, back_face_y, z_pos + z_offset)
              create_cylinder_hole(
                fittings_group.entities,
                screw_center,
                Geom::Vector3d.new(0, 1, 0),
                1.5.mm,   # Mồi vít phi 3mm
                10.0.mm,
                layers[LAYER_HINGE_35],
                "Hinge_Screw_3mm"
              )
            end

            total_hinges += 1
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_hinges} chén bản lề 35mm chuẩn Hafele/Blum!"
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
    # 🧹 5. XÓA CÁC LỖ KHOAN PHỤ KIỆN (KHI CẦN QUAY LẠI 3D SẠCH SẼ)
    # ==========================================================================
    def self.clear_fittings(dialog = nil)
      model = Sketchup.active_model
      return unless model

      model.start_operation("Chill AI: Xóa Phụ Kiện Lỗ Khoan", true)
      deleted = 0
      model.active_entities.grep(Sketchup::Group).each do |g|
        if g.name =~ /^Chill_AI_Fittings_/i
          g.erase! rescue nil
          deleted += 1
        end
      end
      model.commit_operation

      msg = "Đã dọn sạch #{deleted} cụm lỗ khoan phụ kiện để tối ưu tốc độ 3D!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onFittingsCleared) window.onFittingsCleared(#{ { deleted: deleted }.to_json });")
      end
      { status: 'success', deleted: deleted }
    end

    # ==========================================================================
    # HÀM TRỢ GIÚP: VẼ KHỐI TRỤ RỖNG 3D MÔ PHỎNG LỖ KHOAN THỰC TẾ
    # ==========================================================================
    def self.create_cylinder_hole(entities, center, normal, radius, depth, layer, label)
      group = entities.add_group
      group.name = label
      group.layer = layer if layer

      # Tạo vòng tròn đáy
      edges = group.entities.add_circle(center, normal, radius, 24)
      face = group.entities.add_face(edges)

      # Đẩy khối âm xuống theo chiều sâu mũi khoan
      if face
        # Đảo mặt nếu normal ngược chiều
        face.reverse! if face.normal.dot(normal) > 0
        face.pushpull(-depth) rescue nil
      end

      # Gán thuộc tính nhận diện cho CNC Nesting & DXF Exporter
      group.set_attribute('chill_ai_drill', 'diameter', radius * 2.0.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'depth', depth.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'type', label)
      group
    rescue => _e
      nil
    end
  end
end
