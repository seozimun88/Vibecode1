# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Labeling & Grain Direction Engine (Chuẩn ABF CNC)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# Chức năng:
# 1. Dán nhãn trực quan lên mặt tấm ván: Hình thoi ID, Mũi tên chiều vân 2 chiều,
#    Cú pháp tên tấm [P01] (DxRxC) và Thương hiệu xưởng (NOI THAT CHILL CHILL DECOR).
# 2. Cụm nhãn là group dính liền trên mặt ván (tương tự cụm lỗ cam liên kết).
# 3. Điều khiển thông số và xoay chiều vân gỗ (0°, 90°, 45°, -45°...) phục vụ Nesting.
# 4. Canh giữa tâm ván 100%, chống cấn mép, tự động lọc sạch tên cũ chống lặp.
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module LabelingEngine
    LAYER_NAME = "CHILL_AI_LABELS".freeze
    DEFAULT_BRAND = "NOI THAT CHILL CHILL DECOR".freeze

    DEFAULT_CONFIG = {
      "show_id" => true,
      "show_name" => true,
      "show_grain" => true,
      "show_brand" => true,
      "brand_text" => DEFAULT_BRAND,
      "max_size" => 80.0,
      "font_size" => 15.0, # Chiều cao chữ vừa vặn chuẩn mộc (14-16mm)
      "grain_angle" => 0.0, # 0 = dọc chiều dài, 90 = ngang chiều rộng
      "grain_mode" => "length" # "length", "width", "custom"
    }.freeze

    @config = nil

    # --- 1. QUẢN LÝ CẤU HÌNH NHÃN ---
    def self.config_path
      root = ModuleLoader.plugin_root rescue File.expand_path(File.join(File.dirname(__FILE__), '..'))
      File.join(root, 'knowledge_base', 'label_presets.json')
    end

    def self.get_config
      return @config if @config
      load_config
    end

    def self.load_config
      path = config_path
      if File.exist?(path)
        begin
          data = JSON.parse(File.read(path, encoding: 'UTF-8'))
          @config = DEFAULT_CONFIG.merge(data)
        rescue => e
          puts "[Chill AI LabelingEngine] Lỗi đọc label_presets.json: #{e.message}"
          @config = DEFAULT_CONFIG.dup
        end
      else
        @config = DEFAULT_CONFIG.dup
        save_config(@config)
      end
      @config
    end

    def self.save_config(new_config)
      @config = DEFAULT_CONFIG.merge(new_config || {})
      path = config_path
      begin
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w:UTF-8') do |f|
          f.write(JSON.pretty_generate(@config))
        end
        puts "[Chill AI LabelingEngine] Đã lưu cấu hình nhãn thành công!"
      rescue => e
        puts "[Chill AI LabelingEngine] Lỗi lưu label_presets.json: #{e.message}"
      end
      @config
    end

    # --- 2. DÁN NHÃN TRỰC QUAN LÊN MẶT TẤM VÁN ---
    def self.apply_labels(selection_only = false, custom_config = nil)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      cfg = custom_config ? DEFAULT_CONFIG.merge(custom_config) : get_config
      save_config(cfg) if custom_config

      # Thu thập các tấm ván
      target_ents = []
      if selection_only && model.selection && model.selection.count > 0
        model.selection.each { |e| target_ents << e }
      else
        target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a
      end

      parts = []
      target_ents.each do |ent|
        next if ent.name.to_s.start_with?("CHILL_AI_NESTING")
        collect_leaf_panels(ent, parts)
      end

      if parts.empty?
        return { "status" => "warning", "message" => "Không tìm thấy tấm ván nào phù hợp trong mô hình/vùng chọn!" }
      end

      model.start_operation("Chill AI - Dán Nhãn Chuẩn ABF", true)
      begin
        labeled_count = 0
        parts.each_with_index do |part_info, idx|
          ent = part_info[:entity]
          next unless ent && ent.valid?

          id_num = idx + 1
          part_code = sprintf("P%02d", id_num)
          
          # Làm sạch tên cũ để chống bị lặp [P01] [P02]...
          cleaned_orig = clean_raw_name(part_info[:original_name])
          inferred = infer_panel_name(part_info)
          is_generic = cleaned_orig.empty? || 
                       cleaned_orig =~ /^Tấm ván/i || 
                       cleaned_orig =~ /^(Group|Component)(#\d+)?$/i
          final_name = is_generic ? inferred : cleaned_orig

          # Lưu thuộc tính CNC vào Dictionary
          ent.set_attribute("Chill_AI_CNC", "label_id", part_code)
          ent.set_attribute("Chill_AI_CNC", "id_number", id_num)
          ent.set_attribute("Chill_AI_CNC", "part_name", final_name)
          ent.set_attribute("Chill_AI_CNC", "dim_l", part_info[:l])
          ent.set_attribute("Chill_AI_CNC", "dim_w", part_info[:w])
          ent.set_attribute("Chill_AI_CNC", "dim_t", part_info[:t])
          
          grain_mode = cfg["grain_mode"] || "length"
          grain_angle = cfg["grain_angle"].to_f
          ent.set_attribute("Chill_AI_CNC", "grain", grain_mode)
          ent.set_attribute("Chill_AI_CNC", "grain_angle", grain_angle)
          ent.set_attribute("Chill_AI_CNC", "machining_face", "top") unless ent.get_attribute("Chill_AI_CNC", "machining_face")
          ent.set_attribute("Chill_AI_CNC", "brand", cfg["brand_text"].to_s)

          # Cập nhật tên hiển thị chuẩn mộc trong Outliner
          dim_str = "#{part_info[:l].to_i}x#{part_info[:w].to_i}x#{part_info[:t].to_i}"
          ent.name = "[#{part_code}] #{final_name} (#{dim_str})"

          # Vẽ cụm nhãn trực quan 3D dính chặt trên mặt ván - ĐỨNG CHÍNH GIỮA TÂM VÁN
          draw_visual_label(ent, part_info, id_num, part_code, final_name, cfg)

          labeled_count += 1
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã dán nhãn chuẩn ABF thành công cho #{labeled_count} chi tiết tấm ván!"
        {
          "status" => "success",
          "message" => "Đã dán nhãn thành công cho #{labeled_count} chi tiết tấm ván (P01 -> P#{sprintf('%02d', labeled_count)})!",
          "count" => labeled_count,
          "config" => cfg
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI LabelingEngine Error]: #{e.message}\n#{e.backtrace.join("\n")}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 3. ĐIỀU CHỈNH / XOAY CHIỀU VÂN GỖ ---
    def self.rotate_grain_direction(angle_deg = 90.0, selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if selection_only && (model.selection.nil? || model.selection.empty?)
        return { "status" => "warning", "message" => "Vui lòng chọn ít nhất 1 tấm ván trong SketchUp để xoay chiều vân gỗ!" }
      end

      target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Xoay Chiều Vân Gỗ", true)
      begin
        rotated_count = 0
        cfg = get_config

        target_ents.each do |ent|
          parts = []
          collect_leaf_panels(ent, parts)
          parts.each do |part_info|
            target_ent = part_info[:entity]
            next unless target_ent && target_ent.valid?

            # Tính góc mới
            cur_angle = (target_ent.get_attribute("Chill_AI_CNC", "grain_angle") || 0.0).to_f
            
            # Nếu xoay 90 độ (chế độ toggle nút 3. CHIỀU VÂN):
            # Tự động đảo qua lại giữa 0° (Vân Dọc) và 90° (Vân Ngang)
            if (angle_deg - 90.0).abs < 0.001
              if (cur_angle - 90.0).abs < 1.0 || (cur_angle - 270.0).abs < 1.0
                new_angle = 0.0
                delta_rot = -90.0
              else
                new_angle = 90.0
                delta_rot = 90.0
              end
            else
              new_angle = (cur_angle + angle_deg) % 360.0
              delta_rot = angle_deg
            end
            
            # Cập nhật mode vân
            mode = if (new_angle - 0.0).abs < 1.0 || (new_angle - 180.0).abs < 1.0
                     "length"
                   elsif (new_angle - 90.0).abs < 1.0 || (new_angle - 270.0).abs < 1.0
                     "width"
                   else
                     "custom"
                   end

            target_ent.set_attribute("Chill_AI_CNC", "grain", mode)
            target_ent.set_attribute("Chill_AI_CNC", "grain_angle", new_angle)

            # Lấy thông tin ID và tên sạch
            id_num = target_ent.get_attribute("Chill_AI_CNC", "id_number") || (rotated_count + 1)
            part_code = target_ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)
            raw_part_name = target_ent.get_attribute("Chill_AI_CNC", "part_name") || infer_panel_name(part_info)
            cleaned_orig = clean_raw_name(raw_part_name)
            is_generic = cleaned_orig.empty? || 
                         cleaned_orig =~ /^Tấm ván/i || 
                         cleaned_orig =~ /^(Group|Component)(#\d+)?$/i
            part_name = is_generic ? infer_panel_name(part_info) : cleaned_orig

            # 🌟 TỐI ƯU HÓA SIÊU TỐC (ZERO-LAG GRAIN ROTATION - TỨC THÌ < 0.1ms):
            # Nếu tấm ván đã có sẵn nhãn Chill_AI_Label, dùng phép xoay ma trận Transformation
            # xoay nhãn quanh trục pháp tuyến của mặt ván mà KHÔNG CẦN xóa và dựng lại font 3D vector!
            ents_pool = target_ent.is_a?(Sketchup::Group) ? target_ent.entities : target_ent.definition.entities
            existing_label = ents_pool.grep(Sketchup::Group).find { |g| g.name =~ /^Chill_AI_Label/i }

            if existing_label && existing_label.valid?
              face, center, u_vec, v_vec, normal = find_face_and_axes(target_ent, part_info)
              if center && normal
                rot_trans = Geom::Transformation.rotation(center, normal, delta_rot.degrees)
                existing_label.transform!(rot_trans)
              else
                part_cfg = cfg.dup
                part_cfg["grain_angle"] = new_angle
                part_cfg["grain_mode"] = mode
                draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
              end
            else
              part_cfg = cfg.dup
              part_cfg["grain_angle"] = new_angle
              part_cfg["grain_mode"] = mode
              draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
            end

            rotated_count += 1
          end
        end

        model.commit_operation
        grain_desc = (angle_deg == 90.0 || angle_deg == -90.0) ? "Đổi hướng Vân Dọc ↔ Vân Ngang (90°)" : "Xoay góc vân #{angle_deg}°"
        Sketchup.status_text = "Chill AI: Đã #{grain_desc} cho #{rotated_count} tấm ván!"
        {
          "status" => "success",
          "message" => "Đã xoay chiều vân gỗ thành công cho #{rotated_count} tấm ván!",
          "count" => rotated_count,
          "angle" => angle_deg
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Rotate Grain Error]: #{e.message}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 3b. THIẾT LẬP GÓC XOAY VÂN TUYỆT ĐỐI (CHUẨN BẢNG CHỌN GÓC ABF) ---
    def self.set_grain_angle(target_angle_deg = 0.0, selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if selection_only && (model.selection.nil? || model.selection.empty?)
        return { "status" => "warning", "message" => "Vui lòng chọn ít nhất 1 tấm ván trong SketchUp để đặt góc xoay vân!" }
      end

      target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Đặt Góc Xoay Vân", true)
      begin
        rotated_count = 0
        cfg = get_config
        target_angle = target_angle_deg.to_f

        # Xác định mode vân
        mode = if target_angle.abs < 1.0 || (target_angle.abs - 180.0).abs < 1.0 || (target_angle.abs - 360.0).abs < 1.0
                 "length"
               elsif (target_angle.abs - 90.0).abs < 1.0 || (target_angle.abs - 270.0).abs < 1.0
                 "width"
               else
                 "custom"
               end

        target_ents.each do |ent|
          parts = []
          collect_leaf_panels(ent, parts)
          parts.each do |part_info|
            target_ent = part_info[:entity]
            next unless target_ent && target_ent.valid?

            cur_angle = (target_ent.get_attribute("Chill_AI_CNC", "grain_angle") || 0.0).to_f
            delta_angle = target_angle - cur_angle

            target_ent.set_attribute("Chill_AI_CNC", "grain", mode)
            target_ent.set_attribute("Chill_AI_CNC", "grain_angle", target_angle)

            id_num = target_ent.get_attribute("Chill_AI_CNC", "id_number") || (rotated_count + 1)
            part_code = target_ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)
            raw_part_name = target_ent.get_attribute("Chill_AI_CNC", "part_name") || infer_panel_name(part_info)
            cleaned_orig = clean_raw_name(raw_part_name)
            is_generic = cleaned_orig.empty? || 
                         cleaned_orig =~ /^Tấm ván/i || 
                         cleaned_orig =~ /^(Group|Component)(#\d+)?$/i
            part_name = is_generic ? infer_panel_name(part_info) : cleaned_orig

            ents_pool = target_ent.is_a?(Sketchup::Group) ? target_ent.entities : target_ent.definition.entities
            existing_label = ents_pool.grep(Sketchup::Group).find { |g| g.name =~ /^Chill_AI_Label/i }

            if existing_label && existing_label.valid?
              if delta_angle.abs > 0.001
                face, center, u_vec, v_vec, normal = find_face_and_axes(target_ent, part_info)
                if center && normal
                  rot_trans = Geom::Transformation.rotation(center, normal, delta_angle.degrees)
                  existing_label.transform!(rot_trans)
                else
                  part_cfg = cfg.dup
                  part_cfg["grain_angle"] = target_angle
                  part_cfg["grain_mode"] = mode
                  draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
                end
              end
            else
              part_cfg = cfg.dup
              part_cfg["grain_angle"] = target_angle
              part_cfg["grain_mode"] = mode
              draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
            end

            rotated_count += 1
          end
        end

        model.commit_operation
        grain_desc = "#{target_angle}°"
        grain_desc = "0° (Vân Dọc)" if target_angle == 0.0
        grain_desc = "90° (Vân Ngang)" if target_angle == 90.0
        Sketchup.status_text = "Chill AI: Đã đặt góc vân #{grain_desc} cho #{rotated_count} tấm ván!"
        {
          "status" => "success",
          "message" => "Đã đặt góc vân #{grain_desc} thành công cho #{rotated_count} tấm ván!",
          "count" => rotated_count,
          "angle" => target_angle
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Set Grain Angle Error]: #{e.message}\n#{e.backtrace.join("\n")}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 4. HIỆU CHỈNH / LẬT MẶT GIA CÔNG CNC (CHUYỂN NHÃN SANG MẶT ĐỐI DIỆN) ---
    def self.flip_machining_face(selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if selection_only && (model.selection.nil? || model.selection.empty?)
        return { "status" => "warning", "message" => "Vui lòng chọn ít nhất 1 tấm ván trong SketchUp để lật mặt gia công!" }
      end

      target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Lật Mặt Gia Công CNC", true)
      begin
        flipped_count = 0
        last_face_label = "MẶT TRÊN ⤴"
        cfg = get_config

        target_ents.each do |ent|
          parts = []
          collect_leaf_panels(ent, parts)
          parts.each do |part_info|
            target_ent = part_info[:entity]
            next unless target_ent && target_ent.valid?

            # Đảo mặt gia công: "top" <-> "bottom"
            cur_face = target_ent.get_attribute("Chill_AI_CNC", "machining_face") || "top"
            new_face = (cur_face == "top") ? "bottom" : "top"
            target_ent.set_attribute("Chill_AI_CNC", "machining_face", new_face)

            # Lấy thông tin ID và Tên sạch
            id_num = target_ent.get_attribute("Chill_AI_CNC", "id_number")
            if id_num.nil?
              id_num = flipped_count + 1
              part_code = sprintf("P%02d", id_num)
              target_ent.set_attribute("Chill_AI_CNC", "id_number", id_num)
              target_ent.set_attribute("Chill_AI_CNC", "label_id", part_code)
            else
              part_code = target_ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)
            end

            raw_part_name = target_ent.get_attribute("Chill_AI_CNC", "part_name") || infer_panel_name(part_info)
            cleaned_orig = clean_raw_name(raw_part_name)
            is_generic = cleaned_orig.empty? || 
                         cleaned_orig =~ /^Tấm ván/i || 
                         cleaned_orig =~ /^(Group|Component)(#\d+)?$/i
            part_name = is_generic ? infer_panel_name(part_info) : cleaned_orig

            grain_angle = (target_ent.get_attribute("Chill_AI_CNC", "grain_angle") || 0.0).to_f
            grain_mode = target_ent.get_attribute("Chill_AI_CNC", "grain") || "length"

            part_cfg = cfg.dup
            part_cfg["grain_angle"] = grain_angle
            part_cfg["grain_mode"] = grain_mode

            # 🌟 TỐI ƯU HÓA SIÊU TỐC (ZERO-LAG FLIP - TỨC THÌ TRONG 0.1ms):
            # Nếu tấm ván đã có sẵn nhãn Chill_AI_Label, dùng phép xoay ma trận Transformation
            # lật sang mặt đối diện ngay lập tức mà KHÔNG CẦN xóa và vẽ lại font 3D!
            ents_pool = target_ent.is_a?(Sketchup::Group) ? target_ent.entities : target_ent.definition.entities
            existing_label = ents_pool.grep(Sketchup::Group).find { |g| g.name =~ /^Chill_AI_Label/i }

            if existing_label && existing_label.valid?
              face, center, u_vec, v_vec, normal = find_face_and_axes(target_ent, part_info)
              if center && u_vec && normal
                thick = part_info[:t].to_f.mm
                # Tâm tim phôi ván nằm chính giữa độ dày
                mid_pt = center.offset(normal, -thick / 2.0)
                # Xoay 180 độ quanh trục vân gỗ u_vec đi qua tim ván
                rot_trans = Geom::Transformation.rotation(mid_pt, u_vec, 180.degrees)
                existing_label.transform!(rot_trans)
              else
                draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
              end
            else
              # Chưa có nhãn -> Vẽ nhãn lần đầu
              draw_visual_label(target_ent, part_info, id_num, part_code, part_name, part_cfg)
            end

            last_face_label = (new_face == "top") ? "MẶT TRÊN ⤴ (Mặt mặc định)" : "MẶT DƯỚI ⤵ (Đã đảo mặt gia công)"
            flipped_count += 1
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã lật mặt dán nhãn sang #{last_face_label} cho #{flipped_count} tấm ván!"
        {
          "status" => "success",
          "message" => "Đã lật mặt dán nhãn sang #{last_face_label} cho #{flipped_count} tấm ván! (Khi Nesting CNC tấm này sẽ được lật mặt tương ứng)",
          "face_label" => last_face_label,
          "count" => flipped_count
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Flip Face Error]: #{e.message}\n#{e.backtrace.join("\n")}"
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 5. XÓA TẤT CẢ NHÃN 3D ---
    def self.clear_all_labels
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      model.start_operation("Chill AI - Xóa Nhãn 3D", true)
      begin
        deleted_count = 0
        model.entities.grep(Sketchup::Group).each do |g|
          deleted_count += clean_label_groups_recursive(g)
        end
        model.definitions.each do |defn|
          defn.entities.grep(Sketchup::Group).each do |g|
            if g.name =~ /^Chill_AI_Label/i
              g.erase! rescue nil
              deleted_count += 1
            end
          end
        end
        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã xóa #{deleted_count} nhãn 3D trên mô hình."
        { "status" => "success", "message" => "Đã xóa sạch #{deleted_count} nhãn 3D!", "count" => deleted_count }
      rescue => e
        model.abort_operation
        { "status" => "error", "message" => e.message }
      end
    end

    # --- 4b. TÌM MẶT GIA CÔNG CHUẨN & HỆ TRỤC TỌA ĐỘ VÁN ---
    def self.find_face_and_axes(entity, part_info = nil)
      return [nil, nil, nil, nil, nil] unless entity && entity.valid?
      ents = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      faces = ents.grep(Sketchup::Face)
      return [nil, nil, nil, nil, nil] if faces.empty?

      # Sắp xếp các mặt theo diện tích giảm dần: 2 mặt lớn nhất là 2 mặt ván
      sorted_faces = faces.sort_by { |f| -f.area }
      machining_face_pref = entity.get_attribute("Chill_AI_CNC", "machining_face") || "top"

      tr = entity.transformation
      candidate_faces = sorted_faces[0..1]
      selected_face = candidate_faces.first

      if candidate_faces.length > 1
        f1 = candidate_faces[0]
        f2 = candidate_faces[1]
        norm1 = f1.normal.transform(tr)
        norm2 = f2.normal.transform(tr)

        if (norm1.z - norm2.z).abs > 0.01
          selected_face = (machining_face_pref == "bottom") ? ((norm1.z < norm2.z) ? f1 : f2) : ((norm1.z > norm2.z) ? f1 : f2)
        elsif (norm1.y - norm2.y).abs > 0.01
          selected_face = (machining_face_pref == "bottom") ? ((norm1.y < norm2.y) ? f1 : f2) : ((norm1.y > norm2.y) ? f1 : f2)
        elsif (norm1.x - norm2.x).abs > 0.01
          selected_face = (machining_face_pref == "bottom") ? ((norm1.x < norm2.x) ? f1 : f2) : ((norm1.x > norm2.x) ? f1 : f2)
        else
          selected_face = (machining_face_pref == "bottom") ? f2 : f1
        end
      end

      normal = selected_face.normal.clone
      normal.normalize! rescue nil
      center = selected_face.bounds.center

      # Tìm trục dọc (chiều dài) và trục ngang (chiều rộng) của mặt
      longest_edge = selected_face.edges.max_by(&:length)
      if longest_edge
        u_vec = longest_edge.line[1].clone
        u_vec.normalize! rescue nil
      else
        u_vec = normal.parallel?(Geom::Vector3d.new(0, 0, 1)) ? Geom::Vector3d.new(1, 0, 0) : (normal * Geom::Vector3d.new(0, 0, 1))
        u_vec.normalize! rescue nil
      end

      v_vec = normal * u_vec
      v_vec.normalize! rescue nil

      [selected_face, center, u_vec, v_vec, normal]
    rescue => err
      puts "[Chill AI find_face_and_axes Error]: #{err.message}"
      [nil, nil, nil, nil, nil]
    end

    def self.apply_grain_rotation(u_vec, v_vec, normal, angle_deg)
      return [u_vec, v_vec] if angle_deg.nil? || angle_deg.to_f == 0.0
      rot = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), normal, angle_deg.to_f.degrees)
      u_rot = u_vec.transform(rot)
      u_rot.normalize! rescue nil
      v_rot = v_vec.transform(rot)
      v_rot.normalize! rescue nil
      [u_rot, v_rot]
    rescue => _e
      [u_vec, v_vec]
    end

    # --- 5. VẼ HÌNH HỌC NHÃN TRỰC QUAN (CANH GIỮA TÂM VÁN 100%) ---
    def self.draw_visual_label(entity, part_info, id_num, part_code, part_name, cfg)
      # Xóa nhãn cũ bên trong entity
      ents = entity.is_a?(Sketchup::Group) ? entity.entities : (entity.make_unique rescue nil; entity.definition.entities)
      ents.grep(Sketchup::Group).select { |g| g.name =~ /^(Chill_AI_Label|_ABF_Label|ABF_Label)/i }.each { |g| g.erase! rescue nil }

      # 1. Tìm mặt gia công chuẩn (Ưu tiên mặt trên cùng theo World Space)
      face, center, u_vec, v_vec, normal = find_face_and_axes(entity, part_info)
      return unless face && face.valid?

      # 2. Xử lý góc xoay vân gỗ
      grain_angle = (cfg["grain_angle"] || 0.0).to_f
      if cfg["grain_mode"] == "width"
        grain_angle = 90.0
      end

      # Áp dụng góc xoay vân vào vector trục vân
      grain_u, grain_v = apply_grain_rotation(u_vec, v_vec, normal, grain_angle)

      # 3. Chuẩn hóa kích thước font chữ và đo độ dài tổng cụm nhãn
      panel_len = (grain_angle == 90.0 || grain_angle == 270.0) ? part_info[:w] : part_info[:l]
      panel_w   = (grain_angle == 90.0 || grain_angle == 270.0) ? part_info[:l] : part_info[:w]
      
      # Chiều cao chữ tỷ lệ theo khổ ván (12-16mm, không bao giờ quá to)
      font_h = [(cfg["font_size"] || 15.0).to_f, 16.0].min
      font_h = [font_h, panel_len * 0.035].min.mm # Co nhỏ nếu ván quá ngắn
      if panel_w < 80.0
        font_h = [font_h, (panel_w * 0.18).mm].min
      end

      dim_str = "#{part_info[:l].to_i}x#{part_info[:w].to_i}x#{part_info[:t].to_i}"
      clean_name = clean_raw_name(part_name)
      face_suffix = (entity.get_attribute("Chill_AI_CNC", "machining_face") == "bottom") ? " - MẶT DƯỚI ⤵" : ""
      full_title = "[#{part_code}] #{clean_name} (#{dim_str})#{face_suffix}"
      brand_str = cfg["show_brand"] ? cfg["brand_text"].to_s.strip : ""

      # Kích thước hình thoi ID
      diamond_rx = cfg["show_id"] ? 18.mm : 0.mm
      diamond_ry = cfg["show_id"] ? 12.mm : 0.mm
      diamond_w = diamond_rx * 2.0

      # Giới hạn chiều dài toàn cụm nhãn tối đa 65% chiều dài tấm ván
      max_allowed_len = (panel_len * 0.65).mm

      # Tự động scale font chữ nếu text dài hơn không gian cho phép (chống tràn ra ngoài mũi tên)
      avail_text_len = max_allowed_len - diamond_w - 40.mm
      avail_text_len = 100.mm if avail_text_len < 100.mm

      raw_text_len = full_title.length * (font_h * 0.58)
      if raw_text_len > avail_text_len && raw_text_len > 0
        scale = avail_text_len / raw_text_len.to_f
        font_h = font_h * scale
      end

      # Ước tính chiều dài text dòng 1 và dòng 2 sau khi scale
      char_w = font_h * 0.58
      len_text1 = full_title.length * char_w
      len_text2 = brand_str.length * (char_w * 0.75)
      max_text_len = [len_text1, len_text2].max

      # Chiều dài trục mũi tên bao quanh text
      arrow_len = max_text_len + 28.mm
      if (diamond_w + 4.mm + arrow_len) > max_allowed_len && max_allowed_len > 100.mm
        arrow_len = max_allowed_len - diamond_w - 4.mm
      end

      total_label_len = diamond_w + 4.mm + arrow_len

      # 4. TÍNH TOÁN CỤM NHÃN 3D CHUẨN ABF 100%:
      # - Đầu dưới (-Y): Mũi tam giác cân rỗng chĩa xuống
      # - Trục đường thẳng
      # - Đầu trên (+Y): Hình thoi chứa số ID căn giữa hoàn hảo
      # - Hai dòng chữ bên phải trục (Font Arial sắc nét, không bết đen)
      half_total = total_label_len / 2.0
      p_bottom = center.offset(grain_u, -half_total).offset(normal, 0.35.mm)
      p_top    = center.offset(grain_u, half_total).offset(normal, 0.35.mm)

      model = Sketchup.active_model
      tag_label = model.layers[LAYER_NAME] || model.layers.add(LAYER_NAME)

      label_grp = ents.add_group
      label_grp.name = "Chill_AI_Label_P#{id_num}"
      label_grp.layer = tag_label

      # A. Vẽ Mũi Tam Giác Cân Rỗng ở đầu dưới chĩa xuống dưới (Chuẩn ABF)
      tri_w = 20.mm
      tri_h = 16.mm
      p_base = p_bottom.offset(grain_u, tri_h)
      b1 = p_base.offset(grain_v, -tri_w / 2.0)
      b2 = p_base.offset(grain_v, tri_w / 2.0)

      label_grp.entities.add_line(b1, b2)
      label_grp.entities.add_line(b2, p_bottom)
      label_grp.entities.add_line(p_bottom, b1)

      # B. Vẽ Hình Thoi (Diamond Tag) ở đầu trên (Chuẩn ABF)
      diamond_center = p_top.offset(grain_u, -diamond_ry)
      diamond_bottom = diamond_center.offset(grain_u, -diamond_ry)
      diamond_top    = diamond_center.offset(grain_u, diamond_ry)
      diamond_left   = diamond_center.offset(grain_v, diamond_rx)
      diamond_right  = diamond_center.offset(grain_v, -diamond_rx)

      label_grp.entities.add_line(diamond_bottom, diamond_left)
      label_grp.entities.add_line(diamond_left, diamond_top)
      label_grp.entities.add_line(diamond_top, diamond_right)
      label_grp.entities.add_line(diamond_right, diamond_bottom)

      # C. Vẽ Số ID vào giữa hình thoi
      v_right = grain_v.reverse
      if cfg["show_id"]
        id_str = id_num.to_s
        id_font_h = 14.mm
        char_w = id_font_h * 0.55
        offset_u = - (id_str.length * char_w) / 2.0
        id_origin = diamond_center.offset(grain_u, offset_u).offset(v_right, id_font_h * 0.40)
        draw_flat_3d_text(label_grp.entities, id_str, id_origin, grain_u, grain_v, normal, id_font_h, false, false)
      end

      # D. Trục đường thẳng nối từ đáy tam giác dưới lên đỉnh dưới hình thoi
      label_grp.entities.add_line(p_base, diamond_bottom)

      # E. Hai dòng chữ nằm bên phải trục đường thẳng (Chuẩn ABF 100%)
      text_origin = p_base.offset(grain_u, 4.mm).offset(v_right, 4.mm + font_h)
      if cfg["show_name"]
        draw_flat_3d_text(label_grp.entities, full_title, text_origin, grain_u, grain_v, normal, font_h, false, false)
      end

      if cfg["show_brand"] && !brand_str.empty?
        brand_h = font_h * 0.72
        brand_origin = text_origin.offset(v_right, 4.mm + brand_h)
        draw_flat_3d_text(label_grp.entities, brand_str, brand_origin, grain_u, grain_v, normal, brand_h, false, false)
      end
    end

    # Vẽ nhãn 2D trên chi tiết trải phẳng Nesting (Chuẩn DXF ABF)
        # ==============================================================================
    # VẼ NHÃN 2D TRÊN CHI TIẾT TRẢI PHẲNG NESTING (CHUẨN ABF DXF 100%)
    # - Đầu trên (+Y): Hình thoi rỗng chứa số ID căn giữa, chữ xoay theo hướng đọc
    # - Đầu dưới (-Y): Mũi tam giác cân rỗng chĩa xuống (-Y)
    # - Đoạn trục thẳng: Nối từ đỉnh dưới hình thoi xuống đáy mũi tam giác
    # - Hai dòng chữ: Nằm hoàn toàn bên trái đường trục, đỉnh chữ quay vào trục,
    #   chân chữ quay ra ngoài, khoảng hở 3mm chống đè lên trục tuyệt đối!
    # ==============================================================================
    def self.draw_2d_nested_label(entities, center, grain_u, grain_v, normal, panel_len, panel_w, id_num, part_code, full_title, brand_str, cfg)
      # Kích thước chuẩn ABF: Chữ to rõ, không co dúm khi zoom xa
      font_h1 = 15.5.mm
      font_h1 = [font_h1, (panel_w * 0.12).mm].min if panel_w < 120.0
      font_h2 = font_h1 * 0.75

      diamond_rx = 18.mm
      diamond_ry = 18.mm

      tri_w = 26.mm
      tri_h = 18.mm

      raw_text_len = full_title.length * (font_h1 * 0.58)
      max_allowed_len = (panel_len * 0.70).mm

      # Chiều dài trục thẳng bao quanh text dòng 1
      label_total_len = [raw_text_len + 42.mm, max_allowed_len].min
      label_total_len = [label_total_len, 140.mm].max

      half_total = label_total_len / 2.0

      label_grp = entities.add_group
      label_grp.name = "Chill_AI_Label_P#{id_num}"

      # Định hướng theo grain_u và grain_v (Trục dọc u_dir, trục ngang v_dir)
      u_dir = grain_u.clone
      u_dir.normalize! rescue nil
      v_dir = grain_v.clone
      v_dir.normalize! rescue nil
      norm_dir = normal.clone
      norm_dir.normalize! rescue nil

      # Điểm đầu dưới (-half_total theo u_dir)
      p_bottom = center.offset(u_dir, -half_total).offset(norm_dir, 0.25.mm)

      # Điểm đầu trên (+half_total theo u_dir)
      p_top = center.offset(u_dir, half_total).offset(norm_dir, 0.25.mm)

      # 1. Vẽ Mũi Tam GiAC Cân Rỗng ở đầu dưới chĩa xuống dưới (Chuẩn ABF)
      p_tri_base = p_bottom.offset(u_dir, tri_h)
      b1 = p_tri_base.offset(v_dir, -tri_w / 2.0)
      b2 = p_tri_base.offset(v_dir, tri_w / 2.0)

      label_grp.entities.add_line(b1, b2)
      label_grp.entities.add_line(b2, p_bottom)
      label_grp.entities.add_line(p_bottom, b1)

      # 2. Vẽ Hình Thoi (Diamond Tag) ở đầu trên (Chuẩn ABF)
      diamond_center = p_top.offset(u_dir, -diamond_ry)
      diamond_bottom = diamond_center.offset(u_dir, -diamond_ry)
      diamond_top    = diamond_center.offset(u_dir, diamond_ry)
      diamond_left   = diamond_center.offset(v_dir, diamond_rx)
      diamond_right  = diamond_center.offset(v_dir, -diamond_rx)

      label_grp.entities.add_line(diamond_bottom, diamond_left)
      label_grp.entities.add_line(diamond_left, diamond_top)
      label_grp.entities.add_line(diamond_top, diamond_right)
      label_grp.entities.add_line(diamond_right, diamond_bottom)

      # 3. Trục đường thẳng nối từ đáy tam giác dưới lên đỉnh dưới hình thoi
      label_grp.entities.add_line(p_tri_base, diamond_bottom)

      # 4. HỆ TRỤC TOẠ ĐỘ THUẬN (RIGHT-HANDED SYSTEM) CHUẨN ABF / CAD 100%:
      # - Chữ đọc từ dưới (+u_dir) chạy lên trên hướng về phía hình thoi
      # - Trục dọc dòng chữ text_x_vec = u_dir (hướng +Y)
      # - Chiều cao con chữ text_y_vec = v_dir (hướng -X, vươn sang trái ra xa đường trục)
      # - Tích có hướng: text_x_vec x text_y_vec = (0, 1, 0) x (-1, 0, 0) = (0, 0, 1) = norm_dir (+Z)
      # - Ma trận định thức +1 TUYỆT ĐỐI -> Mặt chữ ngửa lên trên phẳng phiu, KHÔNG BẾT ĐEN!
      text_x_vec = u_dir
      text_y_vec = v_dir

      # 5. Vẽ Số ID vào giữa hình thoi (Căn giữa tâm hoàn hảo chuẩn ABF)
      id_str = id_num.to_s
      id_font_h = 16.0.mm
      id_char_w = id_font_h * 0.55
      id_total_w = id_str.length * id_char_w
      # Điểm đặt chân số ID sao cho tâm số trùng đúng tâm hình thoi theo hệ trục thuận
      id_origin = diamond_center.offset(text_x_vec, -id_total_w / 2.0).offset(text_y_vec, -id_font_h * 0.38)
      draw_flat_3d_text(label_grp.entities, id_str, id_origin, text_x_vec, text_y_vec, norm_dir, id_font_h, false, false)

      # 6. Hai dòng chữ nằm hoàn toàn bên trái đường trục (về phía v_dir)
      # Chân chữ tựa cách đường trục đúng 3.5mm, đọc từ dưới lên trên (+Y)
      gap_to_axis = 3.5.mm
      line1_origin = p_tri_base.offset(text_x_vec, 6.0.mm).offset(v_dir, gap_to_axis)
      draw_flat_3d_text(label_grp.entities, full_title, line1_origin, text_x_vec, text_y_vec, norm_dir, font_h1, false, false)

      # Dòng 2: Tên xưởng (nằm song song bên trái dòng 1, cách đỉnh dòng 1 một khoảng thoáng đãng)
      if !brand_str.to_s.strip.empty?
        gap_between_lines = 3.5.mm
        line2_origin = p_tri_base.offset(text_x_vec, 12.0.mm).offset(v_dir, gap_to_axis + font_h1 + gap_between_lines)
        draw_flat_3d_text(label_grp.entities, brand_str, line2_origin, text_x_vec, text_y_vec, norm_dir, font_h2, false, false)
      end
    end

    # ==============================================================================
    # VẼ TEXT 3D PHẲNG CHUẨN ABF (KHÔNG EXTENSION, KHÔNG LEM MỰC, TỌA ĐỘ CHUẨN XÁC)
    # ==============================================================================
    def self.draw_flat_3d_text(entities, text, origin, u_vec, v_vec, normal, letter_h, is_bold = false, is_italic = false)
      return if text.to_s.empty?
      grp = entities.add_group
      # add_3d_text tạo chữ phẳng màu đen trên mặt phẳng XY cục bộ
      grp.entities.add_3d_text(text, TextAlignLeft, "Arial", is_bold, is_italic, letter_h, 0.0, 0.0, false, 0.0)
      
      model = entities.model rescue Sketchup.active_model
      tag_label = model.layers["CHILL_AI_LABELS"] || model.layers.add("CHILL_AI_LABELS") rescue nil
      grp.layer = tag_label if tag_label

      # Cú pháp chuẩn SketchUp API: Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
      z_lift = normal.clone
      z_lift.length = 0.25.mm
      t = Geom::Transformation.axes(origin.offset(z_lift), u_vec, v_vec, normal)
      grp.transform!(t)
      grp
    end

    # Phân giải đối tượng được chọn về đúng tấm ván (kể cả khi người dùng click vào nhãn 3D, rãnh ngàm hay face/edge)
    def self.resolve_to_panel(entity)
      return nil unless entity && entity.valid?

      cur = entity
      4.times do
        break if is_leaf_panel(cur)
        if cur.respond_to?(:parent) && cur.parent.is_a?(Sketchup::ComponentDefinition)
          insts = cur.parent.instances
          if insts && !insts.empty?
            cur = insts.first
            next
          end
        end
        break
      end

      is_leaf_panel(cur) ? cur : entity
    end

    # Kiểm tra xem một đối tượng có phải là tấm ván đơn (Leaf Panel) hay không
    def self.is_leaf_panel(entity)
      return false unless entity && entity.valid?
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      name = entity.name.to_s.strip
      defn_name = entity.respond_to?(:definition) ? entity.definition.name.to_s.strip : ""

      # Bỏ qua các group gia công kỹ thuật
      return false if name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i ||
                      defn_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i

      # 1. Đã có thuộc tính nhận diện tấm ván Chill AI hoặc ABF
      return true if entity.get_attribute("Chill_AI_CNC", "label_id") || 
                     entity.get_attribute("Chill_AI_CNC", "id_number") ||
                     entity.get_attribute("Chill_AI_CNC", "part_name") ||
                     entity.get_attribute("abf_part", "id") ||
                     entity.get_attribute("ABF_ATTRIBUTES", "part_name")

      # 2. Nhận diện qua tên có chứa mã định danh tấm ván [P01], [P1]...
      return true if name =~ /\[P\d+\]/i || defn_name =~ /\[P\d+\]/i

      # 3. Kiểm tra hình học: Tấm ván phải chứa ít nhất 1 Face
      defn = entity.respond_to?(:definition) ? entity.definition : (entity.entities.parent rescue nil)
      sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : (defn ? defn.entities : [])
      faces = sub_ents.grep(Sketchup::Face)
      return false if faces.empty?

      # Kích thước chuẩn ván mộc (Dày <= 65mm, Dài >= 30mm, Rộng >= 30mm)
      bb = (defn && defn.respond_to?(:bounds)) ? defn.bounds : entity.bounds
      dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
      t = dims[0]
      w = dims[1]
      l = dims[2]

      t > 0 && t <= 65.0 && l >= 30.0 && w >= 30.0
    end

    # Thu thập các tấm ván lá mộc (Kèm ma trận biến đổi thế giới World Transformation)
    def self.collect_leaf_panels(entity, list, parent_trans = Geom::Transformation.new)
      return unless entity && entity.valid?

      resolved_ent = resolve_to_panel(entity)
      return unless resolved_ent && resolved_ent.valid?

      current_trans = parent_trans * (resolved_ent.respond_to?(:transformation) ? resolved_ent.transformation : Geom::Transformation.new)

      if is_leaf_panel(resolved_ent)
        bb = resolved_ent.bounds
        dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
        t = dims[0]
        w = dims[1]
        l = dims[2]
        name = resolved_ent.name.to_s.strip
        name = resolved_ent.definition.name.to_s.strip if name.empty? && resolved_ent.respond_to?(:definition)

        unless list.any? { |item| item[:entity] == resolved_ent }
          list << { entity: resolved_ent, original_name: name, l: l, w: w, t: t, world_trans: current_trans }
        end
      else
        # Là cụm lắp ráp cha (Assembly / Cabinet / Module), duyệt đệ quy các đối tượng con
        sub_ents = resolved_ent.is_a?(Sketchup::Group) ? resolved_ent.entities : (resolved_ent.respond_to?(:definition) ? resolved_ent.definition.entities : [])
        sub_ents.each do |child|
          if child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance)
            c_name = child.name.to_s
            c_def_name = child.respond_to?(:definition) ? child.definition.name.to_s : ""
            next if c_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i ||
                    c_def_name =~ /^(Chill_AI_Label|_ABF_|ABF_|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i
            collect_leaf_panels(child, list, current_trans)
          end
        end
      end
    end

    # Làm sạch tên cũ để chống bị lặp [P01] [P02] hoặc kích thước lặp
    def self.clean_raw_name(raw_name)
      str = raw_name.to_s.strip
      # Xóa các tiền tố [P01], [P02] lặp lại
      str = str.gsub(/\[P\d+\]\s*/i, '').strip
      # Xóa định dạng tiền tố rác ABF cũ: === 1. ___ 1. ___ 1. hoặc === ... ===>
      str = str.gsub(/^===+\s*(\d+\.\s*(_+\s*)*)*/, '').strip
      str = str.gsub(/===+>\s*$/, '').strip
      str = str.gsub(/^===+.*?===+>\s*/, '').strip
      # Xóa chuỗi kích thước cũ ở đuôi (ví dụ: (1529x577x17) hoặc (1529 x 577 x 17))
      str = str.gsub(/\(\s*\d+(\.\d+)?\s*[xX*]\s*\d+(\.\d+)?\s*[xX*]\s*\d+(\.\d+)?\s*\)\s*/i, '').strip
      str.strip
    end

    def self.infer_panel_name(part_info)
      bb = part_info[:entity].bounds
      t = part_info[:t]
      dz = bb.depth.to_mm.round(1)
      dx = bb.width.to_mm.round(1)
      dy = bb.height.to_mm.round(1)

      if dz == t
        if bb.min.z < 100.mm
          "Đáy ván"
        elsif bb.max.z > 1800.mm
          "Đỉnh nóc"
        else
          "Đợt ngang"
        end
      elsif dx == t
        "Hồi đứng"
      elsif dy == t
        if t <= 10.0
          "Hậu ván mỏng"
        elsif part_info[:l] > 500 && part_info[:w] > 300
          "Cánh tủ"
        else
          "Yếm ngăn kéo"
        end
      else
        "Tấm ván"
      end
    end

    def self.clean_label_groups_recursive(group)
      count = 0
      group.entities.grep(Sketchup::Group).each do |g|
        if g.name =~ /^Chill_AI_Label/i
          g.erase! rescue nil
          count += 1
        else
          count += clean_label_groups_recursive(g)
        end
      end
      count
    end
  end
end
