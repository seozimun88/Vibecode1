# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - CAM & G-Code CNC Exporter
# Tự động bóc tách tấm 2D (Nesting), xuất DXF cho Aspire và trải phẳng trên SketchUp.
# G-code ISO chỉ là mẫu máy CNC chung: luôn chạy mô phỏng/air-cut trước khi chạy máy thật.
# ==============================================================================

module ChillAIInterior
  module CamGCodeExporter
    SHEET_W = 1220.0 # Chiều rộng khổ ván công nghiệp tiêu chuẩn (mm)
    SHEET_H = 2440.0 # Chiều dài khổ ván công nghiệp tiêu chuẩn (mm)
    BORDER_MARGIN = 10.0 # Chừa lề mép ván (mm)
    BIT_KERF = 6.0       # Đường kính dao mặc định (mm)

    DEFAULT_CONFIG = {
      sheet_w: SHEET_W,
      sheet_h: SHEET_H,
      edge_margin: BORDER_MARGIN,
      tool_diameter: BIT_KERF,
      part_gap: 4.0,
      cut_feed: 2400.0,
      plunge_feed: 700.0,
      spindle_speed: 18000,
      safe_z: 15.0,
      pass_depth: 6.0,
      overcut: 0.5,
      tab_height: 3.0,
      use_tabs: true,
      allow_rotation: true,
      pause_between_sheets: true
    }.freeze

    class CamValidationError < StandardError; end

    def self.process(params)
      config = cam_config(params)
      # 1. Thu thập danh sách các chi tiết tấm phẳng từ thông số hoặc mô hình được chọn trong SU
      parts = extract_parts_from_selection_or_params(params)
      validate_parts!(parts)

      # 2. Thuật toán xếp ván tối ưu 2D (Nesting Algorithm)
      nested_data = perform_nesting(parts, config)

      # 3. Tạo mã lệnh G-Code ISO mẫu. Aspire nên nhận DXF để chỉnh vector/đường dao.
      gcode_str = generate_iso_gcode(nested_data, config)

      # 4. Tạo DXF AutoCAD R12 để import vectors vào Vectric Aspire.
      dxf_str = generate_dxf(nested_data, config)

      {
        "status" => "success",
        "sheet_w" => config[:sheet_w],
        "sheet_h" => config[:sheet_h],
        "total_parts" => parts.length,
        "sheets" => nested_data[:sheets],
        "material_groups" => nested_data[:material_groups],
        "utilization" => nested_data[:utilization],
        "cut_length_m" => nested_data[:total_perimeter_m],
        "estimated_time_min" => nested_data[:estimated_time_min],
        "gcode" => gcode_str,
        "dxf" => dxf_str,
        "cam_config" => config,
        "warnings" => [
          "Để chỉnh trong Aspire: import file DXF, chọn layer CNC_CUT_OUTLINE rồi gán Toolpath.",
          "G-code ISO là mẫu chung; hãy kiểm tra post-processor, gốc phôi, chiều Z và chạy air-cut trước khi gia công."
        ]
      }
    end

    # Xuất DXF một chạm từ các Group/Component đang chọn, tương tự luồng ABF.
    def self.export_selected_dxf
      model = Sketchup.active_model
      return { 'status' => 'error', 'message' => 'Không tìm thấy không gian làm việc SketchUp!' } unless model

      parts = []
      if model.selection && model.selection.count > 0
        model.selection.each { |entity| collect_sub_parts(entity, parts) }
      end

      # Nếu chưa chọn đối tượng, tự động quét tìm khối nội thất trong mô hình (trừ group Nesting phẳng trên sàn)
      if parts.empty? && model.active_entities
        model.active_entities.each do |ent|
          next if ent.name.to_s.start_with?("CHILL_AI_NESTING")
          collect_sub_parts(ent, parts)
        end
      end

      # Nếu vẫn trống, bóc tách từ tham số mặc định
      if parts.empty?
        parts = extract_parts({})
      end

      validate_parts!(parts)
      config = DEFAULT_CONFIG.dup
      nested_data = perform_nesting(parts, config)
      dxf = generate_dxf(nested_data, config)
      default_name = "CNC_ASPIRE_NESTING_#{Time.now.strftime('%d%m_%H%M%S')}.dxf"
      path = UI.savepanel('Lưu file DXF 2D cho Vectric Aspire', '', default_name)
      return { 'status' => 'cancelled' } unless path

      File.open(path, 'w:UTF-8') { |file| file.write(dxf) }
      {
        'status' => 'success', 'path' => path,
        'total_parts' => parts.length, 'total_sheets' => nested_data[:sheets].length
      }
    rescue CamValidationError => error
      UI.messagebox("Không thể xuất DXF: #{error.message}")
      { 'status' => 'error', 'message' => error.message }
    rescue => error
      UI.messagebox("Lỗi xuất DXF: #{error.message}")
      puts "[Chill AI DXF Error]: #{error.message}\n#{error.backtrace}"
      { 'status' => 'error', 'message' => error.message }
    end

    def self.cam_config(params)
      raw = params.is_a?(Hash) && params['cam'].is_a?(Hash) ? params['cam'] : {}
      config = DEFAULT_CONFIG.dup
      config.each_key do |key|
        value = raw[key.to_s]
        value = params[key.to_s] if value.nil? && params.is_a?(Hash)
        next if value.nil? || value == ''
        config[key] = case config[key]
                      when TrueClass, FalseClass then value == true || value.to_s.downcase == 'true'
                      when Integer then value.to_i
                      else value.to_f
                      end
      end

      raise CamValidationError, 'Khổ ván phải lớn hơn 100mm.' if config[:sheet_w] <= 100 || config[:sheet_h] <= 100
      raise CamValidationError, 'Đường kính dao phải nằm trong khoảng 1–50mm.' unless config[:tool_diameter].between?(1.0, 50.0)
      raise CamValidationError, 'Lề biên, khe hở và chiều sâu mỗi lớp không được âm.' if [config[:edge_margin], config[:part_gap], config[:pass_depth], config[:overcut]].any? { |v| v < 0 }
      raise CamValidationError, 'Chiều sâu mỗi lớp phải lớn hơn 0mm.' if config[:pass_depth] <= 0
      config
    end

    def self.validate_parts!(parts)
      raise CamValidationError, 'Không tìm thấy tấm ván nào để bóc tách.' if parts.empty?
      parts.each do |part|
        part[:w] = [part[:w].to_f, 50.0].max
        part[:h] = [part[:h].to_f, 50.0].max
        part[:t] = [part[:t].to_f, 5.0].max
        part[:name] = "Chi tiết ván #{parts.index(part) + 1}" if part[:name].to_s.strip.empty?
      end
    end

    # --- 1. Sinh danh sách chi tiết: Tự động bóc tách từ vùng chọn SU hoặc Params ---
    def self.extract_parts_from_selection_or_params(params)
      model = Sketchup.active_model
      parts = []

      # 1. Ưu tiên bóc tách từ các Group/Component đang được chọn trong SketchUp
      if model && model.selection && model.selection.count > 0
        model.selection.each do |ent|
          collect_sub_parts(ent, parts)
        end
      end

      # 2. Nếu vùng chọn trống, tự động quét tìm các khối nội thất trong không gian vẽ
      if parts.empty? && model && model.active_entities
        model.active_entities.each do |ent|
          next if ent.name.to_s.start_with?("CHILL_AI_NESTING")
          collect_sub_parts(ent, parts)
        end
      end

      # 3. Nếu vẫn hoàn toàn trống -> Lấy từ params tham số mô hình
      if parts.empty?
        parts = extract_parts(params)
      end

      parts
    end

    # Hàm đệ quy quét các tấm ván chi tiết
    def self.collect_sub_parts(entity, parts_list)
      return unless entity && entity.valid?

      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        # Kiểm tra xem có group con bên trong không
        sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        real_child_containers = sub_ents.select do |e|
          (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !(e.name =~ /Chill_AI_Fittings/i)
        end
        has_child_containers = !real_child_containers.empty?

        if has_child_containers
          # Là khối cha/khối tổng -> Đi sâu vào trong
          real_child_containers.each { |child| collect_sub_parts(child, parts_list) }
        else
          # Là chi tiết lá (Leaf Panel)
          bb = entity.bounds
          dim_x = bb.width.to_mm.round(1)
          dim_y = bb.height.to_mm.round(1)
          dim_z = bb.depth.to_mm.round(1)
          dims = [dim_x, dim_y, dim_z].sort
          t = dims[0]
          w = dims[1]
          l = dims[2]

          # Nếu thỏa mãn tỷ lệ tấm ván mộc (độ dày <= 45mm và chiều dài, rộng >= 40mm)
          if t > 0 && t <= 45.0 && l >= 40.0 && w >= 40.0
            name = entity.name.to_s.strip
            if name.empty? && entity.respond_to?(:definition)
              name = entity.definition.name.to_s.strip
            end
            name = "Tấm ván #{parts_list.length + 1}" if name.empty?
            parts_list << { name: name, w: l, h: w, t: t, color: "#2563eb" }
          end
        end
      end
    end

    # Sinh danh sách chi tiết tấm phôi mẫu từ tham số
    def self.extract_parts(params)
      type = (params['type'] || params['model_type'] || 'desk').to_s.downcase
      l = (params['length'] || params['dim_x'] || 1200).to_f
      w = (params['width']  || params['dim_y'] || 600).to_f
      h = (params['height'] || params['dim_z'] || 750).to_f
      t = (params['thickness'] || 17.5).to_f

      # BẢO VỆ CHẶNG 1: Chuẩn hóa kích thước không bao giờ âm hoặc nhỏ hơn giới hạn vật lý
      t = 17.5 if t <= 0.0 || t > 50.0
      l = 1200.0 if l <= 50.0
      w = 600.0 if w <= 50.0

      # Nếu chiều cao h quá bé (do người dùng click 1 tấm ván đơn lẻ hoặc khối nằm sàn h=18mm)
      if type == 'panel' || (h <= 50.0 && l > 100.0 && w > 100.0)
        return [
          { name: params['name'] || "Tấm ván gia công", w: [l, w].max, h: [l, w].min, t: t, color: "#d97706" }
        ]
      end

      h = 750.0 if h <= 100.0

      parts = []
      case type
      when 'desk', 'table'
        parts << { name: "Mặt bàn chính", w: l, h: w, t: t, color: "#d97706" }
        parts << { name: "Yếm bàn dài 1", w: [l - 100, 100.0].max, h: 100, t: t, color: "#b45309" }
        parts << { name: "Yếm bàn dài 2", w: [l - 100, 100.0].max, h: 100, t: t, color: "#b45309" }
        parts << { name: "Yếm hông trái", w: [w - 100, 100.0].max, h: 100, t: t, color: "#92400e" }
        parts << { name: "Yếm hông phải", w: [w - 100, 100.0].max, h: 100, t: t, color: "#92400e" }
        if (params['drawers'] || 0).to_i > 0
          dr_num = params['drawers'].to_i
          parts << { name: "Hông hộc tủ trái", w: [w - 50, 100.0].max, h: 420, t: t, color: "#78350f" }
          parts << { name: "Hông hộc tủ phải", w: [w - 50, 100.0].max, h: 420, t: t, color: "#78350f" }
          parts << { name: "Đáy hộc tủ", w: 380, h: [w - 50, 100.0].max, t: t, color: "#78350f" }
          dr_num.times do |i|
            parts << { name: "Mặt ngăn kéo #{i+1}", w: 370, h: [(400.0 / dr_num).round - 5, 50.0].max, t: t, color: "#f59e0b" }
          end
        end
      when 'wardrobe', 'cabinet', 'kitchen_cabinet'
        h_safe = [h, 600.0].max
        l_safe = [l, 400.0].max
        w_safe = [w, 300.0].max
        parts << { name: "Hông tủ trái", w: h_safe, h: w_safe, t: t, color: "#1e3a8a" }
        parts << { name: "Hông tủ phải", w: h_safe, h: w_safe, t: t, color: "#1e3a8a" }
        parts << { name: "Đáy tủ", w: [l_safe - 2 * t, 100.0].max, h: w_safe, t: t, color: "#1d4ed8" }
        parts << { name: "Nóc tủ", w: [l_safe - 2 * t, 100.0].max, h: w_safe, t: t, color: "#1d4ed8" }
        parts << { name: "Đợt chia ngang 1", w: [l_safe - 2 * t, 100.0].max, h: [w_safe - 15, 100.0].max, t: t, color: "#2563eb" }
        parts << { name: "Đợt chia ngang 2", w: [l_safe - 2 * t, 100.0].max, h: [w_safe - 15, 100.0].max, t: t, color: "#2563eb" }
        doors = [(params['doors'] || 2).to_i, 1].max
        door_w = [(l_safe - 6) / doors, 100.0].max
        doors.times do |i|
          parts << { name: "Cánh tủ #{i+1}", w: [h_safe - 70, 100.0].max, h: door_w, t: t, color: "#60a5fa" }
        end
      else
        # Kệ / Mẫu chung
        h_safe = [h, 600.0].max
        l_safe = [l, 400.0].max
        w_safe = [w, 300.0].max
        parts << { name: "Tấm mặt đỉnh", w: l_safe, h: w_safe, t: t, color: "#047857" }
        parts << { name: "Tấm đáy", w: l_safe, h: w_safe, t: t, color: "#059669" }
        parts << { name: "Hông trái", w: [h_safe - 2 * t, 100.0].max, h: w_safe, t: t, color: "#10b981" }
        parts << { name: "Hông phải", w: [h_safe - 2 * t, 100.0].max, h: w_safe, t: t, color: "#10b981" }
        parts << { name: "Đợt giữa", w: [l_safe - 2 * t, 100.0].max, h: w_safe, t: t, color: "#34d399" }
      end
      parts
    end

    # --- 2. Thuật toán Xếp ván 2D (Shelf Bin Packing, tách theo độ dày phôi) ---
    def self.perform_nesting(parts, config = DEFAULT_CONFIG)
      # Không thể cắt tấm 5mm và 17.5mm trên cùng một gốc Z. Tách thành nhóm phôi riêng.
      groups = parts.group_by { |part| part[:t].to_f.round(2) }
      all_sheets = []
      material_groups = []

      groups.keys.sort.each do |thickness|
        group_sheets = nest_single_material(groups[thickness], thickness, config, all_sheets.length + 1)
        all_sheets.concat(group_sheets)
        material_groups << { thickness: thickness, sheet_count: group_sheets.length, sheets: group_sheets.map { |sheet| sheet[:id] } }
      end

      total_part_area = parts.reduce(0.0) { |sum, part| sum + (part[:w].to_f * part[:h].to_f) }
      total_sheet_area = all_sheets.length * (config[:sheet_w] * config[:sheet_h])
      utilization = total_sheet_area.zero? ? 0.0 : ((total_part_area / total_sheet_area) * 100.0).round(1)
      total_perimeter_mm = parts.reduce(0.0) { |sum, part| sum + 2.0 * (part[:w].to_f + part[:h].to_f) }

      {
        sheets: all_sheets,
        material_groups: material_groups,
        utilization: utilization,
        total_perimeter_m: (total_perimeter_mm / 1000.0).round(2),
        estimated_time_min: ((total_perimeter_mm / config[:cut_feed]) + (parts.length * 0.35)).round(1)
      }
    end

    def self.nest_single_material(parts, thickness, config, first_sheet_id)
      sorted_parts = parts.sort_by { |part| -[part[:w].to_f, part[:h].to_f].max }
      tool_radius = config[:tool_diameter] / 2.0
      inset = config[:edge_margin] + tool_radius
      max_x = config[:sheet_w] - inset
      max_y = config[:sheet_h] - inset
      spacing = config[:part_gap] + config[:tool_diameter]
      sheets = []
      current_sheet = { id: first_sheet_id, thickness: thickness, items: [], used_area: 0.0 }
      cur_x = inset
      cur_y = inset
      shelf_height = 0.0

      sorted_parts.each do |part|
        orientation = choose_orientation(part, cur_x, cur_y, shelf_height, max_x, max_y, spacing, config)
        unless orientation
          # Nếu hết bề ngang hiện tại, thử xuống hàng mới trước khi dùng thêm khổ ván.
          next_row_y = cur_y + shelf_height + spacing
          orientation = choose_orientation(part, inset, next_row_y, 0.0, max_x, max_y, spacing, config)
          if orientation
            cur_x = inset
            cur_y = next_row_y
            shelf_height = 0.0
          else
            sheets << current_sheet unless current_sheet[:items].empty?
            current_sheet = { id: first_sheet_id + sheets.length, thickness: thickness, items: [], used_area: 0.0 }
            cur_x = inset
            cur_y = inset
            shelf_height = 0.0
            orientation = choose_orientation(part, cur_x, cur_y, shelf_height, max_x, max_y, spacing, config)
          end
          unless orientation
            raise CamValidationError, "Chi tiết '#{part[:name]}' (#{part[:w]} x #{part[:h]}mm) không vừa khổ ván #{config[:sheet_w].to_i} x #{config[:sheet_h].to_i}mm sau khi chừa dao và lề biên."
          end
        end

        if cur_y + orientation[:h] > max_y
          sheets << current_sheet unless current_sheet[:items].empty?
          current_sheet = { id: first_sheet_id + sheets.length, thickness: thickness, items: [], used_area: 0.0 }
          cur_x = inset
          cur_y = inset
          shelf_height = 0.0
          orientation = choose_orientation(part, cur_x, cur_y, shelf_height, max_x, max_y, spacing, config)
        end

        current_sheet[:items] << {
          name: part[:name], x: cur_x.round(2), y: cur_y.round(2),
          w: orientation[:w].round(2), h: orientation[:h].round(2),
          t: thickness, color: part[:color] || '#2563eb', rotated: orientation[:rotated]
        }
        current_sheet[:used_area] += orientation[:w] * orientation[:h]
        cur_x += orientation[:w] + spacing
        shelf_height = [shelf_height, orientation[:h]].max
      end

      sheets << current_sheet unless current_sheet[:items].empty?
      sheets
    end

    def self.choose_orientation(part, cur_x, cur_y, shelf_height, max_x, max_y, spacing, config)
      orientations = [{ w: part[:w].to_f, h: part[:h].to_f, rotated: false }]
      grain_locked = part[:grain].to_s.downcase == 'locked'
      if config[:allow_rotation] && !grain_locked && part[:w].to_f != part[:h].to_f
        orientations << { w: part[:h].to_f, h: part[:w].to_f, rotated: true }
      end

      candidates = orientations.select do |candidate|
        candidate[:w] <= (max_x - cur_x) && candidate[:h] <= (max_y - cur_y)
      end
      candidates.min_by { |candidate| [candidate[:h], candidate[:w]] }
    end

    # --- 3. LỰA CHỌN B: XUẤT RA TRỰC TIẾP TRÊN SKETCHUP NHƯ ONE CLICK LÀM ---
    def self.nest_to_sketchup(params)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      config = cam_config(params)
      parts = extract_parts_from_selection_or_params(params)
      validate_parts!(parts)
      nested_data = perform_nesting(parts, config)

      model.start_operation("Chill AI Nesting ra SketchUp (One Click)", true)
      begin
        bb = model.bounds
        start_x = (bb.valid? && bb.max.x) ? (bb.max.x + 600.mm) : 0
        start_y = 0

        master_group = model.active_entities.add_group
        master_group.name = "CHILL_AI_NESTING_#{Time.now.strftime('%d%m_%H%M%S')}"

        # Tạo vật liệu ván và nhãn dán
        mat_sheet = model.materials["Chill_Sheet_Bed"] || model.materials.add("Chill_Sheet_Bed")
        mat_sheet.color = Sketchup::Color.new(240, 238, 230)

        mat_part = model.materials["Chill_Part_Wood"] || model.materials.add("Chill_Part_Wood")
        mat_part.color = Sketchup::Color.new(210, 175, 130)

        nested_data[:sheets].each_with_index do |sheet, s_idx|
          sheet_offset_x = start_x + (s_idx * (config[:sheet_w] + 300).mm)

          sheet_group = master_group.entities.add_group
          sheet_group.name = "Khổ Ván #{sheet[:id]} (#{config[:sheet_w].to_i}x#{config[:sheet_h].to_i}x#{sheet[:thickness]}mm)"

          # 1. Vẽ khung bao tấm ván phôi
          p1 = [sheet_offset_x, start_y, 0]
          p2 = [sheet_offset_x + config[:sheet_w].mm, start_y, 0]
          p3 = [sheet_offset_x + config[:sheet_w].mm, start_y + config[:sheet_h].mm, 0]
          p4 = [sheet_offset_x, start_y + config[:sheet_h].mm, 0]

          bed_face = sheet_group.entities.add_face([p1, p2, p3, p4])
          bed_face.material = mat_sheet
          bed_face.back_material = mat_sheet

          # Tiêu đề tấm ván trên đỉnh
          title_text = "TẤM #{sheet[:id]}: #{config[:sheet_w].to_i}x#{config[:sheet_h].to_i}x#{sheet[:thickness]}mm (#{sheet[:items].length} CHI TIẾT) - TẬN DỤNG: #{nested_data[:utilization]}%"
          t_grp = sheet_group.entities.add_group
          t_grp.entities.add_3d_text(title_text, TextAlignLeft, "Arial", true, false, 35.mm, 0.0, 0.5.mm, true, 0)
          t_grp.transform!(Geom::Transformation.translation([sheet_offset_x, start_y + config[:sheet_h].mm + 25.mm, 0]))

          # 2. Xếp từng chi tiết tấm ván phẳng vào vị trí
          sheet[:items].each do |item|
            ix = sheet_offset_x + item[:x].mm
            iy = start_y + item[:y].mm
            iw = item[:w].mm
            ih = item[:h].mm
            it = (item[:t] || 17.5).mm

            part_grp = sheet_group.entities.add_group
            part_grp.name = item[:name]

            f_pts = [
              [ix, iy, 0.2.mm],
              [ix + iw, iy, 0.2.mm],
              [ix + iw, iy + ih, 0.2.mm],
              [ix, iy + ih, 0.2.mm]
            ]
            part_face = part_grp.entities.add_face(f_pts)
            part_face.pushpull(it)
            part_grp.material = mat_part

            # 3. Ghi nhãn tên, kích thước, thớ gỗ và chỉ dán cạnh trực tiếp trên mặt ván (Chuẩn One Click Cabinet)
            xoay = item[:rotated] ? ' • XOAY 90°' : ''
            label_text = "#{item[:name]}\n#{item[:w].to_i} x #{item[:h].to_i} x #{item[:t].to_i}mm#{xoay}\n[↕ Vân Dọc • Nẹp: 2D 1R]"
            lbl_grp = part_grp.entities.add_group
            lbl_grp.entities.add_3d_text(label_text, TextAlignLeft, "Arial", false, false, 22.mm, 0.0, 0.5.mm, true, 0)
            lbl_grp.transform!(Geom::Transformation.translation([ix + 12.mm, iy + ih - 60.mm, it + 0.5.mm]))
          end
        end

        model.commit_operation

        # Zoom camera đến khu vực xếp ván để thợ mộc ngắm và kiểm tra
        if model.active_view
          model.selection.clear
          model.selection.add(master_group)
          model.active_view.zoom(master_group)
        end

        {
          "status" => "success",
          "message" => "Đã trải phẳng thành công #{nested_data[:sheets].length} khổ ván lên mặt bàn SketchUp!",
          "total_sheets" => nested_data[:sheets].length,
          "total_parts" => parts.length,
          "utilization" => nested_data[:utilization],
          "cut_length_m" => nested_data[:total_perimeter_m],
          "estimated_time_min" => nested_data[:estimated_time_min]
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Nesting SU Error]: #{e.message}\n#{e.backtrace}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 4. LỰA CHỌN A: G-CODE ISO MẪU (phải xác nhận post-processor của máy) ---
    def self.generate_iso_gcode(nested_data, config)
      lines = []
      lines << '( ========================================================== )'
      lines << '( CHILL AI INTERIOR - ISO G-CODE TEMPLATE )'
      lines << '( REVIEW POST-PROCESSOR, ORIGIN, Z ZERO AND AIR-CUT FIRST )'
      lines << "( SHEET: #{config[:sheet_w].to_i} x #{config[:sheet_h].to_i}mm | TOOL: D#{config[:tool_diameter]} )"
      lines << "( SHEETS: #{nested_data[:sheets].length} | UTILIZATION: #{nested_data[:utilization]}% )"
      lines << '( ========================================================== )'
      lines << 'G90 G21 G17 G54'
      lines << "G00 Z#{gcode_number(config[:safe_z])}"
      lines << "M03 S#{config[:spindle_speed]}"
      lines << 'G04 P2'

      nested_data[:sheets].each_with_index do |sheet, sheet_index|
        if sheet_index.positive? && config[:pause_between_sheets]
          lines << 'M00 (THAY PHOI, KIEM TRA DO DAY VA DAT LAI GOC Z)'
        end
        lines << "( SHEET #{sheet[:id]} | STOCK THICKNESS #{gcode_number(sheet[:thickness])}mm | #{sheet[:items].length} PARTS )"
        sheet[:items].each_with_index do |item, item_index|
          lines << "( PART #{item_index + 1}: #{gcode_comment(item[:name])} - #{item[:w]}x#{item[:h]}mm )"
          append_profile_cut(lines, item, config)
        end
      end

      lines << 'M05'
      lines << "G00 Z#{gcode_number([config[:safe_z], 30.0].max)}"
      lines << 'G00 X0 Y0'
      lines << 'M30'
      lines.join("\n")
    end

    def self.append_profile_cut(lines, item, config)
      radius = config[:tool_diameter] / 2.0
      x1 = item[:x] - radius
      y1 = item[:y] - radius
      x2 = item[:x] + item[:w] + radius
      y2 = item[:y] + item[:h] + radius
      cut_depth = item[:t].to_f + config[:overcut]
      tab_height = [[config[:tab_height], item[:t].to_f - 0.5].min, 0.0].max
      use_tabs = config[:use_tabs] && tab_height.positive?
      tab_depth = item[:t].to_f - tab_height
      normal_depth = use_tabs ? [cut_depth - tab_height, 0.0].max : cut_depth

      lines << "G00 X#{gcode_number(x1)} Y#{gcode_number(y1)}"
      depth = 0.0
      while depth < normal_depth
        depth = [depth + config[:pass_depth], normal_depth].min
        lines << "G01 Z-#{gcode_number(depth)} F#{gcode_number(config[:plunge_feed])}"
        append_rectangle(lines, x1, y1, x2, y2, config[:cut_feed])
      end

      if use_tabs && cut_depth > normal_depth
        lines << "G01 Z-#{gcode_number(cut_depth)} F#{gcode_number(config[:plunge_feed])}"
        append_rectangle_with_tabs(lines, x1, y1, x2, y2, cut_depth, tab_depth, config[:cut_feed], config[:plunge_feed])
      end
      lines << "G00 Z#{gcode_number(config[:safe_z])}"
    end

    def self.append_rectangle(lines, x1, y1, x2, y2, feed)
      lines << "G01 X#{gcode_number(x2)} Y#{gcode_number(y1)} F#{gcode_number(feed)}"
      lines << "G01 X#{gcode_number(x2)} Y#{gcode_number(y2)}"
      lines << "G01 X#{gcode_number(x1)} Y#{gcode_number(y2)}"
      lines << "G01 X#{gcode_number(x1)} Y#{gcode_number(y1)}"
    end

    # Giữ lại một cầu nhỏ ở giữa mỗi cạnh để chi tiết không văng khi cắt xuyên.
    def self.append_rectangle_with_tabs(lines, x1, y1, x2, y2, cut_depth, tab_depth, feed, plunge_feed)
      append_side_with_tab(lines, [x1, y1], [x2, y1], cut_depth, tab_depth, feed, plunge_feed)
      append_side_with_tab(lines, [x2, y1], [x2, y2], cut_depth, tab_depth, feed, plunge_feed)
      append_side_with_tab(lines, [x2, y2], [x1, y2], cut_depth, tab_depth, feed, plunge_feed)
      append_side_with_tab(lines, [x1, y2], [x1, y1], cut_depth, tab_depth, feed, plunge_feed)
    end

    def self.append_side_with_tab(lines, start_point, end_point, cut_depth, tab_depth, feed, plunge_feed)
      dx = end_point[0] - start_point[0]
      dy = end_point[1] - start_point[1]
      length = Math.sqrt(dx * dx + dy * dy)
      return if length <= 0
      tab_width = [20.0, length * 0.18].min
      before = (length - tab_width) / 2.0
      tab_start = [start_point[0] + dx * before / length, start_point[1] + dy * before / length]
      tab_end = [start_point[0] + dx * (before + tab_width) / length, start_point[1] + dy * (before + tab_width) / length]
      lines << "G01 X#{gcode_number(tab_start[0])} Y#{gcode_number(tab_start[1])} F#{gcode_number(feed)}"
      lines << "G01 Z-#{gcode_number(tab_depth)} F#{gcode_number(plunge_feed)}"
      lines << "G01 X#{gcode_number(tab_end[0])} Y#{gcode_number(tab_end[1])} F#{gcode_number(feed)}"
      lines << "G01 Z-#{gcode_number(cut_depth)} F#{gcode_number(plunge_feed)}"
      lines << "G01 X#{gcode_number(end_point[0])} Y#{gcode_number(end_point[1])} F#{gcode_number(feed)}"
    end

    def self.gcode_number(value)
      format('%.3f', value.to_f)
    end

    def self.gcode_comment(value)
      value.to_s.encode('ASCII', invalid: :replace, undef: :replace, replace: '').gsub(/[()\r\n]/, ' ').strip
    end

    # --- 5. LỰA CHỌN A: XUẤT DXF VECTOR ĐỂ IMPORT VÀO VECTRIC ASPIRE ---
    def self.generate_dxf(nested_data, config)
      dxf = []
      dxf << "0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1009\n0\nENDSEC"
      dxf << "0\nSECTION\n2\nTABLES"
      dxf << "0\nTABLE\n2\nLAYER\n70\n3"
      # Layer 1: SHEET_BORDER (Màu Đỏ)
      dxf << "0\nLAYER\n2\nSHEET_BORDER\n70\n0\n62\n1\n6\nCONTINUOUS"
      # Layer 2: CNC_CUT_OUTLINE (Màu Xanh Lá - Aspire Profile Cut)
      dxf << "0\nLAYER\n2\nCNC_CUT_OUTLINE\n70\n0\n62\n3\n6\nCONTINUOUS"
      # Layer 3: LABELS (Màu Vàng - Tên chi tiết)
      dxf << "0\nLAYER\n2\nLABELS\n70\n0\n62\n2\n6\nCONTINUOUS"
      dxf << "0\nENDTAB\n0\nENDSEC"
      dxf << "0\nSECTION\n2\nENTITIES"

      nested_data[:sheets].each_with_index do |sheet, s_idx|
        offset_x = s_idx * (config[:sheet_w] + 300.0)

        # Viền khổ ván
        dxf_add_polyline(dxf, "SHEET_BORDER", [
          [offset_x, 0.0],
          [offset_x + config[:sheet_w], 0.0],
          [offset_x + config[:sheet_w], config[:sheet_h]],
          [offset_x, config[:sheet_h]]
        ])

        # Từng tấm chi tiết
        sheet[:items].each do |item|
          x1 = offset_x + item[:x]
          y1 = item[:y]
          x2 = offset_x + item[:x] + item[:w]
          y2 = item[:y] + item[:h]

          dxf_add_polyline(dxf, "CNC_CUT_OUTLINE", [
            [x1, y1],
            [x2, y1],
            [x2, y2],
            [x1, y2]
          ])

          # Text nhãn tên chi tiết
          dxf << "0\nTEXT\n8\nLABELS\n10\n#{x1 + 15.0}\n20\n#{y2 - 35.0}\n30\n0.0\n40\n20.0\n1\n#{dxf_text(item[:name])} (#{item[:w].to_i}x#{item[:h].to_i} T#{item[:t]})"
        end

        dxf << "0\nTEXT\n8\nLABELS\n10\n#{offset_x + 15.0}\n20\n#{config[:sheet_h] + 25.0}\n30\n0.0\n40\n25.0\n1\nSHEET #{sheet[:id]} - STOCK T#{sheet[:thickness]}mm"
      end

      dxf << "0\nENDSEC\n0\nEOF"
      dxf.join("\n")
    end

    def self.dxf_add_polyline(dxf, layer, pts)
      dxf << "0\nPOLYLINE\n8\n#{layer}\n66\n1\n70\n1"
      pts.each do |p|
        dxf << "0\nVERTEX\n8\n#{layer}\n10\n#{p[0]}\n20\n#{p[1]}\n30\n0.0"
      end
      dxf << "0\nSEQEND"
    end

    def self.dxf_text(value)
      str = value.to_s.gsub(/[\r\n]/, ' ').gsub(/[<>]/, '')
      # Chuyển đổi tiếng Việt sang không dấu để tương thích 100% với Vectric Aspire / AutoCAD R12
      str.tr(
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ' \
        'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ',
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd' \
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD'
      ).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
    end
  end
end
