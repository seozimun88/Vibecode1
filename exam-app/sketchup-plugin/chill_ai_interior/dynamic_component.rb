# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Dynamic Component Builder
# Tự động gán hàm thuộc tính động & logic co giãn thông minh cho SketchUp
# ==============================================================================

module ChillAIInterior
  module DynamicComponentBuilder
    DICT_NAME = 'dynamic_attributes'.freeze

    def self.build_and_attach(params)
      model = Sketchup.active_model
      model.start_operation("Chill AI: Tạo Dynamic Component", true)

      # 1. Tạo component cha
      type = (params['type'] || 'desk').to_s.downcase
      comp_name = "Chill_DC_#{type.capitalize}_#{Time.now.to_i}"
      comp_def = model.definitions.add(comp_name)

      l_mm = (params['length'] || 1200).to_f
      w_mm = (params['width']  || 600).to_f
      h_mm = (params['height'] || 750).to_f
      t_mm = (params['thickness'] || 18).to_f

      # Đổi mm sang inch cho thuộc tính DC của SketchUp
      l_inch = l_mm / 25.4
      w_inch = w_mm / 25.4
      h_inch = h_mm / 25.4
      t_inch = t_mm / 25.4

      # 2. Gán thuộc tính cấp cha (Root Component Attributes)
      comp_def.set_attribute(DICT_NAME, '_formatversion', 1.0)
      comp_def.set_attribute(DICT_NAME, '_name', "Bàn Làm Việc Thông Minh Chill AI")
      comp_def.set_attribute(DICT_NAME, '_description', "Dynamic Component được tạo tự động bởi Chill AI. Tự co giãn theo kích thước thực tế.")

      # Cho phép người dùng chỉnh sửa trong hộp thoại "Component Options"
      setup_ui_attribute(comp_def, 'lenx', l_inch, 'Chiều Dài (Length)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'leny', w_inch, 'Chiều Rộng (Width)', 'MILLIMETERS')
      setup_ui_attribute(comp_def, 'lenz', h_inch, 'Chiều Cao (Height)', 'MILLIMETERS')

      # 3. Dựng các chi tiết con bên trong Component Definition
      ents = comp_def.entities

      # --- Chi tiết 1: Mặt Bàn (Liên kết kích thước động theo cha) ---
      mat_top_def = model.definitions.add("DC_Mat_Ban_#{Time.now.to_i}")
      mat_top_def.set_attribute(DICT_NAME, '_name', "Mặt Bàn")
      create_solid_box(mat_top_def.entities, l_inch, w_inch, t_inch)
      
      # Gán công thức toán học động: Mặt bàn luôn tự thay đổi dài/rộng bằng cha
      mat_top_def.set_attribute(DICT_NAME, '_lenx_formula', 'Parent!LenX')
      mat_top_def.set_attribute(DICT_NAME, '_leny_formula', 'Parent!LenY')
      mat_top_def.set_attribute(DICT_NAME, '_lenz_formula', 'Parent!Thickness')
      mat_top_def.set_attribute(DICT_NAME, '_z_formula', 'Parent!LenZ - Parent!Thickness')

      # Thêm instance mặt bàn vào cha
      inst_top = ents.add_instance(mat_top_def, Geom::Transformation.translation([0, 0, (h_inch - t_inch)]))
      inst_top.name = "Mat_Ban_Dong"

      # --- Chi tiết 2: Cánh Tủ / Ngăn Kéo có hàm OnClick mở ra đóng vào ---
      door_def = model.definitions.add("DC_Canh_Mo_#{Time.now.to_i}")
      door_def.set_attribute(DICT_NAME, '_name', "Cánh Tủ Động")
      create_solid_box(door_def.entities, l_inch * 0.4, 0.7, h_inch * 0.5)

      # Thêm hàm tương tác Click chuột mở cánh góc 90 độ (Interactive OnClick)
      door_def.set_attribute(DICT_NAME, 'onclick', 'ANIMATE("RotZ", 0, 90)')
      door_def.set_attribute(DICT_NAME, 'rotz', 0.0)

      inst_door = ents.add_instance(door_def, Geom::Transformation.translation([1, 1, 2]))
      inst_door.name = "Canh_Mo_Interactive"

      # 4. Đặt instance của component cha vào mô hình chính
      instance = model.active_entities.add_instance(comp_def, Geom::Transformation.new)
      
      # Kích hoạt cập nhật Dynamic Component Redraw nếu có sẵn thư viện SketchUp DC
      redraw_dynamic_component(instance)

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
