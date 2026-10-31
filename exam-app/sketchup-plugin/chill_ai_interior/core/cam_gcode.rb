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
    def self.export_selected_dxf(params = {})
      model = Sketchup.active_model
      return { 'status' => 'error', 'message' => 'Không tìm thấy không gian làm việc SketchUp!' } unless model

      config = cam_config(params)
      parts = extract_parts_from_selection_or_params(params)
      validate_parts!(parts)
      nested_data = perform_nesting(parts, config)
      dxf = generate_dxf(nested_data, config)

      model_name = (params && (params['name'] || params['type'] || params['model_name'])) ? (params['name'] || params['type'] || params['model_name']).to_s.gsub(/\s+/, '_') : 'NESTING'
      default_name = "CNC_ASPIRE_#{model_name}_#{Time.now.strftime('%d%m_%H%M%S')}.dxf"
      
      desktop_dir = ENV['USERPROFILE'] ? File.join(ENV['USERPROFILE'], 'Desktop') : nil
      desktop_dir = Dir.pwd unless desktop_dir && Dir.exist?(desktop_dir)

      path = UI.savepanel('Lưu file DXF 2D cho Vectric Aspire', desktop_dir, default_name)
      return { 'status' => 'cancelled', 'message' => 'Đã hủy lưu file DXF.' } unless path

      path = path.tr('\\', '/')
      path += ".dxf" unless path.downcase.end_with?('.dxf')

      File.open(path, 'w:UTF-8') { |file| file.write(dxf) }
      {
        'status' => 'success',
        'path' => path,
        'total_parts' => parts.length,
        'total_sheets' => nested_data[:sheets].length
      }
    rescue Errno::EACCES => error
      msg = "File DXF đang được mở trong phần mềm khác (AutoCAD hoặc Vectric Aspire)!\nVui lòng đóng file đó lại hoặc chọn tên file khác để lưu."
      UI.messagebox(msg)
      { 'status' => 'error', 'message' => msg }
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
    def self.resolve_to_panel(entity)
      return nil unless entity && entity.valid?

      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        name = entity.name.to_s
        defn_name = entity.respond_to?(:definition) ? entity.definition.name.to_s : ""
        if name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i ||
           defn_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i
          parent_def = entity.parent
          if parent_def.respond_to?(:instances) && parent_def.instances.any?
            return parent_def.instances.first
          end
        end
        return entity
      end

      if entity.is_a?(Sketchup::Face) || entity.is_a?(Sketchup::Edge)
        parent_def = entity.parent
        if parent_def.respond_to?(:instances) && parent_def.instances.any?
          return parent_def.instances.first
        end
      end

      entity
    end

    def self.is_leaf_panel(entity)
      return false unless entity && entity.valid?
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      name = entity.name.to_s.strip
      defn_name = entity.respond_to?(:definition) ? entity.definition.name.to_s.strip : ""

      # Bỏ qua các đối tượng bản vẽ nesting hoặc group kỹ thuật
      return false if name =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i || defn_name =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i
      return false if name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i ||
                      defn_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i

      # 1. Đã có thuộc tính nhận diện tấm ván Chill AI CNC hoặc ABF
      if entity.get_attribute("Chill_AI_CNC", "label_id") || 
         entity.get_attribute("Chill_AI_CNC", "id_number") ||
         entity.get_attribute("Chill_AI_CNC", "part_name") ||
         entity.get_attribute("ABF_EDGE_BANDING", "L1") ||
         entity.get_attribute("CHILL_AI_EDGE_BANDING", "L1")
        return true
      end

      # 2. Kiểm tra hình học: Tấm ván phải chứa ít nhất 1 Face mộc
      sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : (entity.respond_to?(:definition) ? entity.definition.entities : [])
      faces = sub_ents.grep(Sketchup::Face)
      return false if faces.empty?

      # Kích thước chuẩn ván mộc (Dày <= 45mm, Dài >= 40mm, Rộng >= 40mm)
      bb = entity.bounds
      dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
      t = dims[0]
      w = dims[1]
      l = dims[2]

      # Nếu xoay góc trong 3D khiến bounding box trục toàn cục phồng to, kiểm tra thêm definition.bounds
      if t > 45.0 && entity.respond_to?(:definition) && entity.definition
        def_bb = entity.definition.bounds
        def_dims = [def_bb.width.to_mm.round(1), def_bb.height.to_mm.round(1), def_bb.depth.to_mm.round(1)].sort
        if def_dims[0] > 0 && def_dims[0] <= 45.0 && def_dims[2] >= 40.0 && def_dims[1] >= 40.0
          return true
        end
      end

      t > 0 && t <= 45.0 && l >= 40.0 && w >= 40.0
    end

    def self.extract_parts_from_selection_or_params(params)
      model = Sketchup.active_model
      parts = []

      # 1. ƯU TIÊN 1: Vùng chọn trực tiếp trong SketchUp (Selection Mode)
      if model && model.selection && model.selection.count > 0
        valid_selected = model.selection.to_a.reject do |ent|
          ent.name.to_s =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i
        end

        # Nếu người dùng chọn đúng 1 đối tượng duy nhất
        if valid_selected.length == 1
          single_ent = resolve_to_panel(valid_selected.first)
          # Nếu đây là tấm ván đơn mộc (Leaf Panel) -> CHỈ NESTING ĐÚNG 1 TẤM NÀY!
          if is_leaf_panel(single_ent)
            collect_sub_parts(single_ent, parts, params)
            return parts unless parts.empty?
          end
        end

        # Nếu chọn nhiều tấm hoặc chọn cụm -> bóc tách từ các đối tượng được chọn
        valid_selected.each do |ent|
          collect_sub_parts(ent, parts, params)
        end

        # Nếu người dùng chọn chính cụm Nesting trên sàn (đã trải phẳng)
        if parts.empty?
          nesting_groups = model.selection.to_a.select { |ent| ent.name.to_s =~ /^(ABF_NESTING|CHILL_AI_NESTING)/i }
          nesting_groups.each do |ng|
            sub_ents = ng.is_a?(Sketchup::Group) ? ng.entities : (ng.respond_to?(:definition) ? ng.definition.entities : [])
            sub_ents.each do |child|
              next if child.name.to_s =~ /^(Khổ Ván|Sheet|Chill_AI_Label)/i
              collect_sub_parts(child, parts, params)
            end
          end
        end

        return parts unless parts.empty?
      end

      # 2. ƯU TIÊN 2: Tấm ván vừa thao tác dán chỉ gần nhất trong phiên làm việc
      if defined?(EdgeBandingEngine) && EdgeBandingEngine.last_selected_panel
        last_panel = resolve_to_panel(EdgeBandingEngine.last_selected_panel)
        if last_panel && last_panel.valid? && is_leaf_panel(last_panel)
          collect_sub_parts(last_panel, parts, params)
          puts "[Chill AI Nesting] 🎯 Ưu tiên bóc tách tấm vừa dán chỉ gần nhất: #{parts.first[:name]}" rescue nil
          return parts unless parts.empty?
        end
      end

      # 3. ƯU TIÊN 3: Nếu hoàn toàn không chọn gì và không có tấm dán chỉ gần nhất -> Quét toàn bộ mô hình
      if model && model.active_entities
        model.active_entities.each do |ent|
          next if ent.name.to_s =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i
          collect_sub_parts(ent, parts, params)
        end

        return parts unless parts.empty?
      end

      # 4. Fallback thông minh: Nếu chưa có ván trên sàn SketchUp nhưng giao diện đang có thông số mô hình
      if params && (params['length'] || params['dim_x'] || params['parts'] || params['type'] || params['model_type'])
        parts = extract_parts(params)
        return parts unless parts.empty?
      end

      raise CamValidationError, "Không tìm thấy tấm ván mộc nào trong mô hình để xuất DXF! Vui lòng chọn mô hình tủ hoặc dựng hình 3D."
    end

    def self.collect_sub_parts(entity, parts_list, params = nil)
      return unless entity && entity.valid?

      resolved = resolve_to_panel(entity)
      return unless resolved && resolved.valid?
      return if resolved.name.to_s =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i

      if is_leaf_panel(resolved)
        return if parts_list.any? { |p| p[:entity] == resolved }

        bb = resolved.bounds
        dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
        t = dims[0]
        w = dims[1]
        l = dims[2]

        if t > 45.0 && resolved.respond_to?(:definition) && resolved.definition
          def_bb = resolved.definition.bounds
          def_dims = [def_bb.width.to_mm.round(1), def_bb.height.to_mm.round(1), def_bb.depth.to_mm.round(1)].sort
          if def_dims[0] > 0 && def_dims[0] <= 45.0
            t = def_dims[0]
            w = def_dims[1]
            l = def_dims[2]
          end
        end

        raw_name = resolved.name.to_s.strip
        if raw_name.empty? && resolved.respond_to?(:definition)
          raw_name = resolved.definition.name.to_s.strip
        end
        raw_name = "Tấm ván #{parts_list.length + 1}" if raw_name.empty?

        clean_name = defined?(LabelingEngine) ? LabelingEngine.clean_raw_name(raw_name) : raw_name
        clean_name = "Tấm ván #{parts_list.length + 1}" if clean_name.empty? || clean_name =~ /^Group/i

        label_id = resolved.get_attribute("Chill_AI_CNC", "label_id")
        part_name = resolved.get_attribute("Chill_AI_CNC", "part_name")
        grain = resolved.get_attribute("Chill_AI_CNC", "grain") || "length"
        machining_face = resolved.get_attribute("Chill_AI_CNC", "machining_face") || "top"

        raw_mat = resolved.get_attribute("Chill_AI_CNC", "material")
        raw_mat ||= resolved.get_attribute("Chill_AI_Interior", "material")
        if raw_mat.nil? || raw_mat.to_s.strip.empty?
          if resolved.material
            raw_mat = resolved.material.display_name
          elsif resolved.respond_to?(:definition) && resolved.definition && resolved.definition.material
            raw_mat = resolved.definition.material.display_name
          end
        end
        raw_mat ||= (params && (params['material_name'] || params['material'] || params['mat_name']))
        mat_name = format_board_material(raw_mat)

        disp_name = label_id ? "[#{label_id}] #{part_name || clean_name}" : clean_name

        # 🌟 TỰ ĐỘNG TRỪ HAO ĐỘ DÀY CHỈ DÁN CẠNH (EDGE BANDING OFFSET):
        eb_deduct = defined?(EdgeBandingEngine) ? EdgeBandingEngine.calculate_edge_deductions(resolved) : { deduct_l: 0.0, deduct_w: 0.0 }
        deduct_l = eb_deduct[:deduct_l].to_f
        deduct_w = eb_deduct[:deduct_w].to_f

        cutting_l = [(l - deduct_l).round(1), 20.0].max
        cutting_w = [(w - deduct_w).round(1), 20.0].max

        parts_list << {
          name: disp_name,
          original_name: clean_name,
          w: cutting_l,               # Chiều dài cắt phôi (đã bị hụt đi theo cạnh dán chỉ!)
          h: cutting_w,               # Chiều rộng cắt phôi (đã bị hụt đi theo cạnh dán chỉ!)
          design_l: l,                # Chiều dài thiết kế ban đầu
          design_w: w,                # Chiều rộng thiết kế ban đầu
          deduct_l: deduct_l,         # Mức hụt dài
          deduct_w: deduct_w,         # Mức hụt rộng
          t: t,
          color: "#2563eb",
          grain: grain,
          machining_face: machining_face,
          label_id: label_id,
          material: mat_name,
          entity: resolved,
          bands: eb_deduct[:bands]
        }
      else
        # Là khối cha/khối tổng -> Đi sâu vào trong
        sub_ents = resolved.is_a?(Sketchup::Group) ? resolved.entities : (resolved.respond_to?(:definition) ? resolved.definition.entities : [])
        sub_ents.each do |child|
          next unless child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance)
          c_name = child.name.to_s
          c_def_name = child.respond_to?(:definition) ? child.definition.name.to_s : ""
          next if c_name =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i || c_def_name =~ /^(ABF_NESTING|CHILL_AI_NESTING|Khổ Ván)/i
          next if c_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i ||
                  c_def_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge|Chill_AI_EdgeBanding)/i
          collect_sub_parts(child, parts_list, params)
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
      mat_name = format_board_material(params['material_name'] || params['material'] || params['mat_name'])

      # BẢO VỆ CHẶNG 1: Chuẩn hóa kích thước không bao giờ âm hoặc nhỏ hơn giới hạn vật lý
      t = 17.5 if t <= 0.0 || t > 50.0
      l = 1200.0 if l <= 50.0
      w = 600.0 if w <= 50.0

      # Nếu chiều cao h quá bé (do người dùng click 1 tấm ván đơn lẻ hoặc khối nằm sàn h=18mm)
      if type == 'panel' || (h <= 50.0 && l > 100.0 && w > 100.0)
        return [
          { name: params['name'] || "Tấm ván gia công", w: [l, w].max, h: [l, w].min, t: t, color: "#d97706", material: mat_name }
        ]
      end

      h = 750.0 if h <= 100.0

      parts = []
      case type
      when 'desk', 'table'
        parts << { name: "Mặt bàn chính", w: l, h: w, t: t, color: "#d97706", material: mat_name }
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

    # ==========================================================================
    # THUẬT TOÁN NESTING TỐI ƯU MAXRECTS 2D (MAXIMAL RECTANGLES BIN PACKING)
    # Chuẩn tối ưu công nghiệp: ABF / Vectric Aspire / CutList Plus
    # Tự động gom cụm các khoảng trống tối đại, ôm khít cạnh ngắn (BSSF)
    # Giảm thiểu tối đa hao hụt ván, tận dụng tối đa phôi ván 1220x2440mm
    # ==========================================================================

    def self.normalize_thickness(t)
      val = t.to_f
      if val <= 7.0
        6.0
      elsif val <= 10.5
        9.0
      elsif val <= 13.5
        12.0
      elsif val <= 15.5
        15.0
      elsif val <= 19.5
        17.5 # Ván Melamine / MDF tiêu chuẩn 17mm, 17.5mm, 18mm gom chung 1 phôi
      elsif val <= 26.0
        25.0
      else
        val.round(1)
      end
    end

    def self.format_board_material(raw)
      s = raw.to_s.strip
      return "MDF Lõi Xanh" if s.empty? || s =~ /^(nil|null|default|\[default\])$/i

      s_lower = s.downcase
      if s_lower.include?('white_melamine') || (s_lower.include?('melamine') && s_lower.include?('trắng'))
        return "MDF Melamine Trắng"
      elsif s_lower.include?('grey_melamine') || (s_lower.include?('melamine') && s_lower.include?('xám'))
        return "MDF Melamine Xám"
      elsif s_lower.include?('plywood')
        return "Plywood"
      elsif s_lower.include?('mfc')
        return "MFC"
      elsif s_lower.include?('walnut') || s_lower.include?('óc chó')
        return "Gỗ Óc Chó"
      end

      # Giữ nguyên tên vật liệu người dùng đặt (Chill_Oak_Wood, Chill_Default_Wood...)
      clean = s.sub(/\s*\d+(\.\d+)?\s*(mm)?.*$/i, '').strip
      clean.empty? ? "MDF Lõi Xanh" : clean
    end

    class MaxRectsSheet
      attr_reader :id, :thickness, :material, :width, :height, :items, :used_area, :free_rects

      def initialize(id, thickness, material, width, height, inset)
        @id = id
        @thickness = thickness
        @material = material || "MDF Lõi Xanh"
        @width = width
        @height = height
        @inset = inset
        @items = []
        @used_area = 0.0

        # Khởi tạo hình chữ nhật tự do ban đầu là toàn bộ lòng phôi (trừ lề biên)
        @free_rects = [
          {
            x: @inset,
            y: @inset,
            w: @width - 2.0 * @inset,
            h: @height - 2.0 * @inset
          }
        ]
      end

      # Thử chèn một chi tiết vào khổ phôi theo thuật toán MaxRects BSSF
      def insert(part, spacing, allow_rotation)
        part_l = [part[:w].to_f, part[:h].to_f].max
        part_w = [part[:w].to_f, part[:h].to_f].min
        grain = part[:grain].to_s.downcase

        # NGUYÊN TẮC VÀNG ABF & NGHỀ MỘC CNC:
        # Khổ ván chuẩn: 2440mm là trục Y (chiều vân gỗ), 1220mm là trục X
        # Mặc định: Chiều vân là chiều dài tấm (grain = 'length' hoặc rỗng)
        # -> Chiều dài part_l BẮT BUỘC chạy dọc theo trục Y (2440mm). TUYỆT ĐỐI KHÔNG XOAY NGANG!
        orientations = []

        if grain == 'width'
          # Vân ngang: Chiều dài tấm part_l chạy theo trục X
          orientations << { w: part_l, h: part_w, rotated: true, grain_along: :x }
        elsif grain == 'free'
          # Chỉ khi chi tiết được chỉ định KHÔNG VÂN mới cho phép xoay tự do
          orientations << { w: part_w, h: part_l, rotated: false, grain_along: :y }
          if part_l != part_w
            orientations << { w: part_l, h: part_w, rotated: true, grain_along: :x }
          end
        else
          # Mặc định chuẩn ABF: Khóa vân dọc (Grain along length)
          # Chiều rộng part_w theo trục X (1220mm), chiều dài part_l theo trục Y (2440mm)
          orientations << { w: part_w, h: part_l, rotated: false, grain_along: :y }
        end

        best_rect = nil
        best_x = Float::INFINITY
        best_y = Float::INFINITY
        best_short_side = Float::INFINITY
        best_orientation = nil

        orientations.each do |opt|
          needed_w = opt[:w]
          needed_h = opt[:h]

          @free_rects.each do |fr|
            # Kiểm tra xem chi tiết có lọt vào khoảng trống fr không
            if fr[:w] >= needed_w && fr[:h] >= needed_h
              rem_x = fr[:w] - needed_w
              rem_y = fr[:h] - needed_h
              short_side = [rem_x, rem_y].min

              # Tiêu chí chuẩn ABF: Xếp đầy theo từng cột dọc trước (Column-First / Xẻ dọc phôi)
              # Ưu tiên 1: Cột bên trái nhất (X nhỏ nhất)
              # Ưu tiên 2: Trong cột đó, xếp từ dưới lên trên (Y nhỏ nhất)
              # Ưu tiên 3: Ôm khít cạnh nhất (Best Short Side Fit)
              if (fr[:x] < best_x) ||
                 (fr[:x] == best_x && fr[:y] < best_y) ||
                 (fr[:x] == best_x && fr[:y] == best_y && short_side < best_short_side)
                best_rect = { x: fr[:x], y: fr[:y], w: needed_w, h: needed_h }
                best_x = fr[:x]
                best_y = fr[:y]
                best_short_side = short_side
                best_orientation = opt
              end
            end
          end
        end

        return nil unless best_rect

        # Đặt thành công: Cắt khoảng trống tự do xung quanh chi tiết vừa đặt (Maximal Rectangles Split)
        # Cộng thêm khoảng cách dao cắt (spacing) vào vùng chiếm dụng để các tấm không dính nhau
        placed_box = {
          x: best_rect[:x],
          y: best_rect[:y],
          w: best_rect[:w] + spacing,
          h: best_rect[:h] + spacing
        }

        split_free_rectangles(placed_box)
        prune_free_rectangles

        item_data = {
          name: part[:name],
          original_name: part[:original_name],
          label_id: part[:label_id],
          x: best_rect[:x].round(2),
          y: best_rect[:y].round(2),
          w: best_rect[:w].round(2),
          h: best_rect[:h].round(2),
          dim_l: part_l.round(1),
          dim_w: part_w.round(1),
          t: @thickness,
          color: part[:color] || '#2563eb',
          rotated: best_orientation[:rotated],
          grain_along: best_orientation[:grain_along],
          entity: part[:entity],
          deduct_l: part[:deduct_l],
          deduct_w: part[:deduct_w],
          design_l: part[:design_l],
          design_w: part[:design_w],
          bands: part[:bands]
        }

        @items << item_data
        @used_area += best_rect[:w] * best_rect[:h]
        item_data
      end

      private

      # Phân rã các hình chữ nhật tự do bị đè lấn
      def split_free_rectangles(placed)
        new_free = []
        @free_rects.each do |fr|
          # Kiểm tra xem có giao nhau với placed không
          if (placed[:x] >= fr[:x] + fr[:w]) || (placed[:x] + placed[:w] <= fr[:x]) ||
             (placed[:y] >= fr[:y] + fr[:h]) || (placed[:y] + placed[:h] <= fr[:y])
            new_free << fr
            next
          end

          # Nếu giao nhau, cắt thành tối đa 4 hình chữ nhật con tự do
          # 1. Đoạn bên trái
          if placed[:x] > fr[:x]
            new_free << { x: fr[:x], y: fr[:y], w: placed[:x] - fr[:x], h: fr[:h] }
          end
          # 2. Đoạn bên phải
          if placed[:x] + placed[:w] < fr[:x] + fr[:w]
            new_free << { x: placed[:x] + placed[:w], y: fr[:y], w: (fr[:x] + fr[:w]) - (placed[:x] + placed[:w]), h: fr[:h] }
          end
          # 3. Đoạn phía dưới
          if placed[:y] > fr[:y]
            new_free << { x: fr[:x], y: fr[:y], w: fr[:w], h: placed[:y] - fr[:y] }
          end
          # 4. Đoạn phía trên
          if placed[:y] + placed[:h] < fr[:y] + fr[:h]
            new_free << { x: fr[:x], y: placed[:y] + placed[:h], w: fr[:w], h: (fr[:y] + fr[:h]) - (placed[:y] + placed[:h]) }
          end
        end
        @free_rects = new_free
      end

      # Lọc bỏ các hình chữ nhật con bị bao trọn hoàn toàn trong hình chữ nhật khác (Pruning)
      def prune_free_rectangles
        pruned = []
        len = @free_rects.length
        (0...len).each do |i|
          r1 = @free_rects[i]
          contained = false
          (0...len).each do |j|
            next if i == j
            r2 = @free_rects[j]
            if r1[:x] >= r2[:x] && r1[:y] >= r2[:y] &&
               r1[:x] + r1[:w] <= r2[:x] + r2[:w] &&
               r1[:y] + r1[:h] <= r2[:y] + r2[:h]
              contained = true
              break
            end
          end
          pruned << r1 unless contained
        end
        @free_rects = pruned
      end
    end

    def self.perform_nesting(parts, config = DEFAULT_CONFIG)
      # 1. Gom nhóm thông minh theo [độ dày chuẩn hóa, loại vật liệu]
      groups = parts.group_by do |part|
        norm_t = normalize_thickness(part[:t])
        mat = format_board_material(part[:material])
        [norm_t, mat]
      end
      all_sheets = []
      material_groups = []

      inset = config[:edge_margin].to_f + (config[:tool_diameter].to_f / 2.0)
      spacing = config[:part_gap].to_f + config[:tool_diameter].to_f
      sheet_w = config[:sheet_w].to_f
      sheet_h = config[:sheet_h].to_f

      # Sắp xếp các nhóm chuẩn ABF: Nhóm có nhiều chi tiết nhất (thùng tủ 17.5mm) xếp trước để đánh số sheet-1..4
      sorted_group_keys = groups.keys.sort_by do |(thickness, material)|
        parts_in_grp = groups[[thickness, material]]
        [-parts_in_grp.length, -thickness.to_f]
      end

      sorted_group_keys.each do |(thickness, material)|
        parts_in_group = groups[[thickness, material]]

        # Sắp xếp các chi tiết chuẩn ABF: Chiều dài lớn xếp trước, sau đó đến chiều rộng (chi tiết to xếp dưới, nhỏ lên trên)
        sorted_parts = parts_in_group.sort_by do |p|
          l = [p[:w].to_f, p[:h].to_f].max
          w = [p[:w].to_f, p[:h].to_f].min
          -(l * 10000.0 + w)
        end

        group_sheets = []

        sorted_parts.each do |part|
          placed = false

          # Thử xếp vào các khổ ván hiện có trong nhóm
          group_sheets.each do |sh|
            if sh.insert(part, spacing, config[:allow_rotation])
              placed = true
              break
            end
          end

          # Nếu các khổ ván hiện có không còn chỗ -> Mở khổ ván mới
          unless placed
            new_sheet_id = all_sheets.length + group_sheets.length + 1
            new_sh = MaxRectsSheet.new(new_sheet_id, thickness, material, sheet_w, sheet_h, inset)
            result = new_sh.insert(part, spacing, config[:allow_rotation])
            unless result
              raise CamValidationError, "Chi tiết '#{part[:name]}' (#{part[:w]} x #{part[:h]}mm) không vừa khổ ván #{sheet_w.to_i} x #{sheet_h.to_i}mm!"
            end
            group_sheets << new_sh
          end
        end

        formatted_sheets = group_sheets.map do |sh|
          {
            id: sh.id,
            thickness: sh.thickness,
            material: sh.material,
            items: sh.items,
            used_area: sh.used_area
          }
        end

        all_sheets.concat(formatted_sheets)
        material_groups << {
          thickness: thickness,
          material: material,
          sheet_count: formatted_sheets.length,
          sheets: formatted_sheets.map { |sh| sh[:id] }
        }
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

    # --- 3. LỰA CHỌN B: XUẤT RA BẢN VẼ TRẢI PHẲNG 2D TRÊN SKETCHUP (CHUẨN ABF DXF) ---
    def self.nest_to_sketchup(params)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      # Xóa sạch các bản vẽ Nesting cũ trên sàn trước khi vẽ mới
      model.active_entities.grep(Sketchup::Group).each do |g|
        if g.name =~ /^(ABF_NESTING|CHILL_AI_NESTING)/i
          g.erase! rescue nil
        end
      end

      config = cam_config(params)
      parts = extract_parts_from_selection_or_params(params)
      validate_parts!(parts)
      nested_data = perform_nesting(parts, config)

      model.start_operation("Chill AI - Nesting Bản Vẽ 2D (Chuẩn ABF DXF)", true)
      begin
        # TÍNH TOÁN VỊ TRÍ ĐẶT VÁN CHUẨN ABF:
        # Đặt ở góc phần tư phía trước bên trái (X < 0, Y < 0) theo đúng hướng mũi tên xanh lá và đỏ của Anh Huy.
        # Khổ ván nằm ở vùng Y âm (phía trước gốc tọa độ) và X âm (bên trái trục xanh lá).
        sheet_w = config[:sheet_w].mm
        sheet_h = config[:sheet_h].mm

        master_group = model.active_entities.add_group
        master_group.name = "ABF_NESTING_#{Time.now.strftime('%d%m_%H%M%S')}"

        tag_sheet = model.layers["ABF_Sheet"] || model.layers.add("ABF_Sheet")
        tag_cut   = model.layers["ABF_Cut"] || model.layers.add("ABF_Cut")
        tag_label = model.layers["CHILL_AI_LABELS"] || model.layers.add("CHILL_AI_LABELS")

        label_cfg = defined?(LabelingEngine) ? LabelingEngine.get_config : {}
        brand_str = label_cfg["show_brand"] ? label_cfg["brand_text"].to_s.strip : "NOI THAT CHILL CHILL DECOR"

        # 🌟 BỐ CỤC CHUẨN ABF: GOM NHÓM THEO [ĐỘ DÀY, VẬT LIỆU] - MỖI NHÓM NẰM TRÊN 1 HÀNG
        sheet_rows = []
        nested_data[:sheets].each do |sh|
          last_row = sheet_rows.last
          if last_row && last_row[:thickness] == sh[:thickness] && last_row[:material] == sh[:material]
            last_row[:sheets] << sh
          else
            sheet_rows << {
              thickness: sh[:thickness],
              material: sh[:material],
              sheets: [sh]
            }
          end
        end

        col_spacing = 350.mm
        row_spacing = 950.mm
        max_cols = sheet_rows.map { |r| r[:sheets].length }.max || 1
        margin_right = 180.mm

        # Tổng chiều rộng hàng dài nhất & Tọa độ X gốc của cột đầu tiên (bên trái nhất)
        max_row_w = max_cols * sheet_w + (max_cols - 1) * col_spacing
        base_start_x = -margin_right - max_row_w

        # Tọa độ Y: Hàng 0 (nhóm 1) ở dưới cùng, các nhóm tiếp theo xếp tiến dần lên trên (Y tăng) sát trục đỏ
        num_rows = sheet_rows.length
        top_row_y = -250.mm - sheet_h
        base_bottom_y = top_row_y - ((num_rows - 1) * (sheet_h + row_spacing))

        sheet_rows.each_with_index do |row_data, r_idx|
          row_y = base_bottom_y + (r_idx * (sheet_h + row_spacing))

          # 🌟 1. Nhãn Tên vật liệu & Độ dày: GOM HOÀN TOÀN Ở BÊN TRÁI HÀNG (Căn phải bằng Leader Line chuẩn ABF)
          thick_val = row_data[:thickness].to_s.sub(/\.0$/, '')
          mat_name = row_data[:material].to_s.strip
          clean_mat = (mat_name.empty? || mat_name =~ /^(nil|null|default|\[default\])$/i) ? "" : " #{mat_name}"
          label_str = "#{thick_val}mm —#{clean_mat}"

          # Điểm neo mục tiêu tại mép trái khổ ván đầu tiên, leader vector lùi sang trái 140mm
          # SketchUp tự động căn phải (Right-align) chuỗi text về phía mép ván, KHÔNG BAO GIỜ đè vào lòng ván!
          target_pt = Geom::Point3d.new(base_start_x - 30.mm, row_y + 850.mm, 0)
          leader_vec = Geom::Vector3d.new(-140.mm, 0, 0)
          txt_row_mat = master_group.entities.add_text(label_str, target_pt, leader_vec)
          if txt_row_mat
            txt_row_mat.layer = tag_sheet if tag_sheet
            txt_row_mat.arrow_type = 0 rescue nil # Không mũi tên rườm rà
            txt_row_mat.leader_type = 2 rescue nil # Đường kẻ thẳng ngang nối từ chữ đến mép ván chuẩn ABF
          end

          # 🌟 2. Vẽ từng khổ ván trong hàng (xếp ngang từ trái sang phải: c_idx = 0, 1, 2...)
          row_data[:sheets].each_with_index do |sheet, c_idx|
            sheet_offset_x = base_start_x + (c_idx * (sheet_w + col_spacing))
            sheet_offset_y = row_y

            sheet_group = master_group.entities.add_group
            sheet_group.name = "Khổ Ván #{sheet[:id]} - #{sheet[:material]} (#{config[:sheet_w].to_i}x#{config[:sheet_h].to_i}x#{sheet[:thickness]}mm)"
            sheet_group.layer = tag_sheet

            # 1. Viền bao 2D khổ ván phôi (1220 x 2440 mm)
            p1 = Geom::Point3d.new(sheet_offset_x, sheet_offset_y, 0)
            p2 = Geom::Point3d.new(sheet_offset_x + sheet_w, sheet_offset_y, 0)
            p3 = Geom::Point3d.new(sheet_offset_x + sheet_w, sheet_offset_y + sheet_h, 0)
            p4 = Geom::Point3d.new(sheet_offset_x, sheet_offset_y + sheet_h, 0)

            sheet_group.entities.add_line(p1, p2)
            sheet_group.entities.add_line(p2, p3)
            sheet_group.entities.add_line(p3, p4)
            sheet_group.entities.add_line(p4, p1)

            # 2. Nhãn đáy khổ ván: Căn ĐÚNG CHÍNH GIỮA cạnh đáy & Hạ thấp (-320mm) tuyệt đối không lấn vào tấm ván
            sheet_str = "sheet-#{sheet[:id]}"
            center_shift_x = (sheet_str.length * 24.mm)
            sheet_lbl_x = sheet_offset_x + (sheet_w / 2.0) - center_shift_x
            sheet_lbl_y = sheet_offset_y - 320.mm
            sheet_lbl_pt = Geom::Point3d.new(sheet_lbl_x, sheet_lbl_y, 0)

            txt_sheet = sheet_group.entities.add_text(sheet_str, sheet_lbl_pt)
            if txt_sheet
              txt_sheet.layer = tag_sheet if tag_sheet
              txt_sheet.leader_type = 0 rescue nil
              txt_sheet.arrow_type = 0 rescue nil
            end

            # 3. Từng chi tiết ván phẳng 2D & Nhãn ABF bên trong khổ ván
            sheet[:items].each_with_index do |item, item_idx|
              ix = sheet_offset_x + item[:x].mm
              iy = sheet_offset_y + item[:y].mm
              iw = item[:w].mm
              ih = item[:h].mm

              part_grp = sheet_group.entities.add_group
              part_grp.name = item[:name]
              part_grp.layer = tag_cut

              # 4 đường cắt chu vi (CNC Profile Cut)
              c1 = Geom::Point3d.new(ix, iy, 0)
              c2 = Geom::Point3d.new(ix + iw, iy, 0)
              c3 = Geom::Point3d.new(ix + iw, iy + ih, 0)
              c4 = Geom::Point3d.new(ix, iy + ih, 0)

              part_grp.entities.add_line(c1, c2)
              part_grp.entities.add_line(c2, c3)
              part_grp.entities.add_line(c3, c4)
              part_grp.entities.add_line(c4, c1)

              # Vẽ Nhãn ABF (Hình thoi ID, Mũi tên vân 2 chiều, Tên chi tiết, Tên xưởng)
              center_pt = Geom::Point3d.new(ix + iw / 2.0, iy + ih / 2.0, 0.1.mm)

              if item[:grain_along] == :x || (item[:grain_along].nil? && iw > ih)
                grain_u = Geom::Vector3d.new(1, 0, 0)
                grain_v = Geom::Vector3d.new(0, 1, 0)
              else
                grain_u = Geom::Vector3d.new(0, 1, 0)
                grain_v = Geom::Vector3d.new(-1, 0, 0)
              end
              normal = Geom::Vector3d.new(0, 0, 1)

              id_num = item[:label_id] ? item[:label_id].gsub(/\D/, '').to_i : (item_idx + 1)
              id_num = (item_idx + 1) if id_num == 0
              part_code = sprintf("P%02d", id_num)

              clean_pname = defined?(LabelingEngine) ? LabelingEngine.clean_raw_name(item[:original_name] || item[:name]) : item[:name]
              clean_pname = "Tấm ván" if clean_pname.empty? || clean_pname =~ /^Group/i

              dim_l = (item[:dim_l] || [item[:w], item[:h]].max).to_i
              dim_w = (item[:dim_w] || [item[:w], item[:h]].min).to_i
              dim_t = (item[:t] || 17.5).to_i
              dim_str = "#{dim_l}x#{dim_w}x#{dim_t}"
              full_title = "[#{part_code}] #{clean_pname} (#{dim_str})"

              if defined?(LabelingEngine)
                LabelingEngine.draw_2d_nested_label(
                  part_grp.entities, center_pt, grain_u, grain_v, normal,
                  [item[:w], item[:h]].max, [item[:w], item[:h]].min,
                  id_num, part_code, full_title, brand_str, label_cfg
                )
              end

              # 🌟 VẼ KÝ HIỆU CHỈ DÁN CẠNH CHUẨN ABF: MŨI TAM GIÁC & ĐƯỜNG NÉT CHỈ ĐÔI
              draw_edge_banding_symbols(part_grp.entities, item, ix, iy, iw, ih)
            end
          end
        end

        model.commit_operation

        # Khóa cứng kích thước cửa sổ khay dock (chống bị phình to ngang)
        WindowManager.snap_to_viewport rescue nil if defined?(WindowManager)

        # Zoom camera đến khu vực xếp ván để thợ mộc kiểm tra
        if model.active_view
          model.selection.clear
          model.active_view.zoom(master_group)
        end

        {
          "status" => "success",
          "message" => "Đã tạo bản vẽ Nesting 2D (Chuẩn ABF DXF) thành công cho #{nested_data[:sheets].length} khổ ván!",
          "total_sheets" => nested_data[:sheets].length,
          "total_parts" => parts.length,
          "utilization" => nested_data[:utilization],
          "cut_length_m" => nested_data[:total_perimeter_m],
          "estimated_time_min" => nested_data[:estimated_time_min]
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Nesting SU Error]: #{e.message}\n#{e.backtrace.join("\n")}"
        { "status" => "error", "message" => e.message }
      end
    end


    # ==========================================================================
    # CỤM 4 CHỨC NĂNG CHUẨN ABF / CNC MỘC NỘI THẤT
    # 1. Gắn nhãn tự động (Auto Label)
    # 2. Hiệu chỉnh mặt gia công (Flip Machining Face)
    # 3. Hiệu chỉnh chiều vân gỗ (Grain Direction)
    # 4. Nesting xếp ván tối ưu (Nest to SketchUp)
    # ==========================================================================

    # --- 1. GẮN NHÃN TỰ ĐỘNG CHO TẤM VÁN ---
    def self.auto_label_parts(selection_only = false)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      target_ents = []
      if selection_only && model.selection && model.selection.count > 0
        model.selection.each { |e| target_ents << e }
      else
        target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a
      end

      parts = []
      target_ents.each do |ent|
        next if ent.name.to_s =~ /^(ABF_NESTING|CHILL_AI_NESTING)/i || (ent.name.to_s =~ /Chill_AI_Fittings|Chill_AI_Label|_ABF_INTERSECT|Chill_AI_Intersect|Chill_AI_Hinges/i)
        collect_sub_parts(ent, parts)
      end

      if parts.empty?
        return { "status" => "warning", "message" => "Không tìm thấy tấm ván nào phù hợp trong mô hình/vùng chọn!" }
      end

      model.start_operation("Chill AI - Gắn Nhãn Tấm Ván CNC", true)
      begin
        labeled_count = 0
        parts.each_with_index do |item, idx|
          ent = item[:entity]
          next unless ent && ent.valid?

          part_code = sprintf("P%02d", idx + 1)
          inferred = infer_part_name(item)
          orig = item[:original_name].to_s.strip
          final_name = (orig.empty? || orig =~ /^Tấm ván/i) ? inferred : orig

          # Gán Attribute từ điển Chill_AI_CNC
          ent.set_attribute("Chill_AI_CNC", "label_id", part_code)
          ent.set_attribute("Chill_AI_CNC", "part_name", final_name)
          ent.set_attribute("Chill_AI_CNC", "dim_l", item[:w])
          ent.set_attribute("Chill_AI_CNC", "dim_w", item[:h])
          ent.set_attribute("Chill_AI_CNC", "dim_t", item[:t])
          ent.set_attribute("Chill_AI_CNC", "grain", "length") unless ent.get_attribute("Chill_AI_CNC", "grain")
          ent.set_attribute("Chill_AI_CNC", "machining_face", "top") unless ent.get_attribute("Chill_AI_CNC", "machining_face")

          # Cập nhật tên hiển thị trong Outliner
          ent.name = "[#{part_code}] #{final_name} (#{item[:w].to_i}x#{item[:h].to_i}x#{item[:t].to_i})"

          labeled_count += 1
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã gắn nhãn thành công cho #{labeled_count} chi tiết tấm ván!"
        {
          "status" => "success",
          "message" => "Đã gắn nhãn thành công cho #{labeled_count} chi tiết tấm ván (P01 -> P#{sprintf('%02d', labeled_count)})!",
          "count" => labeled_count
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Label Error]: #{e.message}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 2. HIỆU CHỈNH / LẬT MẶT GIA CÔNG CNC ---
    def self.flip_machining_face(selection_only = true)
      if defined?(LabelingEngine)
        return LabelingEngine.flip_machining_face(selection_only)
      end
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if model.selection.empty?
        return { "status" => "warning", "message" => "Vui lòng chọn ít nhất 1 tấm ván trong SketchUp để lật mặt gia công!" }
      end

      model.start_operation("Chill AI - Lật Mặt Gia Công CNC", true)
      begin
        flipped_count = 0
        last_face = "top"
        model.selection.each do |ent|
          next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
          cur_face = ent.get_attribute("Chill_AI_CNC", "machining_face") || "top"
          new_face = (cur_face == "top") ? "bottom" : "top"
          ent.set_attribute("Chill_AI_CNC", "machining_face", new_face)
          last_face = new_face
          flipped_count += 1
        end

        model.commit_operation
        face_label = (last_face == "top") ? "MẶT TRÊN ⤴ (Khoan cam/phay rãnh chính)" : "MẶT DƯỚI ⤵ (Đã đảo mặt gia công)"
        Sketchup.status_text = "Chill AI: Đã đổi mặt gia công -> #{face_label} cho #{flipped_count} tấm ván!"
        {
          "status" => "success",
          "message" => "Đã chuyển đổi mặt gia công sang #{face_label} cho #{flipped_count} tấm ván!",
          "face" => last_face,
          "face_label" => face_label,
          "count" => flipped_count
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Flip Face Error]: #{e.message}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 3. HIỆU CHỈNH CHIỀU VÂN GỖ ---
    def self.toggle_grain_direction(selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if model.selection.empty?
        return { "status" => "warning", "message" => "Vui lòng chọn ít nhất 1 tấm ván trong SketchUp để chỉnh chiều vân gỗ!" }
      end

      model.start_operation("Chill AI - Chỉnh Chiều Vân Gỗ", true)
      begin
        changed_count = 0
        new_grain = "length"
        model.selection.each do |ent|
          next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
          cur_grain = ent.get_attribute("Chill_AI_CNC", "grain") || "length"
          # Luân chuyển 3 trạng thái: length -> width -> free -> length
          new_grain = case cur_grain
                      when "length" then "width"
                      when "width" then "free"
                      else "length"
                      end
          ent.set_attribute("Chill_AI_CNC", "grain", new_grain)
          changed_count += 1
        end

        model.commit_operation
        grain_label = case new_grain
                      when "length" then "↕ VÂN DỌC (Theo chiều dài)"
                      when "width" then "↔ VÂN NGANG (Theo chiều rộng)"
                      else "🔄 TỰ DO (Không vân - tối ưu xếp ván)"
                      end
        Sketchup.status_text = "Chill AI: Chiều vân gỗ -> #{grain_label} (#{changed_count} tấm)"
        {
          "status" => "success",
          "message" => "Đã đặt chiều vân gỗ thành: #{grain_label} cho #{changed_count} tấm ván!",
          "grain" => new_grain,
          "grain_label" => grain_label,
          "count" => changed_count
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Grain Error]: #{e.message}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- DỰ ĐOÁN TÊN CHI TIẾT DỰA VÀO HÌNH HỌC VÀ VỊ TRÍ ---
    def self.infer_part_name(item)
      w = item[:w].to_f
      h = item[:h].to_f
      t = item[:t].to_f
      ent = item[:entity]
      return "Tấm ván" unless ent && ent.valid?

      bb = ent.bounds
      dz = bb.depth.to_mm.round(1)
      dx = bb.width.to_mm.round(1)
      dy = bb.height.to_mm.round(1)

      if dz == t # Tấm nằm ngang
        if bb.min.z < 100.mm
          "Đáy tủ / Đáy bàn"
        elsif bb.max.z > 1800.mm
          "Đỉnh tủ / Nóc"
        else
          "Đợt ngang / Mặt bàn"
        end
      elsif dx == t # Tấm dựng dọc theo trục X
        "Hồi tủ / Chân vách"
      elsif dy == t # Tấm dựng theo trục Y
        if t <= 10.0
          "Hậu tủ (Alu/Ván mỏng)"
        elsif w > 300 && h > 500
          "Cánh tủ"
        else
          "Yếm bàn / Mặt ngăn kéo"
        end
      else
        "Tấm ván chi tiết"
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
      # Layer 2: CNC_CUT_OUTLINE (Màu Trắng / Xanh Lá - Aspire Profile Cut)
      dxf << "0\nLAYER\n2\nCNC_CUT_OUTLINE\n70\n0\n62\n7\n6\nCONTINUOUS"
      # Layer 3: LABELS (Màu Vàng / Xanh Dương - Tên chi tiết & Nhãn)
      dxf << "0\nLAYER\n2\nLABELS\n70\n0\n62\n3\n6\nCONTINUOUS"
      # Layer 4: CNC_GROOVE (Màu Cam - Rãnh soi hậu & Rãnh ngàm âm dương)
      dxf << "0\nLAYER\n2\nCNC_GROOVE\n70\n0\n62\n40\n6\nCONTINUOUS"
      dxf << "0\nENDTAB\n0\nENDSEC"
      dxf << "0\nSECTION\n2\nENTITIES"

      label_cfg = defined?(LabelingEngine) ? LabelingEngine.get_config : {}
      brand_str = label_cfg["show_brand"] ? label_cfg["brand_text"].to_s.strip : "NOI THAT CHILL CHILL DECOR"

      # Gom nhóm theo [độ dày, vật liệu] để xuất DXF thành các hàng ngang chuẩn ABF
      sheet_rows = []
      nested_data[:sheets].each do |sh|
        last_row = sheet_rows.last
        if last_row && last_row[:thickness] == sh[:thickness] && last_row[:material] == sh[:material]
          last_row[:sheets] << sh
        else
          sheet_rows << {
            thickness: sh[:thickness],
            material: sh[:material],
            sheets: [sh]
          }
        end
      end

      sheet_rows.each_with_index do |row_data, r_idx|
        offset_y = r_idx * (config[:sheet_h] + 650.0)

        # Nhãn Tên vật liệu & Độ dày ở lề trái hàng (Chỉ in 1 lần duy nhất cho mỗi hàng)
        thick_val = row_data[:thickness].to_s.sub(/\.0$/, '')
        thick_y = offset_y + (config[:sheet_h] * 0.35)
        mat_name = row_data[:material].to_s.strip
        clean_mat = (mat_name.empty? || mat_name =~ /^(nil|null|default|\[default\])$/i) ? "" : " #{mat_name}"
        dxf << "0\nTEXT\n8\nSHEET_BORDER\n10\n-180.0\n20\n#{thick_y - 12.0}\n30\n0.0\n40\n28.0\n1\n#{thick_val}mm -#{clean_mat}"
        dxf_add_line(dxf, "SHEET_BORDER", -60.0, thick_y, 0.0, thick_y)

        row_data[:sheets].each_with_index do |sheet, c_idx|
          offset_x = c_idx * (config[:sheet_w] + 350.0)

          # 1. Viền khổ ván phôi
          dxf_add_polyline(dxf, "SHEET_BORDER", [
            [offset_x, offset_y],
            [offset_x + config[:sheet_w], offset_y],
            [offset_x + config[:sheet_w], offset_y + config[:sheet_h]],
            [offset_x, offset_y + config[:sheet_h]]
          ])

          # 2. Text sheet-1 ở đáy (Căn chính giữa & Hạ thấp cách mép đáy 250mm)
          sheet_str = "sheet-#{sheet[:id]}"
          dxf_center_x = offset_x + (config[:sheet_w] / 2.0) - (sheet_str.length * 15.0)
          dxf << "0\nTEXT\n8\nSHEET_BORDER\n10\n#{dxf_center_x}\n20\n#{offset_y - 250.0}\n30\n0.0\n40\n36.0\n1\n#{sheet_str}"

          # 3. Từng chi tiết ván
          sheet[:items].each_with_index do |item, item_idx|
            x1 = offset_x + item[:x]
            y1 = offset_y + item[:y]
            x2 = offset_x + item[:x] + item[:w]
            y2 = offset_y + item[:y] + item[:h]

            dxf_add_polyline(dxf, "CNC_CUT_OUTLINE", [
              [x1, y1],
              [x2, y1],
              [x2, y2],
              [x1, y2]
            ])

            # Nhãn tên chi tiết
            id_num = item[:label_id] ? item[:label_id].gsub(/\D/, '').to_i : (item_idx + 1)
            id_num = (item_idx + 1) if id_num == 0
            part_code = sprintf("P%02d", id_num)

            clean_pname = defined?(LabelingEngine) ? LabelingEngine.clean_raw_name(item[:original_name] || item[:name]) : item[:name]
            clean_pname = "Tam van" if clean_pname.empty? || clean_pname =~ /^Group/i
            clean_pname = dxf_text(clean_pname)

            dim_l = (item[:dim_l] || [item[:w], item[:h]].max).to_i
            dim_w = (item[:dim_w] || [item[:w], item[:h]].min).to_i
            dim_t = (item[:t] || 17.5).to_i
            dim_str = "#{dim_l}x#{dim_w}x#{dim_t}"
            full_title = "[#{part_code}] #{clean_pname} (#{dim_str})"

            cx = (x1 + x2) / 2.0
            cy = (y1 + y2) / 2.0

            # Text dòng 1: Tên tấm & Kích thước
            dxf << "0\nTEXT\n8\nLABELS\n10\n#{cx - 80.0}\n20\n#{cy + 10.0}\n30\n0.0\n40\n18.0\n1\n#{full_title}"
            # Text dòng 2: Tên xưởng
            dxf << "0\nTEXT\n8\nLABELS\n10\n#{cx - 80.0}\n20\n#{cy - 18.0}\n30\n0.0\n40\n14.0\n1\n#{dxf_text(brand_str)}"
          end
        end
      end
      dxf << "0\nENDSEC\n0\nEOF"
      dxf.join("\n")
    end

    def self.dxf_add_line(dxf, layer, x1, y1, x2, y2)
      # Chuẩn AutoCAD R12 & Vectric Aspire: điểm 1 (10, 20, 30), điểm 2 (11, 21, 31)
      dxf << "0\nLINE\n8\n#{layer}\n10\n#{sprintf('%.3f', x1)}\n20\n#{sprintf('%.3f', y1)}\n30\n0.0\n11\n#{sprintf('%.3f', x2)}\n21\n#{sprintf('%.3f', y2)}\n31\n0.0"
    end

    def self.dxf_add_polyline(dxf, layer, pts)
      # Chuẩn POLYLINE khép kín với đầy đủ dummy header và SEQEND có layer cho Vectric Aspire
      dxf << "0\nPOLYLINE\n8\n#{layer}\n66\n1\n70\n1\n10\n0.0\n20\n0.0\n30\n0.0"
      pts.each do |p|
        dxf << "0\nVERTEX\n8\n#{layer}\n10\n#{sprintf('%.3f', p[0])}\n20\n#{sprintf('%.3f', p[1])}\n30\n0.0"
      end
      dxf << "0\nSEQEND\n8\n#{layer}"
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
    # ==========================================================================
    # VẼ KÝ HIỆU CHỈ DÁN CẠNH CHUẨN ABF: MŨI TAM GIÁC & ĐƯỜNG NÉT CHỈ ĐÔI
        # ==========================================================================
    # VẼ KÝ HIỆU CHỈ DÁN CẠNH CHUẨN ABF: MŨI TAM GIÁC & ĐƯỜNG NÉT CHỈ ĐÔI
    # ==========================================================================
    # VẼ KÝ HIỆU CHỈ DÁN CẠNH CHUẨN ABF: MŨI TAM GIÁC TO RÕ & ĐƯỜNG NÉT CHỈ ĐÔI
    # ==========================================================================
        # ==========================================================================
    # VẼ KÝ HIỆU CHỈ DÁN CẠNH CHUẨN ABF: MŨI TAM GIÁC & ĐƯỜNG NÉT CHỈ ĐÔI
    # ==========================================================================
    def self.draw_edge_banding_symbols(entities, item, ix, iy, iw, ih)
      ent = item[:entity]
      edge_bands = {}

      # 1. Nguồn trực tiếp từ item[:bands]
      if item[:bands] && item[:bands].is_a?(Hash)
        item[:bands].each { |k, v| edge_bands[k.to_s] = v if v }
      end

      # 2. Quét từ entity thông qua EdgeBandingEngine và các Dictionary
      if ent && ent.valid?
        if defined?(EdgeBandingEngine)
          eb_engine_bands = EdgeBandingEngine.get_panel_edge_bandings(ent) rescue {}
          eb_engine_bands.each { |k, v| edge_bands[k.to_s] ||= v if v }
        end

        ['L1', 'L2', 'W1', 'W2'].each do |k|
          unless edge_bands[k]
            ["ABF_EDGE_BANDING", "CHILL_AI_EDGE_BANDING", "ABF_Part", "ABF_EB", "abf_part"].each do |dict_name|
              raw_val = ent.get_attribute(dict_name, k) || ent.get_attribute(dict_name, k.downcase)
              if raw_val.nil? && ent.respond_to?(:definition) && ent.definition
                raw_val = ent.definition.get_attribute(dict_name, k) || ent.definition.get_attribute(dict_name, k.downcase)
              end
              if raw_val
                begin
                  edge_bands[k] = JSON.parse(raw_val)
                rescue
                  edge_bands[k] = { 'name' => raw_val.to_s, 'thickness' => 1.0 }
                end
                break
              end
            end
          end
        end

        # 3. Phân tích trực tiếp 4 mặt cạnh của tấm ván
        if defined?(EdgeBandingEngine)
          geom = EdgeBandingEngine.analyze_panel_edges(ent) rescue nil
          if geom && geom[:edge_faces]
            geom[:edge_faces].each do |k, face|
              next if edge_bands[k]
              if face && face.valid? && face.material
                mat_name = face.material.name.to_s
                if mat_name =~ /^(EB_|eb_|Chỉ|Chi|dan_|dán_|band|edge)/i
                  edge_bands[k] = { 'name' => mat_name, 'thickness' => 1.0 }
                end
              end
            end
          end
        end
      end

      # TUYỆT ĐỐI CHỈ VẼ CÁC CẠNH CÓ DÁN CHỈ THỰC TẾ
      has_any_band = ['L1', 'L2', 'W1', 'W2'].any? { |k| edge_bands[k] }
      return unless has_any_band

      # 🌟 QUY ĐỔI CẠNH DÁN CHỈ SANG 4 CẠNH 2D PHẲNG CHUẨN ABF 100%:
      # - Nếu có 1 cạnh dài dán chỉ: Luôn định vị ở CẠNH TRÁI (:left). Nếu có 2 cạnh dài: Cả TRÁI và PHẢI.
      # - Nếu có 1 cạnh ngắn dán chỉ: Luôn định vị ở CẠNH ĐÁY (:bottom). Nếu có 2 cạnh ngắn: Cả ĐÁY và ĐỈNH.
      has_l1 = !edge_bands['L1'].nil?
      has_l2 = !edge_bands['L2'].nil?
      has_w1 = !edge_bands['W1'].nil?
      has_w2 = !edge_bands['W2'].nil?

      sides_to_draw = []
      if ih >= iw
        # Tấm ván nằm dọc: Cạnh Dài nằm dọc (Trái/Phải), Cạnh Ngắn nằm ngang (Đáy/Đỉnh)
        if has_l1 && has_l2
          sides_to_draw << { side: :left,  key: 'L1', band: edge_bands['L1'] }
          sides_to_draw << { side: :right, key: 'L2', band: edge_bands['L2'] }
        elsif has_l1 || has_l2
          b = edge_bands['L1'] || edge_bands['L2']
          k = has_l1 ? 'L1' : 'L2'
          sides_to_draw << { side: :left, key: k, band: b }
        end

        if has_w1 && has_w2
          sides_to_draw << { side: :bottom, key: 'W1', band: edge_bands['W1'] }
          sides_to_draw << { side: :top,    key: 'W2', band: edge_bands['W2'] }
        elsif has_w1 || has_w2
          b = edge_bands['W1'] || edge_bands['W2']
          k = has_w1 ? 'W1' : 'W2'
          sides_to_draw << { side: :bottom, key: k, band: b }
        end
      else
        # Tấm ván nằm ngang: Cạnh Dài nằm ngang (Đáy/Đỉnh), Cạnh Ngắn nằm dọc (Trái/Phải)
        if has_l1 && has_l2
          sides_to_draw << { side: :bottom, key: 'L1', band: edge_bands['L1'] }
          sides_to_draw << { side: :top,    key: 'L2', band: edge_bands['L2'] }
        elsif has_l1 || has_l2
          b = edge_bands['L1'] || edge_bands['L2']
          k = has_l1 ? 'L1' : 'L2'
          sides_to_draw << { side: :bottom, key: k, band: b }
        end

        if has_w1 && has_w2
          sides_to_draw << { side: :left,  key: 'W1', band: edge_bands['W1'] }
          sides_to_draw << { side: :right, key: 'W2', band: edge_bands['W2'] }
        elsif has_w1 || has_w2
          b = edge_bands['W1'] || edge_bands['W2']
          k = has_w1 ? 'W1' : 'W2'
          sides_to_draw << { side: :left, key: k, band: b }
        end
      end

      # Kích thước chuẩn ABF của mũi tam giác dán chỉ (Khớp 100% Mẫu ABF Ảnh 1)
      # - Đường nét chỉ đôi song song cách mép cạnh ván 2.5mm
      # - Mũi tam giác to rõ ràng: Đáy rộng 46mm, cao 24mm
      # - Đáy tam giác tựa trực tiếp trên đường chỉ đôi, đỉnh chĩa thẳng vào lòng ván
      # Kích thước chuẩn ABF của mũi tam giác dán chỉ (Khớp 100% Mẫu ABF Ảnh 1 & Ảnh 2)
      # - Đường nét chỉ đôi song song cách mép cạnh ván 2.5mm
      # - Mũi tam giác to rõ ràng: Đáy rộng 75mm, cao 36mm
      # - Đáy tam giác tựa trực tiếp trên đường chỉ đôi, đỉnh chĩa thẳng vào lòng ván
      # - Nâng cao độ z = 0.25mm chống Z-fighting, đảm bảo luôn hiển thị nổi bật trên mặt ván
      offset_d = 2.5.mm
      z_h = 0.25.mm
      base_w = [75.0.mm, [iw, ih].max * 0.45].min
      tri_h  = [36.0.mm, [iw, ih].min * 0.40].min

      model = entities.model rescue Sketchup.active_model
      tag_edge = model.layers["ABF_Edge"] || model.layers.add("ABF_Edge")
      tag_edge.visible = true rescue nil

      sides_to_draw.each do |s|
        case s[:side]
        when :left
          # Đường nét chỉ đôi chạy dọc cạnh trái
          l_line = entities.add_line(
            Geom::Point3d.new(ix + offset_d, iy, z_h),
            Geom::Point3d.new(ix + offset_d, iy + ih, z_h)
          )
          l_line.layer = tag_edge rescue nil

          # Mũi tam giác tựa trên đường chỉ đôi chĩa vào trong lòng ván
          mid_y = iy + ih / 2.0
          base_x = ix + offset_d
          p1 = Geom::Point3d.new(base_x, mid_y - base_w / 2.0, z_h)
          p2 = Geom::Point3d.new(base_x, mid_y + base_w / 2.0, z_h)
          p_peak = Geom::Point3d.new(base_x + tri_h, mid_y, z_h)
          t1 = entities.add_line(p1, p2)
          t2 = entities.add_line(p2, p_peak)
          t3 = entities.add_line(p_peak, p1)
          [t1, t2, t3].each { |e| e.layer = tag_edge rescue nil }

        when :right
          # Đường nét chỉ đôi chạy dọc cạnh phải
          r_line = entities.add_line(
            Geom::Point3d.new(ix + iw - offset_d, iy, z_h),
            Geom::Point3d.new(ix + iw - offset_d, iy + ih, z_h)
          )
          r_line.layer = tag_edge rescue nil

          # Mũi tam giác tựa trên đường chỉ đôi chĩa vào trong lòng ván
          mid_y = iy + ih / 2.0
          base_x = ix + iw - offset_d
          p1 = Geom::Point3d.new(base_x, mid_y - base_w / 2.0, z_h)
          p2 = Geom::Point3d.new(base_x, mid_y + base_w / 2.0, z_h)
          p_peak = Geom::Point3d.new(base_x - tri_h, mid_y, z_h)
          t1 = entities.add_line(p1, p2)
          t2 = entities.add_line(p2, p_peak)
          t3 = entities.add_line(p_peak, p1)
          [t1, t2, t3].each { |e| e.layer = tag_edge rescue nil }

        when :bottom
          # Đường nét chỉ đôi chạy dọc cạnh đáy
          b_line = entities.add_line(
            Geom::Point3d.new(ix, iy + offset_d, z_h),
            Geom::Point3d.new(ix + iw, iy + offset_d, z_h)
          )
          b_line.layer = tag_edge rescue nil

          # Mũi tam giác tựa trên đường chỉ đôi chĩa lên trên vào trong lòng ván
          mid_x = ix + iw / 2.0
          base_y = iy + offset_d
          p1 = Geom::Point3d.new(mid_x - base_w / 2.0, base_y, z_h)
          p2 = Geom::Point3d.new(mid_x + base_w / 2.0, base_y, z_h)
          p_peak = Geom::Point3d.new(mid_x, base_y + tri_h, z_h)
          t1 = entities.add_line(p1, p2)
          t2 = entities.add_line(p2, p_peak)
          t3 = entities.add_line(p_peak, p1)
          [t1, t2, t3].each { |e| e.layer = tag_edge rescue nil }

        when :top
          # Đường nét chỉ đôi chạy dọc cạnh đỉnh
          tp_line = entities.add_line(
            Geom::Point3d.new(ix, iy + ih - offset_d, z_h),
            Geom::Point3d.new(ix + iw, iy + ih - offset_d, z_h)
          )
          tp_line.layer = tag_edge rescue nil

          # Mũi tam giác tựa trên đường chỉ đôi chĩa xuống dưới vào trong lòng ván
          mid_x = ix + iw / 2.0
          base_y = iy + ih - offset_d
          p1 = Geom::Point3d.new(mid_x - base_w / 2.0, base_y, z_h)
          p2 = Geom::Point3d.new(mid_x + base_w / 2.0, base_y, z_h)
          p_peak = Geom::Point3d.new(mid_x, base_y - tri_h, z_h)
          t1 = entities.add_line(p1, p2)
          t2 = entities.add_line(p2, p_peak)
          t3 = entities.add_line(p_peak, p1)
          [t1, t2, t3].each { |e| e.layer = tag_edge rescue nil }
        end
      end
    end
  end
end
