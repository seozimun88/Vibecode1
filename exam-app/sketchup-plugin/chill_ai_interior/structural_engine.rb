# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Structural Engine (Cỗ Máy Kết Cấu & Dynamic DC Chặng 3)
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module StructuralEngine
    DICT_DC = 'dynamic_attributes'.freeze
    DICT_CHILL = 'chill_ai'.freeze

    # Đường dẫn file tri thức kết cấu
    def self.preset_file_path
      File.join(File.dirname(__FILE__), 'knowledge_base', 'furniture_rules.json')
    end

    def self.contributions_file_path
      File.join(File.dirname(__FILE__), 'knowledge_base', 'community_contributions.json')
    end

    # 1. ĐỌC VÀ QUẢN LÝ BỘ GEN KẾT CẤU
    def self.load_presets
      path = preset_file_path
      return {} unless File.exist?(path)
      begin
        content = File.read(path, encoding: 'UTF-8')
        JSON.parse(content)
      rescue => e
        puts "[Chill AI] Lỗi đọc presets: #{e.message}"
        {}
      end
    end

    def self.get_preset(preset_id = nil)
      data = load_presets
      presets = data['presets'] || {}
      target_id = preset_id || data['active_preset'] || 'an_cuong_17_5'
      presets[target_id] || presets['an_cuong_17_5'] || {
        'board_thickness' => 17.5,
        'back_thickness' => 9.0,
        'back_groove_depth' => 9.0,
        'back_groove_offset' => 18.0,
        'door_gap_center' => 2.0,
        'drawer_side_clearance' => 12.7,
        'toe_kick_height' => 60.0
      }
    end

    def self.save_custom_preset(custom_data)
      path = preset_file_path
      return false unless File.exist?(path)
      begin
        data = load_presets
        data['presets'] ||= {}
        data['presets']['custom_user'] = custom_data
        data['active_preset'] = 'custom_user'
        File.write(path, JSON.pretty_generate(data), encoding: 'UTF-8')
        puts "[Chill AI] Đã lưu thành công Cấu Hình Riêng Của Xưởng!"
        true
      rescue => e
        puts "[Chill AI] Lỗi lưu preset: #{e.message}"
        false
      end
    end

    # 2. TIẾP NHẬN ĐÓNG GÓP TRI THỨC MỘC TỪ CỘNG ĐỒNG
    def self.save_contribution(contribution)
      path = contributions_file_path
      list = []
      if File.exist?(path)
        begin
          list = JSON.parse(File.read(path, encoding: 'UTF-8'))
        rescue => e
          list = []
        end
      end
      contribution['timestamp'] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      list << contribution
      File.write(path, JSON.pretty_generate(list), encoding: 'UTF-8')
      puts "[Chill AI] Đã ghi nhận đóng góp tri thức: #{contribution['title']}"
      true
    end

    # 3. CỖ MÁY SINH MÔ HÌNH 3D KẾT CẤU CHUẨN MỘC (MODULAR WARDROBE)
    def self.build_wardrobe_structural(params = {})
      model = Sketchup.active_model
      model.start_operation("Chill AI: Tạo Tủ Áo Kỹ Thuật Chuẩn Mộc", true)

      preset_id = params['preset_id'] || 'an_cuong_17_5'
      preset = get_preset(preset_id)

      # Thông số tổng thể
      l_mm = (params['length'] || 1600).to_f
      w_mm = (params['width'] || 600).to_f
      h_mm = (params['height'] || 2200).to_f
      doors_cnt = (params['doors'] || 3).to_i
      drawers_cnt = (params['drawers'] || 2).to_i

      # Bộ gen mộc từ Preset
      t_mm = (preset['board_thickness'] || 17.5).to_f
      t_back_mm = (preset['back_thickness'] || 9.0).to_f
      groove_d_mm = (preset['back_groove_depth'] || 9.0).to_f
      groove_off_mm = (preset['back_groove_offset'] || 18.0).to_f
      door_gap_mm = (preset['door_gap_center'] || 2.0).to_f
      toe_h_mm = (preset['toe_kick_height'] || 60.0).to_f
      dr_gap_mm = (preset['drawer_side_clearance'] || 12.7).to_f

      # Chuyển đổi sang đơn vị chuẩn SketchUp (Internal Inches)
      l = l_mm.mm
      w = w_mm.mm
      h = h_mm.mm
      t = t_mm.mm
      t_back = t_back_mm.mm
      groove_d = groove_d_mm.mm
      groove_off = groove_off_mm.mm
      door_gap = door_gap_mm.mm
      toe_h = toe_h_mm.mm
      dr_gap = dr_gap_mm.mm

      # Vật liệu
      mat_name = params['material'] || 'white_melamine'
      mat_body = ModelGenerator.get_or_create_material(mat_name)
      mat_door = ModelGenerator.get_or_create_material(params['door_material'] || mat_name)
      mat_metal = ModelGenerator.get_or_create_material('metal_black')

      # ========================================================================
      # TẦNG 1: KHỐI TỔNG (ROOT ASSEMBLY DYNAMIC COMPONENT)
      # ========================================================================
      comp_name = "Chill_Wardrobe_#{Time.now.to_i}"
      root_def = model.definitions.add(comp_name)
      root_def.name = "Tủ Áo Chuẩn Xưởng CNC (Chill AI)"

      setup_dc_root(root_def, l_mm, w_mm, h_mm, t_mm, "Hệ Tủ Áo Module Đóng Gói Chuẩn Mộc CNC")

      # Gắn nhãn 3 tầng Chill AI
      root_def.set_attribute(DICT_CHILL, 'tier', 1)
      root_def.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 1: Khối Tổng (Wardrobe Assembly)')
      root_def.set_attribute(DICT_CHILL, 'preset_used', preset['name'])

      root_ents = root_def.entities

      # ========================================================================
      # TẦNG 2A: CỤM THÙNG TỦ (BODY CARCASS MODULE)
      # ========================================================================
      carcass_group = root_ents.add_group
      carcass_group.name = "Cum_Thung_Tu_Chiu_Luc"
      carcass_group.set_attribute(DICT_CHILL, 'tier', 2)
      carcass_group.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 2: Cụm Thùng Tủ Chịu Lực')
      c_ents = carcass_group.entities

      # 1. Hồi Trái (Tấm đứng chịu lực bên trái)
      h_l = create_part_component(c_ents, "TA-01_HoiTrai", "Hồi Trái Chịu Lực", [0, 0, 0], t, w, h, {
        'grain' => 'vertical',
        'length_mm' => h_mm, 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_top' => 0.4, 'edge_bottom' => 0.4,
        'has_groove' => true, 'groove_desc' => "Rãnh hậu 9x9mm cách mép sau #{groove_off_mm}mm"
      })
      h_l.material = mat_body

      # 2. Hồi Phải (Tấm đứng chịu lực bên phải)
      h_r = create_part_component(c_ents, "TA-02_HoiPhai", "Hồi Phải Chịu Lực", [l - t, 0, 0], t, w, h, {
        'grain' => 'vertical',
        'length_mm' => h_mm, 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_top' => 0.4, 'edge_bottom' => 0.4,
        'has_groove' => true, 'groove_desc' => "Rãnh hậu 9x9mm cách mép sau #{groove_off_mm}mm"
      })
      h_r.material = mat_body

      # 3. Đáy Tủ (Nằm lọt lòng giữa 2 hồi, cách đất toe_h mm)
      w_carcass_inner = l - 2 * t
      day = create_part_component(c_ents, "TA-03_DayTu", "Đáy Tủ Lọt Lòng", [t, 0, toe_h], w_carcass_inner, w, t, {
        'grain' => 'horizontal',
        'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_left' => 0.0, 'edge_right' => 0.0,
        'has_groove' => true
      })
      day.material = mat_body

      # 4. Nóc Tủ (Nằm lọt lòng giữa 2 hồi ở đỉnh)
      noc = create_part_component(c_ents, "TA-04_NocTu", "Nóc Tủ Lọt Lòng", [t, 0, h - t], w_carcass_inner, w, t, {
        'grain' => 'horizontal',
        'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_left' => 0.0, 'edge_right' => 0.0,
        'has_groove' => true
      })
      noc.material = mat_body

      # 5. Len Chân Trước & Len Chân Sau
      len_f = create_part_component(c_ents, "TA-05_LenTruoc", "Len Chân Trước", [t, 20.mm, 0], w_carcass_inner, t, toe_h, {
        'grain' => 'horizontal',
        'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => toe_h_mm, 'thick_mm' => t_mm,
        'edge_front' => 0.4, 'edge_bottom' => 0.4
      })
      len_b = create_part_component(c_ents, "TA-06_LenSau", "Len Chân Sau", [t, w - 20.mm - t, 0], w_carcass_inner, t, toe_h, {
        'grain' => 'horizontal',
        'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => toe_h_mm, 'thick_mm' => t_mm
      })
      [len_f, len_b].each { |m| m.material = mat_body }

      # 6. Vách Ngăn Đứng & Đợt Ngang (Nếu có từ 3 cánh)
      inner_h = h - toe_h - t
      if doors_cnt >= 3
        # Chia tỉ lệ: 2/3 khoang đôi và 1/3 khoang đơn
        div_x = t + (w_carcass_inner * 2.0 / 3.0)
        vach = create_part_component(c_ents, "TA-07_VachChia", "Vách Đứng Chia Khoang", [div_x, 0, toe_h], t, w - groove_off, inner_h, {
          'grain' => 'vertical',
          'length_mm' => inner_h.to_mm, 'width_mm' => (w - groove_off).to_mm, 'thick_mm' => t_mm,
          'edge_front' => 1.0
        })
        vach.material = mat_body

        # Đợt khoang áo dài (bên phải)
        dot_r = create_part_component(c_ents, "TA-08_DotPhai", "Đợt Khoang Áo Dài", [div_x + t, 10.mm, h * 0.7], l - div_x - 2 * t, w - groove_off - 10.mm, t, {
          'grain' => 'horizontal', 'edge_front' => 1.0
        })
        dot_r.material = mat_body
      end

      # ========================================================================
      # TẦNG 2B: CỤM TẤM HẬU TỦ (BACK PANEL SOI RÃNH ÂM)
      # ========================================================================
      back_group = root_ents.add_group
      back_group.name = "Cum_Tam_Hau_Soi_Ranh"
      back_group.set_attribute(DICT_CHILL, 'tier', 2)
      back_group.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 2: Tấm Hậu Soi Rãnh 9mm')

      # Tấm hậu ngậm sâu vào rãnh mỗi bên groove_d (9mm)
      back_w = w_carcass_inner + 2 * groove_d
      back_h = inner_h + 2 * groove_d
      back_pos_x = t - groove_d
      back_pos_y = w - groove_off - t_back
      back_pos_z = toe_h - groove_d + t

      hau = create_part_component(back_group.entities, "TA-09_TamHau", "Tấm Hậu MDF 9mm Soi Âm", [back_pos_x, back_pos_y, back_pos_z], back_w, t_back, back_h, {
        'grain' => 'vertical',
        'length_mm' => back_h.to_mm, 'width_mm' => back_w.to_mm, 'thick_mm' => t_back_mm,
        'material_type' => 'MDF_Hau_Trang_9mm'
      })
      hau.material = ModelGenerator.get_or_create_material('white_melamine')

      # ========================================================================
      # TẦNG 2C: CỤM CÁNH TỦ (DOORS WITH INTERACTIVE ONCLICK)
      # ========================================================================
      doors_group = root_ents.add_group
      doors_group.name = "Cum_Canh_Tu_Interactive"
      doors_group.set_attribute(DICT_CHILL, 'tier', 2)
      doors_group.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 2: Cánh Tủ Thông Minh (Click Mở 90°)')

      door_total_w = l - 2 * door_gap
      single_door_w = (door_total_w - (doors_cnt - 1) * door_gap) / doors_cnt
      door_h = h - toe_h - 2 * door_gap

      doors_cnt.times do |i|
        dx = door_gap + i * (single_door_w + door_gap)
        dy = -t # Cánh trùm ngoài phủ trước mặt thùng
        dz = toe_h + door_gap

        is_left_hinge = (i % 2 == 0)
        door_comp = create_interactive_door(doors_group.entities, "TA-10_Canh_#{i+1}", "Cánh Tủ #{i+1}", [dx, dy, dz], single_door_w, t, door_h, is_left_hinge)
        door_comp.material = mat_door

        # Tay nắm vát mép / tay nắm thanh
        tn_x = is_left_hinge ? dx + single_door_w - 35.mm : dx + 20.mm
        tn = create_part_component(doors_group.entities, "TA-11_TayNam_#{i+1}", "Tay Nắm Kim Loại", [tn_x, dy - 20.mm, dz + door_h * 0.5 - 60.mm], 15.mm, 20.mm, 120.mm)
        tn.material = mat_metal
      end

      # ========================================================================
      # TẦNG 2D: CỤM HỘC KÉO (DRAWERS WITH SIDE CLEARANCE)
      # ========================================================================
      if drawers_cnt > 0
        drawers_group = root_ents.add_group
        drawers_group.name = "Cum_Hoc_Ngan_Keo"
        drawers_group.set_attribute(DICT_CHILL, 'tier', 2)
        drawers_group.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 2: Hộc Ngăn Kéo (Trừ Ray 12.7mm)')

        # Chiều rộng lọt lòng khoang chứa hộc kéo
        dr_bay_w = (doors_cnt >= 3) ? (w_carcass_inner * 2.0 / 3.0) : w_carcass_inner
        dr_total_h = [drawers_cnt * 160.mm, inner_h * 0.4].min
        dr_single_h = (dr_total_h - (drawers_cnt - 1) * 4.mm) / drawers_cnt

        drawers_cnt.times do |j|
          dr_z = toe_h + 4.mm + j * (dr_single_h + 4.mm)
          # Thùng hộc kéo trừ 12.7mm mỗi bên cho ray trượt
          box_w = dr_bay_w - 2 * dr_gap
          box_depth = w - groove_off - 30.mm

          # Mặt ngăn kéo (phủ ngoài)
          face = create_part_component(drawers_group.entities, "TA-12_MatKeo_#{j+1}", "Mặt Ngăn Kéo #{j+1}", [t + 2.mm, -t, dr_z], dr_bay_w - 4.mm, t, dr_single_h, {
            'grain' => 'horizontal', 'edge_all' => 1.0
          })
          face.material = mat_door

          # Khối hộc kéo bên trong
          box = create_part_component(drawers_group.entities, "TA-13_ThungKeo_#{j+1}", "Thùng Hộc Kéo #{j+1}", [t + dr_gap, 20.mm, dr_z], box_w, box_depth, dr_single_h * 0.85, {
            'is_drawer_box' => true
          })
          box.material = mat_body
        end
      end

      # Đặt Instance vào không gian làm việc chính
      instance = model.active_entities.add_instance(root_def, Geom::Transformation.new)
      
      # Tự động chọn và zoom vào mô hình
      model.selection.clear
      model.selection.add(instance)
      model.active_view.zoom(instance) if model.active_view

      # Kích hoạt Dynamic Component Redraw nếu có
      DynamicComponentBuilder.redraw_dynamic_component(instance) rescue nil

      model.commit_operation
      puts "[Chill AI] Đã dựng thành công Tủ Áo Module Chuẩn Mộc (Preset: #{preset['name']})!"
      instance
    end

    # HÀM PHỤ TRỢ: TẠO SOLID COMPONENT CHO TỪNG TẤM VÁN CÓ METADATA DNA
    def self.create_part_component(entities, part_id, part_name, origin, dx, dy, dz, dna = {})
      model = Sketchup.active_model
      comp_def = model.definitions.add(part_id)
      comp_def.name = part_name

      # Tạo hình khối Solid Box
      pts = [
        [0, 0, 0],
        [dx, 0, 0],
        [dx, dy, 0],
        [0, dy, 0]
      ]
      face = comp_def.entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)

      # Gán DNA dữ liệu sản xuất vào Component
      comp_def.set_attribute(DICT_CHILL, 'tier', 3)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', "Tầng 3: Tấm Ván [#{part_name}]")
      comp_def.set_attribute(DICT_CHILL, 'part_id', part_id)
      comp_def.set_attribute(DICT_CHILL, 'name', part_name)
      comp_def.set_attribute(DICT_CHILL, 'len_mm', [dx.to_mm, dy.to_mm, dz.to_mm].max.round(1))
      comp_def.set_attribute(DICT_CHILL, 'width_mm', [dx.to_mm, dy.to_mm, dz.to_mm].sort[1].round(1))
      comp_def.set_attribute(DICT_CHILL, 'thick_mm', [dx.to_mm, dy.to_mm, dz.to_mm].min.round(1))
      comp_def.set_attribute(DICT_CHILL, 'grain', dna['grain'] || 'vertical')
      comp_def.set_attribute(DICT_CHILL, 'edge_banding', dna['edge_banding'] || 'PVC 1mm')

      # Thêm instance vào cụm cha
      inst = entities.add_instance(comp_def, Geom::Transformation.translation(origin))
      inst.name = part_name
      inst
    end

    # HÀM PHỤ TRỢ: TẠO CÁNH TỦ CÓ HÀM DYNAMIC ONCLICK MỞ 90 ĐỘ
    def self.create_interactive_door(entities, part_id, part_name, origin, dx, dy, dz, is_left_hinge = true)
      model = Sketchup.active_model
      comp_def = model.definitions.add("#{part_id}_Interactive")
      comp_def.name = part_name

      pts = [
        [0, 0, 0],
        [dx, 0, 0],
        [dx, dy, 0],
        [0, dy, 0]
      ]
      face = comp_def.entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)

      # Gán hàm OnClick mở cánh
      rot_angle = is_left_hinge ? -90 : 90
      comp_def.set_attribute(DICT_DC, 'onclick', "ANIMATE(\"RotZ\", 0, #{rot_angle})")
      comp_def.set_attribute(DICT_DC, 'rotz', 0.0)
      comp_def.set_attribute(DICT_DC, '_name', part_name)

      # Gán nhãn Chill AI
      comp_def.set_attribute(DICT_CHILL, 'tier', 3)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', "Tầng 3: Cánh Tủ [#{part_name}]")
      comp_def.set_attribute(DICT_CHILL, 'is_door', true)

      inst = entities.add_instance(comp_def, Geom::Transformation.translation(origin))
      inst.name = part_name
      inst
    end

    # THIẾT LẬP THUỘC TÍNH DYNAMIC COMPONENT CẤP CHA
    def self.setup_dc_root(comp_def, l_mm, w_mm, h_mm, t_mm, desc)
      comp_def.set_attribute(DICT_DC, '_formatversion', 1.0)
      comp_def.set_attribute(DICT_DC, '_name', comp_def.name)
      comp_def.set_attribute(DICT_DC, '_description', desc)

      # Thêm các tham số cho hộp thoại Component Options
      setup_dc_attr(comp_def, 'lenx', l_mm / 25.4, 'Chiều Dài (Length)', 'MILLIMETERS')
      setup_dc_attr(comp_def, 'leny', w_mm / 25.4, 'Chiều Sâu (Depth)', 'MILLIMETERS')
      setup_dc_attr(comp_def, 'lenz', h_mm / 25.4, 'Chiều Cao (Height)', 'MILLIMETERS')
      setup_dc_attr(comp_def, 'thickness', t_mm / 25.4, 'Độ Dày Ván', 'MILLIMETERS')
    end

    def self.setup_dc_attr(comp_def, attr, val, label, units = 'MILLIMETERS')
      comp_def.set_attribute(DICT_DC, attr, val)
      comp_def.set_attribute(DICT_DC, "_#{attr}_access", 'TEXTBOX')
      comp_def.set_attribute(DICT_DC, "_#{attr}_label", label)
      comp_def.set_attribute(DICT_DC, "_#{attr}_units", units)
    end
  end
end
