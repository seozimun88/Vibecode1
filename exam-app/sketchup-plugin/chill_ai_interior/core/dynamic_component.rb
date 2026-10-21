# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Dynamic Component Builder
# Tự động gán hàm thuộc tính động & logic co giãn thông minh cho SketchUp
# Hỗ trợ: Biến đối tượng đang chọn (Tủ áo, bàn, bếp...) thành Dynamic Component
# ==============================================================================

module ChillAIInterior
  module DynamicComponentBuilder
    DICT_NAME = 'dynamic_attributes'.freeze

    def self.build_and_attach(params = {})
      model = Sketchup.active_model
      return nil unless model

      # 1. KIỂM TRA XEM NGƯỜI DÙNG CÓ ĐANG CHỌN MÔ HÌNH TRÊN SKETCHUP KHÔNG
      # NẾU CÓ: BIẾN ĐỐI TƯỢNG ĐANG CHỌN ĐÓ THÀNH DYNAMIC COMPONENT!
      target = nil
      if params && params['entity_id']
        target = model.find_entity_by_id(params['entity_id'].to_i) rescue nil
      end
      if target.nil? || !target.valid?
        sel = model.selection
        target = sel.first if sel && sel.count > 0
      end

      if target && target.valid? && (target.is_a?(Sketchup::Group) || target.is_a?(Sketchup::ComponentInstance))
        return convert_to_dynamic_component(target, params)
      end

      # 2. NẾU KHÔNG CÓ ĐỐI TƯỢNG ĐƯỢC CHỌN: DỰNG MỚI THEO LOẠI NỘI THẤT
      type = (params['type'] || 'wardrobe').to_s.downcase
      if type.include?('tu') || type.include?('wardrobe') || type.include?('cabinet')
        return StructuralEngine.build_wardrobe_structural(params) rescue build_new_dynamic_desk(params)
      else
        return build_new_dynamic_desk(params)
      end
    end

    # --- CHUYỂN ĐỔI MỘT ĐỐI TƯỢNG ĐANG CHỌN TRÊN SKETCHUP THÀNH DYNAMIC COMPONENT ---
    def self.convert_to_dynamic_component(target, params = {})
      model = Sketchup.active_model
      return nil unless model && target && target.valid?

      model.start_operation("Chill AI: Tạo Dynamic Component Cho Đối Tượng", true)

      # 1. Nếu là Group, chuyển thành ComponentInstance
      instance = if target.is_a?(Sketchup::Group)
        target.to_component
      elsif target.is_a?(Sketchup::ComponentInstance)
        target
      else
        nil
      end

      return nil unless instance && instance.valid?

      # Tách riêng definition để không ảnh hưởng các bản sao khác
      instance.make_unique rescue nil
      comp_def = instance.definition

      # 2. Đặt tên chuẩn nhận diện
      raw_name = instance.name.to_s.strip
      raw_name = comp_def.name.to_s.strip if raw_name.empty?
      raw_name = params['name'].to_s.strip if (raw_name.empty? || raw_name == "Component") && params['name']
      raw_name = "Tủ Quần Áo Động Chill AI" if raw_name.empty?

      comp_def.name = raw_name
      instance.name = raw_name

      # 3. Đọc kích thước thực tế ngoài không gian vẽ
      bb = instance.bounds
      w_mm = bb.width.to_mm.round(1)
      h_mm = bb.height.to_mm.round(1)
      d_mm = bb.depth.to_mm.round(1)

      lenx_inch = bb.width.to_inch
      leny_inch = bb.height.to_inch
      lenz_inch = bb.depth.to_inch

      # 4. Gán thuộc tính cấp cha (Root Component Attributes)
      comp_def.set_attribute(DICT_NAME, '_formatversion', 1.0)
      comp_def.set_attribute(DICT_NAME, '_name', raw_name)
      comp_def.set_attribute(DICT_NAME, '_description', "Dynamic Component được tạo tự động bởi Chill AI. Tự co giãn theo kích thước thực tế.")

      setup_ui_attribute(comp_def, 'lenx', lenx_inch, 'Chiều Dài / Ngang (Length)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'leny', leny_inch, 'Chiều Sâu (Width)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'lenz', lenz_inch, 'Chiều Cao (Height)', 'MILLIMETERS')

      # Cảnh báo khổ ván CNC 2440mm
      is_over = (w_mm > 2440.0 || h_mm > 2440.0 || d_mm > 2440.0 || [w_mm, h_mm, d_mm].sort[1] > 1220.0)
      init_warning = is_over ? "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!" : "✅ ĐẠT CHUẨN CNC (1220x2440mm)"
      comp_def.set_attribute(DICT_NAME, 'canh_bao_kho_van', init_warning)
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_access', 'VIEW')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_label', 'Kiểm Tra Khổ Ván CNC')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_formlabel', 'Trạng Thái Khổ Ván')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_formula', 'IF(OR(LenX>96.06, LenY>96.06, LenZ>96.06), "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!", "✅ ĐẠT CHUẨN CNC (1220x2440mm)")')

      # 5. Gắn hàm OnClick mở cánh và kéo ngăn kéo cho các linh kiện con bên trong
      setup_interactive_subcomponents(comp_def)

      # 6. Gán cho instance nếu có dictionary
      inst_dict = instance.attribute_dictionary(DICT_NAME, true)
      inst_dict['lenx'] = lenx_inch
      inst_dict['leny'] = leny_inch
      inst_dict['lenz'] = lenz_inch
      inst_dict['canh_bao_kho_van'] = init_warning

      # Kích hoạt Dynamic Components Redraw
      redraw_dynamic_component(instance)

      # Chọn lại đối tượng để SketchUp refresh hộp thoại Component Options
      model.selection.clear
      model.selection.add(instance)

      model.commit_operation
      puts "[Chill AI] Đã chuyển đổi thành công #{raw_name} thành Dynamic Component!"
      instance
    end

    # Gắn hàm tương tác mở cánh góc 90 độ, kéo ngăn kéo và KHÓA CHIỀU DÀY TẤM VÁN TRÁNH MÉO CAO SU
    def self.setup_interactive_subcomponents(comp_def)
      sub_entities = comp_def.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      sub_entities.each do |sub|
        next unless sub.valid?
        sub_name = sub.name.to_s.strip
        sub_name = sub.definition.name.to_s.strip if sub_name.empty? && sub.respond_to?(:definition)
        sub_name_lower = sub_name.downcase

        sub_inst = sub.is_a?(Sketchup::Group) ? sub.to_component : sub
        next unless sub_inst && sub_inst.respond_to?(:definition)
        sub_def = sub_inst.definition

        # 1. Cánh tủ: Gán OnClick mở cánh góc 90 độ
        if sub_name_lower.include?('cánh') || sub_name_lower.include?('canh') || sub_name_lower.include?('door')
          is_right = sub_name_lower.include?('phải') || sub_name_lower.include?('phai') || sub_name_lower.include?('2') || sub_name_lower.include?('right')
          rot_deg = is_right ? 90 : -90
          sub_def.set_attribute(DICT_NAME, '_name', sub_name)
          sub_def.set_attribute(DICT_NAME, 'onclick', "ANIMATE(\"RotZ\", 0, #{rot_deg})")
          sub_def.set_attribute(DICT_NAME, 'rotz', 0.0)
          sub_def.set_attribute(DICT_NAME, '_scaletool', 0)
        # 2. Ngăn kéo: Gán OnClick trượt kéo ra ngoài
        elsif sub_name_lower.include?('ngăn kéo') || sub_name_lower.include?('ngan keo') || sub_name_lower.include?('drawer')
          sub_def.set_attribute(DICT_NAME, '_name', sub_name)
          sub_def.set_attribute(DICT_NAME, 'onclick', 'ANIMATE("Y", 0, -350)')
          sub_def.set_attribute(DICT_NAME, 'y', 0.0)
          sub_def.set_attribute(DICT_NAME, '_scaletool', 0)
        else
          # 3. Các tấm ván mộc thùng tủ: Khóa chiều dày ván tránh bị co giãn như cao su và chống vỡ mép
          bb = sub_inst.bounds
          dx = bb.width.to_mm.round(1)
          dy = bb.height.to_mm.round(1)
          dz = bb.depth.to_mm.round(1)
          min_dim = [dx, dy, dz].min
          if min_dim <= 45.0
            sub_def.set_attribute(DICT_NAME, '_name', sub_name)
            sub_def.set_attribute(DICT_NAME, '_scaletool', 0)
            thick_inch = min_dim.mm.to_inch.round(4)

            if min_dim == dx
              # Tấm đứng hồi tủ (độ dày nằm ở trục X)
              sub_def.set_attribute(DICT_NAME, '_lenx_formula', "#{thick_inch}")
              # Nếu là hồi phải: BẮT BUỘC gán X bám sát mép phải Parent!LenX - Parent!Thickness
              if sub_name_lower.include?('phải') || sub_name_lower.include?('phai') || sub_name_lower.include?('right') || sub_inst.transformation.origin.x.to_mm > 300.0
                sub_def.set_attribute(DICT_NAME, '_x_formula', "Parent!LenX - #{thick_inch}")
              else
                sub_def.set_attribute(DICT_NAME, '_x_formula', "0")
              end
            elsif min_dim == dy
              # Tấm hậu hoặc len chân (độ dày nằm ở trục Y)
              sub_def.set_attribute(DICT_NAME, '_leny_formula', "#{thick_inch}")
              sub_def.set_attribute(DICT_NAME, '_x_formula', "#{thick_inch}")
              sub_def.set_attribute(DICT_NAME, '_lenx_formula', "Parent!LenX - 2 * #{thick_inch}")
            else
              # Tấm đáy hoặc nóc (độ dày nằm ở trục Z)
              sub_def.set_attribute(DICT_NAME, '_lenz_formula', "#{thick_inch}")
              sub_def.set_attribute(DICT_NAME, '_x_formula', "#{thick_inch}")
              sub_def.set_attribute(DICT_NAME, '_lenx_formula', "Parent!LenX - 2 * #{thick_inch}")
              if sub_name_lower.include?('nóc') || sub_name_lower.include?('noc') || sub_name_lower.include?('top')
                sub_def.set_attribute(DICT_NAME, '_z_formula', "Parent!LenZ - #{thick_inch}")
              end
            end
          end
        end
      end
    rescue => e
      puts "[Chill AI] Lỗi setup subcomponents DC: #{e.message}"
    end

    # --- DỰNG MỚI BÀN LÀM VIỆC DYNAMIC NẾU KHÔNG CÓ ĐỐI TƯỢNG CHỌN ---
    def self.build_new_dynamic_desk(params)
      model = Sketchup.active_model
      model.start_operation("Chill AI: Tạo Bàn Dynamic Component", true)

      comp_name = "Chill_DC_Desk_#{Time.now.to_i}"
      comp_def = model.definitions.add(comp_name)

      l_mm = (params['length'] || 1200).to_f
      w_mm = (params['width']  || 600).to_f
      h_mm = (params['height'] || 750).to_f
      t_mm = (params['thickness'] || 18).to_f

      l_inch = l_mm / 25.4
      w_inch = w_mm / 25.4
      h_inch = h_mm / 25.4
      t_inch = t_mm / 25.4

      comp_def.set_attribute(DICT_NAME, '_formatversion', 1.0)
      comp_def.set_attribute(DICT_NAME, '_name', "Bàn Làm Việc Thông Minh Chill AI")
      comp_def.set_attribute(DICT_NAME, '_description', "Dynamic Component được tạo tự động bởi Chill AI. Tự co giãn theo kích thước thực tế.")

      setup_ui_attribute(comp_def, 'lenx', l_inch, 'Chiều Dài (Length)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'leny', w_inch, 'Chiều Rộng (Width)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'lenz', h_inch, 'Chiều Cao (Height)', 'MILLIMETERS')

      comp_def.set_attribute(DICT_NAME, 'canh_bao_kho_van', 'ĐẠT CHUẨN 1220x2440MM')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_access', 'VIEW')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_label', 'Kiểm Tra Khổ Ván CNC')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_formlabel', 'Trạng Thái Khổ Ván')
      comp_def.set_attribute(DICT_NAME, '_canh_bao_kho_van_formula', 'IF(OR(LenX>96.06, LenY>96.06, LenZ>96.06), "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!", "✅ ĐẠT CHUẨN CNC (1220x2440mm)")')

      ents = comp_def.entities

      mat_top_def = model.definitions.add("DC_Mat_Ban_#{Time.now.to_i}")
      mat_top_def.set_attribute(DICT_NAME, '_name', "Mặt Bàn")
      create_solid_box(mat_top_def.entities, l_inch, w_inch, t_inch)
      
      mat_top_def.set_attribute(DICT_NAME, '_lenx_formula', 'Parent!LenX')
      mat_top_def.set_attribute(DICT_NAME, '_leny_formula', 'Parent!LenY')
      mat_top_def.set_attribute(DICT_NAME, '_lenz_formula', 'Parent!Thickness')
      mat_top_def.set_attribute(DICT_NAME, '_z_formula', 'Parent!LenZ - Parent!Thickness')

      inst_top = ents.add_instance(mat_top_def, Geom::Transformation.translation([0, 0, (h_inch - t_inch)]))
      inst_top.name = "Mat_Ban_Dong"

      door_def = model.definitions.add("DC_Canh_Mo_#{Time.now.to_i}")
      door_def.set_attribute(DICT_NAME, '_name', "Cánh Tủ Động")
      create_solid_box(door_def.entities, l_inch * 0.4, 0.7, h_inch * 0.5)
      door_def.set_attribute(DICT_NAME, 'onclick', 'ANIMATE("RotZ", 0, 90)')
      door_def.set_attribute(DICT_NAME, 'rotz', 0.0)

      inst_door = ents.add_instance(door_def, Geom::Transformation.translation([1, 1, 2]))
      inst_door.name = "Canh_Mo_Interactive"

      instance = model.active_entities.add_instance(comp_def, Geom::Transformation.new)
      redraw_dynamic_component(instance)

      model.selection.clear
      model.selection.add(instance)

      model.commit_operation
      instance
    end

    def self.setup_ui_attribute(definition, attr_name, default_val, label, units = 'MILLIMETERS')
      definition.set_attribute(DICT_NAME, attr_name, default_val)
      definition.set_attribute(DICT_NAME, "_#{attr_name}_access", 'TEXTBOX')
      definition.set_attribute(DICT_NAME, "_#{attr_name}_label", label)
      definition.set_attribute(DICT_NAME, "_#{attr_name}_formlabel", label)
      definition.set_attribute(DICT_NAME, "_#{attr_name}_units", units)
    end

    def self.create_solid_box(entities, dx, dy, dz)
      pts = [
        [0, 0, 0],
        [dx, 0, 0],
        [dx, dy, 0],
        [0, dy, 0]
      ]
      face = entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)
    end

    def self.redraw_dynamic_component(instance)
      if defined?($dc_observers) && $dc_observers
        begin
          $dc_observers.get_latest_class.redraw_with_undo(instance)
        rescue => e
          puts "[Chill AI] Thông báo: Dynamic Components extension chưa sẵn sàng: #{e.message}"
        end
      end
    end
  end
end
