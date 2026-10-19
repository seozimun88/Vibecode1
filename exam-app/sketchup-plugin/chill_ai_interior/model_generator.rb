# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Model Generator (Dựng hình 3D SketchUp)
# ==============================================================================

module ChillAIInterior
  module ModelGenerator
    def self.generate(params)
      model = Sketchup.active_model
      model.start_operation("Chill AI: Tạo Mô Hình 3D", true)

      entities = model.active_entities
      type = (params['type'] || 'desk').to_s.downcase

      # ĐẶC BIỆT: Nếu là Tủ Quần Áo / Cabinet: Dựng trực tiếp qua Cỗ Máy Kết Cấu StructuralEngine
      # Đảm bảo 100% các tấm ván (Hồi, Đáy, Nóc, Hậu, Cánh, Ngăn kéo) đều có công thức Dynamic Component
      # Tuyệt đối không bao giờ bị vỡ hay hở mép khi co kéo kích thước trong SketchUp!
      if type == 'wardrobe' || type == 'cabinet' || type.include?('tu')
        model.abort_operation
        return StructuralEngine.build_wardrobe_structural(params)
      end

      # Kích thước đầu vào chuẩn xưởng (Dài 1200mm, Rộng 600mm, Tủ áo Cao 1800mm, Bàn 750mm)
      default_h = 750
      length = (params['length'] || 1200).to_f.mm
      width  = (params['width']  || 600).to_f.mm
      height = (params['height'] || default_h).to_f.mm
      thick  = (params['thickness'] || 17.5).to_f.mm

      # Tùy chọn nâng cao
      wood_type = params['material'] || 'oak'
      leg_style = params['leg_style'] || 'metal_frame' # metal_frame, wooden_legs, panel_legs
      drawers   = (params['drawers'] || 0).to_i

      main_group = entities.add_group
      main_group.name = "Chill_AI_#{type.capitalize}_#{params['name'] || 'Model'}"
      main_group.set_attribute('chill_ai', 'tier', 1)
      main_group.set_attribute('chill_ai', 'tier_label', 'Tầng 1: Khối Tổng (Composite Assembly)')
      main_group.set_attribute('chill_ai', 'name', params['name'] || "Khối Tổng #{type.capitalize}")
      main_group.set_attribute('chill_ai', 'category', 'Nội Thất Hoàn Thiện')
      main_group.set_attribute('chill_ai', 'icon_type', 'assembly')

      case type
      when 'desk', 'table'
        build_desk(main_group, length, width, height, thick, leg_style, drawers, wood_type)
      when 'wardrobe', 'cabinet'
        doors = (params['doors'] || 3).to_i
        drawers = (params['drawers'] || 0).to_i
        door_mat = params['door_material'] || 'same_as_body'
        build_cabinet(main_group, length, width, height, thick, doors, drawers, wood_type, door_mat)
      when 'kitchen_cabinet'
        build_kitchen(main_group, length, width, height, thick, params, wood_type)
      when 'shelf', 'bookshelf', 'tv_stand'
        shelves = (params['shelves'] || 3).to_i
        build_shelf(main_group, length, width, height, thick, shelves, wood_type)
      when 'bed'
        build_bed(main_group, length, width, height, thick, wood_type)
      else
        build_desk(main_group, length, width, height, thick, leg_style, drawers, wood_type)
      end

      # Tự động chuyển đổi thành Dynamic Component có đầy đủ thông số và cảnh báo khổ ván
      begin
        dc_inst = DynamicComponentBuilder.convert_to_dynamic_component(main_group, params)
        main_group = dc_inst if dc_inst && dc_inst.valid?
      rescue => dc_err
        puts "[Chill AI] Chuyển đổi DC ban đầu: #{dc_err.message}"
      end

      # Tự động chọn mô hình vừa tạo và căn khung nhìn
      model.selection.clear
      model.selection.add(main_group)
      model.active_view.zoom(main_group) if model.active_view

      model.commit_operation
      main_group
    end

    # --- 1. Dựng Bàn Làm Việc / Bàn Ăn ---
    def self.build_desk(parent, l, w, h, t, leg_style, drawers, wood)
      ents = parent.entities
      mat_wood = get_or_create_material(wood)
      mat_metal = get_or_create_material('metal_black')

      # a) Mặt bàn (Table Top)
      top = create_box(ents, [0, 0, h - t], l, w, t, "Mặt bàn")
      top.material = mat_wood
      top.set_attribute('chill_ai', 'tier', 2)
      top.set_attribute('chill_ai', 'tier_label', 'Tầng 2: Khối Lẻ (Mặt Bàn Gỗ Sồi)')
      top.set_attribute('chill_ai', 'name', 'Mặt Bàn Gỗ Tự Nhiên Sồi Nga')
      top.set_attribute('chill_ai', 'category', 'Chi Tiết Mặt Bàn')
      top.set_attribute('chill_ai', 'icon_type', 'panel')

      # b) Chân bàn theo phong cách
      if leg_style == 'panel_legs'
        # Chân ván gỗ công nghiệp (Panel Legs)
        leg_l = create_box(ents, [0, 0, 0], t, w, h - t, "Chân ván trái")
        leg_r = create_box(ents, [l - t, 0, 0], t, w, h - t, "Chân ván phải")
        [leg_l, leg_r].each { |p| p.material = mat_wood }

        # Yếm giằng sau
        yem_h = [250.mm, (h - t) * 0.4].min
        yem = create_box(ents, [t, w - 60.mm - t, h - t - yem_h], l - 2 * t, t, yem_h, "Yếm giằng sau")
        yem.material = mat_wood

      elsif leg_style == 'wooden_legs'
        # 4 Chân gỗ tiêu chuẩn
        leg_size = 40.mm
        c1 = create_box(ents, [10.mm, 10.mm, 0], leg_size, leg_size, h - t, "Chân gỗ 1")
        c2 = create_box(ents, [l - 10.mm - leg_size, 10.mm, 0], leg_size, leg_size, h - t, "Chân gỗ 2")
        c3 = create_box(ents, [10.mm, w - 10.mm - leg_size, 0], leg_size, leg_size, h - t, "Chân gỗ 3")
        c4 = create_box(ents, [l - 10.mm - leg_size, w - 10.mm - leg_size, 0], leg_size, leg_size, h - t, "Chân gỗ 4")
        [c1, c2, c3, c4].each { |c| c.material = mat_wood }

        # Yếm bàn 4 phía
        apron_h = 70.mm
        y1 = create_box(ents, [10.mm + leg_size, 15.mm, h - t - apron_h], l - 2 * (10.mm + leg_size), t, apron_h, "Yếm trước")
        y2 = create_box(ents, [10.mm + leg_size, w - 15.mm - t, h - t - apron_h], l - 2 * (10.mm + leg_size), t, apron_h, "Yếm sau")
        y3 = create_box(ents, [15.mm, 10.mm + leg_size, h - t - apron_h], t, w - 2 * (10.mm + leg_size), apron_h, "Yếm trái")
        y4 = create_box(ents, [l - 15.mm - t, 10.mm + leg_size, h - t - apron_h], t, w - 2 * (10.mm + leg_size), apron_h, "Yếm phải")
        [y1, y2, y3, y4].each { |y| y.material = mat_wood }

      else
        # Khung chân sắt hộp chữ U đôi (Mặc định)
        leg_size = 40.mm
        leg_l = create_metal_u_leg(ents, 0, 0, h - t, leg_size, w, "Chân sắt trái")
        leg_l.material = mat_metal

        leg_r = create_metal_u_leg(ents, l - leg_size, 0, h - t, leg_size, w, "Chân sắt phải")
        leg_r.material = mat_metal

        # Giằng ngang sắt sau
        stretcher = create_box(ents, [leg_size, w / 2 - 15.mm, h - t - 30.mm], l - 2 * leg_size, 30.mm, 30.mm, "Giằng ngang sắt")
        stretcher.material = mat_metal
      end

      # c) Hộc tủ ngăn kéo (Nếu có)
      if drawers > 0
        dr_w = [380.mm, l * 0.35].min
        dr_h = [drawers * 160.mm, h - t - 50.mm].min
        dr_d = w - 40.mm
        dr_group = ents.add_group
        dr_group.name = "Hộc ngăn kéo (#{drawers} ngăn)"
        dr_ents = dr_group.entities

        # Thùng hộc
        h_left  = create_box(dr_ents, [l - dr_w - 20.mm, 20.mm, h - t - dr_h], t, dr_d, dr_h, "Hông hộc trái")
        h_right = create_box(dr_ents, [l - 20.mm - t, 20.mm, h - t - dr_h], t, dr_d, dr_h, "Hông hộc phải")
        h_bot   = create_box(dr_ents, [l - dr_w - 20.mm, 20.mm, h - t - dr_h], dr_w, dr_d, t, "Đáy hộc")
        [h_left, h_right, h_bot].each { |p| p.material = mat_wood }

        # Mặt từng ngăn kéo
        slot_h = (dr_h - 20.mm) / drawers
        drawers.times do |i|
          d_face = create_box(dr_ents, [l - dr_w - 18.mm, 15.mm, h - t - dr_h + 10.mm + i * slot_h], dr_w - 4.mm, t, slot_h - 4.mm, "Mặt ngăn kéo #{i + 1}")
          d_face.material = mat_wood
        end
      end
    end

    # --- 2. Dựng Tủ Quần Áo / Tủ Bếp ---
    def self.build_cabinet(parent, l, w, h, t, doors, drawers, wood, door_mat_type)
      ents = parent.entities
      mat_wood = get_or_create_material(wood)
      mat_white = get_or_create_material('white_melamine')
      mat_door = (door_mat_type.to_s == 'white_melamine') ? mat_white : mat_wood
      mat_metal = get_or_create_material('metal_black')

      # Hông trái & phải (Từ Z=0 lên Z=h)
      h_trai = create_box(ents, [0, 0, 0], t, w, h, "Hông tủ trái [#{h.to_mm.to_i}x#{w.to_mm.to_i}x#{t.to_mm.to_i}]")
      h_phai = create_box(ents, [l - t, 0, 0], t, w, h, "Hông tủ phải [#{h.to_mm.to_i}x#{w.to_mm.to_i}x#{t.to_mm.to_i}]")
      
      # Đáy & Nóc tủ
      day = create_box(ents, [t, 0, 60.mm], l - 2 * t, w, t, "Đáy tủ [#{((l - 2 * t).to_mm).to_i}x#{w.to_mm.to_i}x#{t.to_mm.to_i}]")
      noc = create_box(ents, [t, 0, h - t], l - 2 * t, w, t, "Nóc tủ [#{((l - 2 * t).to_mm).to_i}x#{w.to_mm.to_i}x#{t.to_mm.to_i}]")
      
      # Len chân tủ (cao 60mm ở đáy trước)
      len = create_box(ents, [t, 20.mm, 0], l - 2 * t, t, 60.mm, "Len chân tủ")

      # Tấm hậu tủ MDF 6mm
      hau = create_box(ents, [t, w - 6.mm, 60.mm], l - 2 * t, 6.mm, h - 60.mm - t, "Hậu tủ MDF 6mm")

      [h_trai, h_phai, day, noc, len].each { |m| m.material = mat_wood }
      hau.material = mat_white

      # TRƯỜNG HỢP A: TỦ 3 CÁNH + NGĂN KÉO (Khớp 100% ảnh chụp thực tế của khách hàng!)
      if doors == 3 && drawers > 0
        col_w = (l - 4.mm) / 3
        dr_total_h = [drawers * 180.mm, 420.mm].min
        upper_door_h = h - 64.mm - dr_total_h - 4.mm

        # Vách ngăn đứng bên trong chia khoang 2 cánh trái và khoang 1 cánh phải
        divider_x = t + 2 * (l - 2 * t) / 3
        vach = create_box(ents, [divider_x, 0, 60.mm], t, w - 10.mm, h - 60.mm - t, "Vách ngăn đứng chia khoang")
        vach.material = mat_wood

        # Đợt ngang chia khoang trái (nằm ngay trên nóc ngăn kéo)
        dot_dr = create_box(ents, [t, 10.mm, 60.mm + dr_total_h], divider_x - t, w - 10.mm, t, "Đợt nóc ngăn kéo")
        # Đợt chia khoang cánh dài bên phải
        dot_r = create_box(ents, [divider_x + t, 10.mm, h * 0.7], l - divider_x - 2 * t, w - 10.mm, t, "Đợt khoang áo dài")
        [dot_dr, dot_r].each { |m| m.material = mat_wood }

        # 1 Cánh dài suốt bên phải (từ len chân lên sát nóc)
        r_door_x = 2.mm + 2 * col_w
        r_door = create_box(ents, [r_door_x, -t, 62.mm], col_w - 2.mm, t, h - 64.mm, "Cánh dài phải")
        r_door.material = mat_door
        # Tay nắm đứng cánh phải
        tn_r = create_box(ents, [r_door_x + 25.mm, -t - 20.mm, h * 0.5 - 60.mm], 15.mm, 20.mm, 120.mm, "Tay nắm cánh phải")
        tn_r.material = mat_metal

        # 2 Cánh ngắn bên trái
        upper_z = 62.mm + dr_total_h + 4.mm
        d1 = create_box(ents, [2.mm, -t, upper_z], col_w - 2.mm, t, upper_door_h, "Cánh ngắn trái 1")
        d2 = create_box(ents, [2.mm + col_w, -t, upper_z], col_w - 2.mm, t, upper_door_h, "Cánh ngắn trái 2")
        [d1, d2].each { |m| m.material = mat_door }

        # Tay nắm đứng 2 cánh ngắn (đặt đối xứng ở giữa)
        tn1 = create_box(ents, [2.mm + col_w - 35.mm, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, "Tay nắm cánh 1")
        tn2 = create_box(ents, [2.mm + col_w + 20.mm, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, "Tay nắm cánh 2")
        [tn1, tn2].each { |m| m.material = mat_metal }

        # Các ngăn kéo bên dưới (trải rộng qua 2 khoang trái)
        single_dr_h = (dr_total_h - (drawers - 1) * 4.mm) / drawers
        dr_w = 2 * col_w - 2.mm
        drawers.times do |j|
          dr_z = 62.mm + j * (single_dr_h + 4.mm)
          dr_face = create_box(ents, [2.mm, -t, dr_z], dr_w, t, single_dr_h, "Mặt ngăn kéo #{j + 1}")
          dr_face.material = mat_door

          # 2 Tay nắm ngang cho mỗi ngăn kéo như ảnh chụp
          tn_dr1 = create_box(ents, [2.mm + col_w * 0.5 - 45.mm, -t - 20.mm, dr_z + single_dr_h * 0.5 - 7.mm], 90.mm, 20.mm, 15.mm, "Tay nắm kéo #{j+1}-A")
          tn_dr2 = create_box(ents, [2.mm + col_w * 1.5 - 45.mm, -t - 20.mm, dr_z + single_dr_h * 0.5 - 7.mm], 90.mm, 20.mm, 15.mm, "Tay nắm kéo #{j+1}-B")
          [tn_dr1, tn_dr2].each { |m| m.material = mat_metal }
        end

      elsif doors == 2 && drawers > 0
        # TRƯỜNG HỢP B: TỦ 2 CÁNH + NGĂN KÉO DƯỚI
        col_w = (l - 4.mm) / 2
        dr_total_h = [drawers * 180.mm, 420.mm].min
        upper_door_h = h - 64.mm - dr_total_h - 4.mm
        upper_z = 62.mm + dr_total_h + 4.mm

        # Đợt ngang nóc ngăn kéo
        dot_dr = create_box(ents, [t, 10.mm, 60.mm + dr_total_h], l - 2 * t, w - 10.mm, t, "Đợt nóc ngăn kéo")
        dot_dr.material = mat_wood

        # 2 Cánh ngắn
        doors.times do |i|
          dx = 2.mm + i * col_w
          d = create_box(ents, [dx, -t, upper_z], col_w - 2.mm, t, upper_door_h, "Cánh ngắn #{i + 1}")
          d.material = mat_door
          tn_x = (i == 0) ? dx + col_w - 35.mm : dx + 20.mm
          tn = create_box(ents, [tn_x, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, "Tay nắm #{i + 1}")
          tn.material = mat_metal
        end

        # Ngăn kéo dưới
        single_dr_h = (dr_total_h - (drawers - 1) * 4.mm) / drawers
        drawers.times do |j|
          dr_z = 62.mm + j * (single_dr_h + 4.mm)
          dr_face = create_box(ents, [2.mm, -t, dr_z], l - 4.mm, t, single_dr_h, "Mặt ngăn kéo #{j + 1}")
          dr_face.material = mat_door
          tn = create_box(ents, [l * 0.5 - 50.mm, -t - 20.mm, dr_z + single_dr_h * 0.5 - 7.mm], 100.mm, 20.mm, 15.mm, "Tay nắm kéo #{j + 1}")
          tn.material = mat_metal
        end

      else
        # TRƯỜNG HỢP C: TỦ CÁNH MỞ TIÊU CHUẨN
        dot1 = create_box(ents, [t, 10.mm, (h * 0.4)], l - 2 * t, w - 10.mm, t, "Đợt chia ngang")
        dot1.material = mat_wood

        door_w = (l - 4.mm) / doors
        door_h = h - 64.mm
        doors.times do |i|
          d = create_box(ents, [2.mm + i * door_w, -t, 62.mm], door_w - 2.mm, t, door_h, "Cánh tủ #{i + 1}")
          d.material = mat_door

          tn_x = 2.mm + i * door_w + (i.even? ? door_w - 40.mm : 25.mm)
          tn = create_box(ents, [tn_x, -t - 20.mm, (h * 0.5) - 60.mm], 15.mm, 20.mm, 120.mm, "Tay nắm #{i + 1}")
          tn.material = mat_metal
        end
      end
    end

    # --- 2.5. Tủ Bếp ---
    def self.build_kitchen(parent, l, w, h, t, params, wood)
      ents = parent.entities
      mat_wood = get_or_create_material(wood)
      mat_white = get_or_create_material('white_melamine')

      bs_color = params['backsplash_color'] || 'green_glass'
      mat_glass = Sketchup.active_model.materials["Chill_Glass_#{bs_color}"]
      unless mat_glass
        mat_glass = Sketchup.active_model.materials.add("Chill_Glass_#{bs_color}")
        mat_glass.alpha = 0.8
        if bs_color.include?('white')
          mat_glass.color = Sketchup::Color.new(245, 245, 245)
        elsif bs_color.include?('black')
          mat_glass.color = Sketchup::Color.new(30, 30, 30)
        else
          mat_glass.color = Sketchup::Color.new(100, 200, 150)
        end
      end

      lower_h = 810.mm
      lower_d = w
      bs_h = 650.mm
      upper_h = [h - lower_h - bs_h, 400.mm].max
      upper_d = 350.mm

      shape = params['kitchen_shape'] || "I"
      has_upper = params['has_upper'] != false
      has_lower = params['has_lower'] != false

      # 1. Main I arm along X axis
      if has_lower
        create_box(ents, [0, 0, 0], l, lower_d, lower_h, "Tủ Dưới Chính").material = mat_wood
      end
      if has_lower && has_upper
        create_box(ents, [0, lower_d - 10.mm, lower_h], l, 10.mm, bs_h, "Kính Ốp Chính").material = mat_glass
      end
      if has_upper
        create_box(ents, [0, lower_d - upper_d, lower_h + bs_h], l, upper_d, upper_h, "Tủ Trên Chính").material = mat_white
      end

      # 2. L arm if needed
      if shape == "L"
        l_arm_len = [l * 0.8, 1500.mm].min
        
        # Start at x=0, going along Y axis (-Y direction since Sketchup Y is usually depth)
        # Wait, the main arm goes from x=0 to x=l, y=0 to y=lower_d.
        # The L arm should go from y=0 to y=-l_arm_len, or x=0 to x=-l_arm_len?
        # A standard L kitchen has the corner at (0,0) and extends along X and Y.
        # So L arm extends from y=lower_d to y=lower_d + l_arm_len (if we extend back).
        # Let's just extend along X = 0, Y goes negative.
        if has_lower
          create_box(ents, [0, -l_arm_len + lower_d, 0], lower_d, l_arm_len - lower_d, lower_h, "Tủ Dưới L").material = mat_wood
        end
        if has_lower && has_upper
          create_box(ents, [0, -l_arm_len + lower_d, lower_h], 10.mm, l_arm_len - lower_d, bs_h, "Kính Ốp L").material = mat_glass
        end
        if has_upper
          create_box(ents, [0, -l_arm_len + lower_d, lower_h + bs_h], upper_d, l_arm_len - lower_d, upper_h, "Tủ Trên L").material = mat_white
        end
      end
    end

    # --- 3. Dựng Kệ Sách / Kệ Tivi ---
    def self.build_shelf(parent, l, w, h, t, shelves, wood)
      ents = parent.entities
      mat = get_or_create_material(wood)

      create_box(ents, [0, 0, 0], t, w, h, "Vách đứng trái").material = mat
      create_box(ents, [l - t, 0, 0], t, w, h, "Vách đứng phải").material = mat
      create_box(ents, [t, 0, 0], l - 2 * t, w, t, "Đáy kệ").material = mat
      create_box(ents, [t, 0, h - t], l - 2 * t, w, t, "Nóc kệ").material = mat

      spacing = (h - 2 * t) / (shelves + 1)
      shelves.times do |i|
        dot = create_box(ents, [t, 0, t + (i + 1) * spacing], l - 2 * t, w, t, "Đợt ngang #{i + 1}")
        dot.material = mat
      end
    end

    # --- 4. Dựng Giường Ngủ ---
    def self.build_bed(parent, l, w, h, t, wood)
      ents = parent.entities
      mat = get_or_create_material(wood)

      head_h = h * 2.2
      # Đầu giường
      create_box(ents, [0, w - t, 0], l, t, head_h, "Đầu giường").material = mat
      # Đuôi giường
      create_box(ents, [0, 0, 0], l, t, h, "Đuôi giường").material = mat
      # 2 Vai giường
      create_box(ents, [0, t, 0], t, w - 2 * t, h, "Vai giường trái").material = mat
      create_box(ents, [l - t, t, 0], t, w - 2 * t, h, "Vai giường phải").material = mat
      # Dát phản nằm
      create_box(ents, [t, t, h - 30.mm], l - 2 * t, w - 2 * t, 20.mm, "Dát giường").material = mat
    end

    # --- Tiện ích hình học tạo hộp (Box Generator) ---
    def self.create_box(ents, origin, dx, dy, dz, name = "Panel")
      grp = ents.add_group
      grp.name = name
      grp.set_attribute('chill_ai', 'tier', 3)
      grp.set_attribute('chill_ai', 'tier_label', 'Tầng 3: Miếng Ván Nhỏ (Part / Panel)')
      grp.set_attribute('chill_ai', 'name', name)
      grp.set_attribute('chill_ai', 'category', 'Tấm Ván Sản Xuất')
      grp.set_attribute('chill_ai', 'icon_type', 'panel')
      pts = [
        origin,
        [origin[0] + dx, origin[1], origin[2]],
        [origin[0] + dx, origin[1] + dy, origin[2]],
        [origin[0], origin[1] + dy, origin[2]]
      ]
      face = grp.entities.add_face(pts)
      # Luôn đảm bảo mặt hướng lên trên (+Z) để pushpull luôn kéo lên trên, không bị thụt xuống dưới âm Z
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)
      grp
    end

    def self.create_metal_u_leg(ents, x, y, h, size, depth, name)
      grp = ents.add_group
      grp.name = name
      grp.set_attribute('chill_ai', 'tier', 2)
      grp.set_attribute('chill_ai', 'tier_label', 'Tầng 2: Khối Lẻ (Khung Chân Sắt)')
      grp.set_attribute('chill_ai', 'name', name)
      grp.set_attribute('chill_ai', 'category', 'Kết Cấu Chịu Lực')
      grp.set_attribute('chill_ai', 'icon_type', 'module')
      e = grp.entities

      # Chân đứng 1
      f1 = e.add_face([[x, y, 0], [x + size, y, 0], [x + size, y + size, 0], [x, y + size, 0]])
      f1.reverse! if f1.normal.z < 0
      f1.pushpull(h)

      # Chân đứng 2
      f2 = e.add_face([[x, y + depth - size, 0], [x + size, y + depth - size, 0], [x + size, y + depth, 0], [x, y + depth, 0]])
      f2.reverse! if f2.normal.z < 0
      f2.pushpull(h)

      # Giằng đáy nối 2 chân
      b_pts = [[x, y, 0], [x + size, y, 0], [x + size, y + depth, 0], [x, y + depth, 0]]
      fb = e.add_face(b_pts)
      fb.reverse! if fb.normal.z < 0
      fb.pushpull(size)

      # Giằng đỉnh bắt vít vào mặt bàn
      t_pts = [[x, y, h - size], [x + size, y, h - size], [x + size, y + depth, h - size], [x, y + depth, h - size]]
      ft = e.add_face(t_pts)
      ft.reverse! if ft.normal.z < 0
      ft.pushpull(size)

      grp
    end

    def self.get_or_create_material(type)
      materials = Sketchup.active_model.materials
      case type.to_s.downcase
      when 'walnut', 'oc_cho'
        mat = materials["Chill_Walnut_Wood"] || materials.add("Chill_Walnut_Wood")
        mat.color = Sketchup::Color.new(92, 64, 51)
      when 'oak', 'soi'
        mat = materials["Chill_Oak_Wood"] || materials.add("Chill_Oak_Wood")
        mat.color = Sketchup::Color.new(205, 168, 130)
      when 'white_melamine', 'trang'
        mat = materials["Chill_White_Melamine"] || materials.add("Chill_White_Melamine")
        mat.color = Sketchup::Color.new(245, 245, 245)
      when 'metal_black'
        mat = materials["Chill_Metal_Black"] || materials.add("Chill_Metal_Black")
        mat.color = Sketchup::Color.new(45, 45, 45)
      else
        mat = materials["Chill_Default_Wood"] || materials.add("Chill_Default_Wood")
        mat.color = Sketchup::Color.new(180, 140, 100)
      end
      mat
    end
  end
end
