# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Rename Engine (Chuyên Gia Đổi Tên Tấm Ván & Cụm Module Chuẩn ABF)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module RenameEngine
    PRESET_FILE = File.join(File.dirname(__FILE__), '..', 'knowledge_base', 'rename_presets.json')

    # Danh sách Preset mặc định chuẩn xưởng anh Huy (khớp 100% hình ảnh thực tế)
    DEFAULT_PRESETS = {
      "Huy" => {
        "modules" => [
          "_Giường_", "_Tủ Áo_", "_Bếp_",
          "_Tủ Giày_", "_Kệ TV_", "_Tủ Cầu Thang_",
          "_Tủ Lavabo_", "_Bàn Học_", "_Kệ Sách_",
          "_Tủ Trang Trí_", "_Ốp Tường_", "_Bàn Trang Điểm_"
        ],
        "parts" => [
          # Cột 1
          "_H1_", "_H4_", "_Đáy_", "_Sấn Giữa_", "_Len Chân_", "_Hậu_", "1", "4", "7", "10",
          "_Cánh Mở_", "_NK_", "Phải", "_Đáy NK_", "_Thanh Gia Giảm_", "Xà Sau_", "Thùng Ngăn Kéo_",
          # Cột 2
          "_H2_", "_H5_", "_Hông Trái_", "_Đáy_", "_Len Chân Giữa_", "_Hậu Trước_", "2", "5", "8",
          "_Xương Cong_", "_Cánh Lùa_", "_Thành_", "Trước", "_Chỉ Nóc_", "_Thanh Chặn_", "Xà Trước_",
          # Cột 3
          "_H3_", "_Nóc_", "_Hông Phải_", "_Đợt_", "_Len Chân Sau_", "_Nóc_", "3", "6", "9",
          "_Cánh NK_", "Cánh Chết", "Trái", "Sau", "Chỉ Hông_", "_Trang Trí Ông Táo_", "Thanh Gắn Lề_"
        ]
      }
    }

    # 1. LẤY & LƯU BỘ PRESETS TỪ FILE
    def self.get_presets
      if File.exist?(PRESET_FILE)
        begin
          data = JSON.parse(File.read(PRESET_FILE, encoding: 'utf-8'))
          return data if data.is_a?(Hash) && !data.empty?
        rescue => e
          puts "[Chill AI RenameEngine] Lỗi đọc preset: #{e.message}"
        end
      end
      DEFAULT_PRESETS
    end

    def self.save_presets(presets_data)
      dir = File.dirname(PRESET_FILE)
      Dir.mkdir(dir) unless Dir.exist?(dir)
      File.open(PRESET_FILE, 'w:utf-8') do |f|
        f.write(JSON.pretty_generate(presets_data))
      end
      { "status" => "success", "message" => "Đã lưu bộ preset thành công!" }
    rescue => e
      { "status" => "error", "message" => e.message }
    end

    # 2. ÁP DỤNG ĐỔI TÊN ĐẦY ĐỦ (THEO FORM: Code N1, N2, N3, Tiền tố, Hậu tố, Số thứ tự)
    def self.rename_selection(params)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      selection_only = params.key?('selection_only') ? params['selection_only'] : true
      if selection_only && (model.selection.nil? || model.selection.empty?)
        return { "status" => "warning", "message" => "Vui lòng kích chọn ít nhất 1 tấm ván hoặc module trong SketchUp!" }
      end

      targets = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      code1 = params['code_n1'].to_s.strip
      code2 = params['code_n2'].to_s.strip
      code3 = params['code_n3'].to_s.strip
      base_name = params['part_name'].to_s.strip
      prefix = params['prefix'].to_s.strip
      suffix = params['suffix'].to_s.strip
      auto_index = params['auto_index'] ? true : false
      start_index = (params['start_index'] || 1).to_i

      model.start_operation("Chill AI - Đổi Tên Chuẩn ABF", true)
      begin
        renamed_count = 0
        current_idx = start_index

        targets.each do |ent|
          next unless ent && ent.valid?

          # Trường hợp A: Đối tượng là tấm ván đơn lẻ (Leaf Panel)
          if defined?(LabelingEngine) && LabelingEngine.is_leaf_panel(ent)
            resolved = LabelingEngine.resolve_to_panel(ent) || ent
            name_core = base_name.empty? ? resolved.name.to_s.strip : base_name
            name_core = LabelingEngine.clean_raw_name(name_core) if defined?(LabelingEngine)
            name_core = clean_copy_tag(name_core)

            final_name = build_full_name(prefix, code1, code2, code3, name_core, auto_index ? current_idx : nil, suffix)
            apply_name_to_entity(resolved, final_name, false)
            renamed_count += 1
            current_idx += 1 if auto_index

          # Trường hợp B: Đối tượng là cụm Module cha (chứa các tấm con bên trong)
          elsif is_module_assembly(ent)
            # 1. Đổi tên cho cụm Module cha
            module_base = base_name.empty? ? ent.name.to_s.strip : base_name
            module_base = clean_copy_tag(module_base)
            module_full_name = build_full_name(prefix, code1, code2, code3, module_base, nil, suffix)
            apply_name_to_entity(ent, module_full_name, true)
            renamed_count += 1

            # 2. Đồng thời cập nhật nhãn và tên cho toàn bộ các tấm con bên trong cụm tủ
            leaf_parts = []
            LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
            leaf_parts.each do |p|
              child_ent = p[:entity]
              next unless child_ent && child_ent.valid?

              child_core = base_name.empty? ? p[:original_name] : base_name
              child_core = LabelingEngine.clean_raw_name(child_core) if defined?(LabelingEngine)
              child_core = clean_copy_tag(child_core)

              # Ghép tên chuẩn ABF: [CodeN1]_[CodeN2]_[Tên tấm]_[Số thứ tự]
              child_full_name = build_full_name(prefix, code1, code2, code3, child_core, auto_index ? current_idx : nil, suffix)
              apply_name_to_entity(child_ent, child_full_name, false, p)
              current_idx += 1 if auto_index
            end

          # Trường hợp C: Đối tượng khác
          else
            leaf_parts = []
            LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
            if leaf_parts.empty?
              final_name = build_full_name(prefix, code1, code2, code3, base_name.empty? ? ent.name : base_name, auto_index ? current_idx : nil, suffix)
              apply_name_to_entity(ent, final_name, false)
              renamed_count += 1
              current_idx += 1 if auto_index
            else
              leaf_parts.each do |p|
                child_ent = p[:entity]
                next unless child_ent && child_ent.valid?
                child_core = base_name.empty? ? p[:original_name] : base_name
                child_core = LabelingEngine.clean_raw_name(child_core) if defined?(LabelingEngine)
                child_full_name = build_full_name(prefix, code1, code2, code3, child_core, auto_index ? current_idx : nil, suffix)
                apply_name_to_entity(child_ent, child_full_name, false, p)
                renamed_count += 1
                current_idx += 1 if auto_index
              end
            end
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã đổi tên và cập nhật nhãn 3D cho #{renamed_count} đối tượng!"
        {
          "status" => "success",
          "message" => "Đã đổi tên và cập nhật nhãn 3D thành công cho #{renamed_count} đối tượng!",
          "count" => renamed_count
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Rename Error]: #{e.message}
#{e.backtrace.join("
")}"
        { "status" => "error", "message" => e.message }
      end
    end

    # 3. GÁN NHANH TỪ 1 CLICK TRÊN BẢNG NÚT (MODULE HOẶC TẤM VÁN)
    def self.apply_quick_name(quick_name, is_module = false, auto_index = false, extra_params = {})
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      if model.selection.nil? || model.selection.empty?
        return { "status" => "warning", "message" => "Vui lòng kích chọn tấm ván hoặc module trong SketchUp trước khi bấm nút tên!" }
      end

      targets = model.selection.to_a
      code1 = extra_params['code_n1'].to_s.strip
      code2 = extra_params['code_n2'].to_s.strip
      code3 = extra_params['code_n3'].to_s.strip
      prefix = extra_params['prefix'].to_s.strip
      suffix = extra_params['suffix'].to_s.strip

      model.start_operation("Chill AI - Gán Nhanh Tên #{quick_name}", true)
      begin
        renamed_count = 0
        idx = 1

        targets.each do |ent|
          next unless ent && ent.valid?

          # Nếu đang chọn 1 tấm ván đơn lẻ (dù bấm nút Module hay Part, đều gán tên và vẽ nhãn cho tấm ván này)
          if defined?(LabelingEngine) && LabelingEngine.is_leaf_panel(ent)
            resolved = LabelingEngine.resolve_to_panel(ent) || ent
            final_name = build_full_name(prefix, code1, code2, code3, quick_name, auto_index ? idx : nil, suffix)
            apply_name_to_entity(resolved, final_name, false)
            renamed_count += 1
            idx += 1

          # Nếu đang chọn Cụm Module cha
          elsif is_module_assembly(ent)
            if is_module
              # Gán tên cho Module cha
              mod_full_name = build_full_name(prefix, code1, code2, code3, quick_name, nil, suffix)
              apply_name_to_entity(ent, mod_full_name, true)
              renamed_count += 1

              # Đồng thời cập nhật nhãn cho tất cả tấm con bên trong
              leaf_parts = []
              LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
              leaf_parts.each do |p|
                c_ent = p[:entity]
                next unless c_ent && c_ent.valid?
                c_name = p[:original_name]
                c_name = LabelingEngine.clean_raw_name(c_name) if defined?(LabelingEngine)
                c_full = build_full_name(prefix, code1, code2, quick_name, c_name, nil, suffix)
                apply_name_to_entity(c_ent, c_full, false, p)
              end
            else
              # Bấm nút tên tấm ván khi đang chọn cụm: gán tên chi tiết cho các tấm con
              leaf_parts = []
              LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
              leaf_parts.each do |p|
                c_ent = p[:entity]
                next unless c_ent && c_ent.valid?
                c_full = build_full_name(prefix, code1, code2, code3, quick_name, auto_index ? idx : nil, suffix)
                apply_name_to_entity(c_ent, c_full, false, p)
                renamed_count += 1
                idx += 1
              end
            end

          # Đối tượng chung khác
          else
            leaf_parts = []
            LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
            if leaf_parts.empty?
              final_name = build_full_name(prefix, code1, code2, code3, quick_name, auto_index ? idx : nil, suffix)
              apply_name_to_entity(ent, final_name, false)
              renamed_count += 1
              idx += 1
            else
              leaf_parts.each do |p|
                c_ent = p[:entity]
                next unless c_ent && c_ent.valid?
                final_name = build_full_name(prefix, code1, code2, code3, quick_name, auto_index ? idx : nil, suffix)
                apply_name_to_entity(c_ent, final_name, false, p)
                renamed_count += 1
                idx += 1
              end
            end
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã gán tên '#{quick_name}' và cập nhật nhãn 3D cho #{renamed_count} đối tượng!"
        {
          "status" => "success",
          "message" => "Đã gán tên '#{quick_name}' và cập nhật nhãn 3D cho #{renamed_count} đối tượng thành công!",
          "count" => renamed_count,
          "name" => quick_name
        }
      rescue => e
        model.abort_operation
        puts "[Chill AI Quick Name Error]: #{e.message}
#{e.backtrace.join("
")}"
        { "status" => "error", "message" => e.message }
      end
    end

    # 4. TÌM KIẾM VÀ THAY THẾ CHUỖI TRONG TÊN (REPLACE)
    def self.replace_text(find_str, replace_str, selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model
      return { "status" => "warning", "message" => "Chuỗi tìm kiếm không được để trống!" } if find_str.to_s.empty?

      targets = (selection_only && model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Thay Thế Tên: #{find_str} -> #{replace_str}", true)
      begin
        replaced_count = 0
        targets.each do |ent|
          leaf_parts = []
          LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
          list = leaf_parts.empty? ? [ent] : leaf_parts.map { |p| p[:entity] }
          list << ent if is_module_assembly(ent)

          list.uniq.each do |target_ent|
            next unless target_ent && target_ent.valid?
            cur_name = target_ent.name.to_s
            cur_def = target_ent.respond_to?(:definition) ? target_ent.definition.name.to_s : ""

            if cur_name.include?(find_str) || cur_def.include?(find_str)
              new_name = cur_name.gsub(find_str, replace_str)
              apply_name_to_entity(target_ent, new_name, is_module_assembly(target_ent))
              replaced_count += 1
            end
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã thay thế '#{find_str}' -> '#{replace_str}' cho #{replaced_count} đối tượng!"
        {
          "status" => "success",
          "message" => "Đã thay thế '#{find_str}' bằng '#{replace_str}' cho #{replaced_count} đối tượng!",
          "count" => replaced_count
        }
      rescue => e
        model.abort_operation
        { "status" => "error", "message" => e.message }
      end
    end

    # 5. XÓA HẬU TỐ COPY CỦA SKETCHUP (#1, #2, #3, _copy...)
    def self.clean_copy_names(selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      targets = (selection_only && model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Xóa Hậu Tố Copy #1 #2", true)
      begin
        cleaned_count = 0
        targets.each do |ent|
          leaf_parts = []
          LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
          list = leaf_parts.empty? ? [ent] : leaf_parts.map { |p| p[:entity] }
          list << ent if is_module_assembly(ent)

          list.uniq.each do |target_ent|
            next unless target_ent && target_ent.valid?
            cur_name = target_ent.name.to_s
            cleaned = clean_copy_tag(cur_name)
            if cleaned != cur_name
              apply_name_to_entity(target_ent, cleaned, is_module_assembly(target_ent))
              cleaned_count += 1
            end
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã xóa hậu tố copy (#1, #2, _copy) cho #{cleaned_count} đối tượng!"
        {
          "status" => "success",
          "message" => "Đã xóa sạch hậu tố copy (#1, #2, _copy) cho #{cleaned_count} đối tượng!",
          "count" => cleaned_count
        }
      rescue => e
        model.abort_operation
        { "status" => "error", "message" => e.message }
      end
    end

    # 6. XÓA ID CŨ ([P01], [P02]...) ĐỂ ĐÁNH SỐ LẠI
    def self.clear_part_ids(selection_only = true)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      targets = (selection_only && model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a

      model.start_operation("Chill AI - Xóa Tiền Tố ID [P01]", true)
      begin
        cleared_count = 0
        targets.each do |ent|
          leaf_parts = []
          LabelingEngine.collect_leaf_panels(ent, leaf_parts) if defined?(LabelingEngine)
          list = leaf_parts.empty? ? [ent] : leaf_parts.map { |p| p[:entity] }

          list.uniq.each do |target_ent|
            next unless target_ent && target_ent.valid?
            target_ent.delete_attribute("Chill_AI_CNC", "label_id")
            target_ent.delete_attribute("Chill_AI_CNC", "id_number")

            cur_name = target_ent.name.to_s
            cleaned = LabelingEngine.clean_raw_name(cur_name) if defined?(LabelingEngine)
            cleaned ||= cur_name.gsub(/\[P\d+\]\s*/i, '').strip

            if cleaned != cur_name
              apply_name_to_entity(target_ent, cleaned, false)
              cleared_count += 1
            end
          end
        end

        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã xóa mã ID [P01]... cho #{cleared_count} tấm ván!"
        {
          "status" => "success",
          "message" => "Đã xóa sạch mã ID [P01]... cho #{cleared_count} tấm ván để sẵn sàng đánh số mới!",
          "count" => cleared_count
        }
      rescue => e
        model.abort_operation
        { "status" => "error", "message" => e.message }
      end
    end

    # --- HÀM TRỢ GIÚP NỘI BỘ ---

    # Xây dựng chuỗi tên hoàn chỉnh theo chuẩn ABF
    def self.build_full_name(prefix, code1, code2, code3, name_core, index_num = nil, suffix = nil)
      arr = []
      arr << prefix.to_s.strip unless prefix.to_s.strip.empty?
      arr << code1.to_s.strip unless code1.to_s.strip.empty?
      arr << code2.to_s.strip unless code2.to_s.strip.empty?
      arr << code3.to_s.strip unless code3.to_s.strip.empty?

      core = name_core.to_s.strip
      arr << core unless core.empty?
      arr << index_num.to_s if index_num
      arr << suffix.to_s.strip unless suffix.to_s.strip.empty?

      res = arr.join("_").gsub(/__+/, "_").strip
      res.gsub(/^_|_$/, "") if res =~ /^_[^_]+_$/
      res
    end

    # Gán tên cho Entity, đồng thời đồng bộ Definition và VẼ LẠI NHÃN 3D TỨC THÌ
    def self.apply_name_to_entity(target_ent, new_name, is_module = false, part_info = nil)
      return unless target_ent && target_ent.valid?
      clean_n = new_name.to_s.strip
      return if clean_n.empty?

      target_ent.name = clean_n
      if target_ent.respond_to?(:definition) && target_ent.definition
        target_ent.definition.name = clean_n rescue nil
      end

      # Lưu vào thuộc tính Chill_AI_CNC
      if is_module
        target_ent.set_attribute("Chill_AI_CNC", "module_name", clean_n)
      else
        target_ent.set_attribute("Chill_AI_CNC", "part_name", clean_n)
      end

      # 🌟 QUAN TRỌNG NHẤT: Luôn cập nhật hoặc vẽ nhãn 3D hiển thị ngay lập tức trên tấm ván!
      refresh_or_draw_label(target_ent, clean_n, part_info) unless is_module
    end

    # Cập nhật hoặc Dán nhãn 3D mới sắc nét trên tấm ván với tên mới
    def self.refresh_or_draw_label(target_ent, new_part_name, part_info = nil)
      return unless defined?(LabelingEngine)
      return unless target_ent && target_ent.valid?

      # Lấy thông số nhãn hiện tại
      id_num = target_ent.get_attribute("Chill_AI_CNC", "id_number") || 1
      part_code = target_ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)
      grain_angle = (target_ent.get_attribute("Chill_AI_CNC", "grain_angle") || 0.0).to_f
      grain_mode = target_ent.get_attribute("Chill_AI_CNC", "grain") || "length"

      cfg = LabelingEngine.get_config.dup
      cfg["grain_angle"] = grain_angle
      cfg["grain_mode"] = grain_mode

      # Tạo part_info nếu chưa có
      if part_info.nil?
        bb = target_ent.bounds
        dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
        part_info = {
          entity: target_ent,
          original_name: new_part_name,
          l: dims[2],
          w: dims[1],
          t: dims[0],
          world_trans: target_ent.transformation
        }
      end

      # Cập nhật tên Outliner chuẩn mộc
      dim_str = "#{part_info[:l].to_i}x#{part_info[:w].to_i}x#{part_info[:t].to_i}"
      target_ent.name = "[#{part_code}] #{new_part_name} (#{dim_str})"

      # Vẽ đè nhãn mới với tên cập nhật (xóa sạch nhãn cũ và hiện tên mới ngay lập tức)
      LabelingEngine.draw_visual_label(target_ent, part_info, id_num, part_code, new_part_name, cfg)
    rescue => e
      puts "[Chill AI Rename Label Refresh Warn]: #{e.message}"
    end

    # Kiểm tra xem đối tượng có phải cụm module cha hay không
    def self.is_module_assembly(entity)
      return false unless entity && entity.valid?
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      return false if LabelingEngine.is_leaf_panel(entity) if defined?(LabelingEngine)

      sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      has_children = sub_ents.any? { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      has_children
    end

    # Xóa các thẻ #1, #2, _copy, (1)...
    def self.clean_copy_tag(str)
      s = str.to_s
      s = s.gsub(/#\d+/i, '')
      s = s.gsub(/_copy\d*/i, '')
      s = s.gsub(/\(\d+\)/i, '')
      s = s.gsub(/\s\s+/, ' ')
      s.strip
    end
  end
end
