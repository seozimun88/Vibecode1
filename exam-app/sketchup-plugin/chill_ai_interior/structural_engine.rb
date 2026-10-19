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

    # 3. CỖ MÁY SINH MÔ HÌNH 3D KẾT CẤU CHUẨN MỘC (MODULAR PARAMETRIC DYNAMIC WARDROBE)
    def self.build_wardrobe_structural(params = {})
      model = Sketchup.active_model
      model.start_operation("Chill AI: Tạo Tủ Áo Dynamic Chuẩn Xưởng CNC", true)

      preset_id = params['preset_id'] || 'an_cuong_17_5'
      preset = get_preset(preset_id)

      # Thông số tổng thể chuẩn xưởng: Dài 1200mm (1m2), Rộng/Sâu 600mm, Cao 1800mm (1m8)
      l_mm = (params['length'] || 1200).to_f
      w_mm = (params['width'] || 600).to_f
      h_mm = (params['height'] || 1800).to_f
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

      setup_dc_root(root_def, l_mm, w_mm, h_mm, t_mm, "Hệ Tủ Áo Dynamic Module Chuẩn Mộc CNC", toe_h_mm, groove_off_mm, t_back_mm)

      # Gắn nhãn 3 tầng Chill AI
      root_def.set_attribute(DICT_CHILL, 'tier', 1)
      root_def.set_attribute(DICT_CHILL, 'tier_label', 'Tầng 1: Khối Tổng (Wardrobe Assembly)')
      root_def.set_attribute(DICT_CHILL, 'preset_used', preset['name'])

      root_ents = root_def.entities

      # ========================================================================
      # CÁC TẤM VÁN THÙNG TỦ (CARCASS PANELS) VỚI CÔNG THỨC KHÓA ĐỘ DÀY CHUẨN MỘC
      # ========================================================================
      w_carcass_inner = l - 2 * t
      inner_h = h - toe_h - t

      # 1. Hồi Trái (Tấm đứng chịu lực bên trái) - Khóa chiều dày 17.5mm theo Parent!Thickness
      h_l = create_part_component(root_ents, "TA-01_HoiTrai", "Hồi Trái Chịu Lực", [0, 0, 0], t, w, h, {
        'grain' => 'vertical', 'length_mm' => h_mm, 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_top' => 0.4, 'edge_bottom' => 0.4,
        'has_groove' => true
      }, {
        'x' => '0', 'y' => '0', 'z' => '0',
        'lenx' => 'Parent!Thickness',
        'leny' => 'Parent!LenY',
        'lenz' => 'Parent!LenZ'
      })
      h_l.material = mat_body

      # 2. Hồi Phải (Tấm đứng chịu lực bên phải) - Luôn bám sát mép phải Parent!LenX - Parent!Thickness
      h_r = create_part_component(root_ents, "TA-02_HoiPhai", "Hồi Phải Chịu Lực", [l - t, 0, 0], t, w, h, {
        'grain' => 'vertical', 'length_mm' => h_mm, 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'edge_back' => 0.0, 'edge_top' => 0.4, 'edge_bottom' => 0.4,
        'has_groove' => true
      }, {
        'x' => 'Parent!LenX - Parent!Thickness', 'y' => '0', 'z' => '0',
        'lenx' => 'Parent!Thickness',
        'leny' => 'Parent!LenY',
        'lenz' => 'Parent!LenZ'
      })
      h_r.material = mat_body

      # 3. Đáy Tủ (Nằm lọt lòng giữa 2 hồi, cách đất toe_height)
      day = create_part_component(root_ents, "TA-03_DayTu", "Đáy Tủ Lọt Lòng", [t, 0, toe_h], w_carcass_inner, w, t, {
        'grain' => 'horizontal', 'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'has_groove' => true
      }, {
        'x' => 'Parent!Thickness', 'y' => '0', 'z' => 'Parent!ToeHeight',
        'lenx' => 'Parent!LenX - 2 * Parent!Thickness',
        'leny' => 'Parent!LenY',
        'lenz' => 'Parent!Thickness'
      })
      day.material = mat_body

      # 4. Nóc Tủ (Nằm lọt lòng giữa 2 hồi ở đỉnh)
      noc = create_part_component(root_ents, "TA-04_NocTu", "Nóc Tủ Lọt Lòng", [t, 0, h - t], w_carcass_inner, w, t, {
        'grain' => 'horizontal', 'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => w_mm, 'thick_mm' => t_mm,
        'edge_front' => 1.0, 'has_groove' => true
      }, {
        'x' => 'Parent!Thickness', 'y' => '0', 'z' => 'Parent!LenZ - Parent!Thickness',
        'lenx' => 'Parent!LenX - 2 * Parent!Thickness',
        'leny' => 'Parent!LenY',
        'lenz' => 'Parent!Thickness'
      })
      noc.material = mat_body

      # 5. Len Chân Trước & Len Chân Sau
      len_f = create_part_component(root_ents, "TA-05_LenTruoc", "Len Chân Trước", [t, 20.mm, 0], w_carcass_inner, t, toe_h, {
        'grain' => 'horizontal', 'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => toe_h_mm, 'thick_mm' => t_mm
      }, {
        'x' => 'Parent!Thickness', 'y' => '0.7874', 'z' => '0',
        'lenx' => 'Parent!LenX - 2 * Parent!Thickness',
        'leny' => 'Parent!Thickness',
        'lenz' => 'Parent!ToeHeight'
      })
      len_b = create_part_component(root_ents, "TA-06_LenSau", "Len Chân Sau", [t, w - 20.mm - t, 0], w_carcass_inner, t, toe_h, {
        'grain' => 'horizontal', 'length_mm' => (l_mm - 2 * t_mm), 'width_mm' => toe_h_mm, 'thick_mm' => t_mm
      }, {
        'x' => 'Parent!Thickness', 'y' => 'Parent!LenY - 0.7874 - Parent!Thickness', 'z' => '0',
        'lenx' => 'Parent!LenX - 2 * Parent!Thickness',
        'leny' => 'Parent!Thickness',
        'lenz' => 'Parent!ToeHeight'
      })
      [len_f, len_b].each { |m| m.material = mat_body }

      # 6. Vách Ngăn Đứng & Đợt Ngang (Chia khoang theo tỉ lệ 2/3 và 1/3)
      if doors_cnt >= 3
        div_x = t + (w_carcass_inner * 2.0 / 3.0)
        vach = create_part_component(root_ents, "TA-07_VachChia", "Vách Đứng Chia Khoang", [div_x, 0, toe_h], t, w - groove_off, inner_h, {
          'grain' => 'vertical', 'length_mm' => inner_h.to_mm, 'width_mm' => (w - groove_off).to_mm, 'thick_mm' => t_mm,
          'edge_front' => 1.0
        }, {
          'x' => 'Parent!Thickness + (Parent!LenX - 2 * Parent!Thickness) * 2 / 3',
          'y' => '0',
          'z' => 'Parent!ToeHeight',
          'lenx' => 'Parent!Thickness',
          'leny' => 'Parent!LenY - Parent!GrooveOffset',
          'lenz' => 'Parent!LenZ - Parent!ToeHeight - Parent!Thickness'
        })
        vach.material = mat_body

        dot_r = create_part_component(root_ents, "TA-08_DotPhai", "Đợt Khoang Áo Dài", [div_x + t, 10.mm, h * 0.7], (w_carcass_inner / 3.0) - t, w - groove_off - 10.mm, t, {
          'grain' => 'horizontal', 'edge_front' => 1.0
        }, {
          'x' => 'Parent!Thickness + (Parent!LenX - 2 * Parent!Thickness) * 2 / 3 + Parent!Thickness',
          'y' => '0.3937',
          'z' => 'Parent!LenZ * 0.7',
          'lenx' => '(Parent!LenX - 2 * Parent!Thickness) / 3 - Parent!Thickness',
          'leny' => 'Parent!LenY - Parent!GrooveOffset - 0.3937',
          'lenz' => 'Parent!Thickness'
        })
        dot_r.material = mat_body
      end

      # ========================================================================
      # TẤM HẬU TỦ (BACK PANEL SOI RÃNH ÂM)
      # ========================================================================
      back_w = w_carcass_inner + 2 * groove_d
      back_h = inner_h + 2 * groove_d
      back_pos_x = t - groove_d
      back_pos_y = w - groove_off - t_back
      back_pos_z = toe_h - groove_d + t

      hau = create_part_component(root_ents, "TA-09_TamHau", "Tấm Hậu MDF 9mm Soi Âm", [back_pos_x, back_pos_y, back_pos_z], back_w, t_back, back_h, {
        'grain' => 'vertical', 'length_mm' => back_h.to_mm, 'width_mm' => back_w.to_mm, 'thick_mm' => t_back_mm,
        'material_type' => 'MDF_Hau_Trang_9mm'
      }, {
        'x' => 'Parent!Thickness - 0.3543',
        'y' => 'Parent!LenY - Parent!GrooveOffset - Parent!BackThickness',
        'z' => 'Parent!ToeHeight - 0.3543 + Parent!Thickness',
        'lenx' => 'Parent!LenX - 2 * Parent!Thickness + 0.7087',
        'leny' => 'Parent!BackThickness',
        'lenz' => 'Parent!LenZ - Parent!ToeHeight - Parent!Thickness + 0.7087'
      })
      hau.material = ModelGenerator.get_or_create_material('white_melamine')

      # ========================================================================
      # CỤM CÁNH TỦ VÀ HỘC KÉO DYNAMIC (MODULAR PARAMETRIC - KHÔNG BAO GIỜ BỊ VỠ KHI CO KÉO)
      # ========================================================================
      if doors_cnt == 3 && drawers_cnt > 0
        # TRƯỜNG HỢP ĐẶC BIỆT CHUẨN XƯỞNG (2 cánh ngắn + 2 ngăn kéo bên trái 2/3, 1 cánh dài bên phải 1/3)
        dr_bay_w = w_carcass_inner * 2.0 / 3.0
        dr_total_h = [drawers_cnt * 180.mm, 420.mm].min
        dr_total_h_inch = dr_total_h.to_inch.round(4)
        single_dr_h = (dr_total_h - (drawers_cnt - 1) * 4.mm) / drawers_cnt
        single_dr_h_inch = single_dr_h.to_inch.round(4)

        # 1. Đợt ngang nóc ngăn kéo (ngăn cách ngăn kéo và 2 cánh ngắn phía trên)
        dot_dr = create_part_component(root_ents, "TA-08B_DotNocKeo", "Đợt Nóc Ngăn Kéo", [t, 10.mm, toe_h + dr_total_h], dr_bay_w, w - groove_off - 10.mm, t, {
          'grain' => 'horizontal', 'edge_front' => 1.0
        }, {
          'x' => 'Parent!Thickness',
          'y' => '0.3937',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch}",
          'lenx' => '(Parent!LenX - 2 * Parent!Thickness) * 2 / 3',
          'leny' => 'Parent!LenY - Parent!GrooveOffset - 0.3937',
          'lenz' => 'Parent!Thickness'
        })
        dot_dr.material = mat_body

        # 2. Hai cánh ngắn bên trái (nằm từ nóc ngăn kéo lên sát nóc tủ)
        single_short_door_w = ((dr_bay_w) - 3 * door_gap) / 2.0
        upper_z = toe_h + dr_total_h + 4.mm
        upper_door_h = h - upper_z - door_gap

        # Cánh ngắn trái 1
        d1 = create_interactive_door(root_ents, "TA-10A_CanhNgan1", "Cánh Ngắn Trái 1", [t + door_gap, -t, upper_z], single_short_door_w, t, upper_door_h, true, {
          'x' => 'Parent!Thickness + 0.0787',
          'y' => '-Parent!Thickness',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575",
          'lenx' => '((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.2362) / 2',
          'leny' => 'Parent!Thickness',
          'lenz' => "Parent!LenZ - Parent!ToeHeight - #{dr_total_h_inch} - 0.2362"
        })
        d1.material = mat_door

        # Tay nắm đứng cánh ngắn 1
        tn1_x = t + door_gap + single_short_door_w - 35.mm
        tn1 = create_handle_component(root_ents, "TA-11A_TayNamCanh1", "Tay Nắm Cánh 1", [tn1_x, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, {
          'x' => 'Parent!Thickness + 0.0787 + ((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.2362) / 2 - 1.378',
          'y' => '-Parent!Thickness - 0.7874',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575 + 3.1496",
          'lenx' => '0.5906',
          'leny' => '0.7874',
          'lenz' => '4.7244'
        })

        # Cánh ngắn trái 2
        d2 = create_interactive_door(root_ents, "TA-10B_CanhNgan2", "Cánh Ngắn Trái 2", [t + door_gap + single_short_door_w + door_gap, -t, upper_z], single_short_door_w, t, upper_door_h, false, {
          'x' => 'Parent!Thickness + 0.1574 + ((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.2362) / 2',
          'y' => '-Parent!Thickness',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575",
          'lenx' => '((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.2362) / 2',
          'leny' => 'Parent!Thickness',
          'lenz' => "Parent!LenZ - Parent!ToeHeight - #{dr_total_h_inch} - 0.2362"
        })
        d2.material = mat_door

        # Tay nắm đứng cánh ngắn 2
        tn2_x = t + door_gap + single_short_door_w + door_gap + 20.mm
        tn2 = create_handle_component(root_ents, "TA-11B_TayNamCanh2", "Tay Nắm Cánh 2", [tn2_x, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, {
          'x' => 'Parent!Thickness + 0.1574 + ((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.2362) / 2 + 0.7874',
          'y' => '-Parent!Thickness - 0.7874',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575 + 3.1496",
          'lenx' => '0.5906',
          'leny' => '0.7874',
          'lenz' => '4.7244'
        })

        # 3. Một cánh dài suốt bên phải (từ len chân lên đỉnh nóc)
        r_door_w = (w_carcass_inner / 3.0) - door_gap
        r_door = create_interactive_door(root_ents, "TA-10C_CanhDaiPhai", "Cánh Dài Phải", [t + dr_bay_w + door_gap, -t, toe_h + door_gap], r_door_w, t, h - toe_h - 2 * door_gap, false, {
          'x' => 'Parent!Thickness + (Parent!LenX - 2 * Parent!Thickness) * 2 / 3 + 0.0787',
          'y' => '-Parent!Thickness',
          'z' => 'Parent!ToeHeight + 0.0787',
          'lenx' => '(Parent!LenX - 2 * Parent!Thickness) / 3 - 0.0787',
          'leny' => 'Parent!Thickness',
          'lenz' => 'Parent!LenZ - Parent!ToeHeight - 0.1575'
        })
        r_door.material = mat_door

        # Tay nắm đứng cánh dài phải (Tầng 3 Phụ Kiện Kim Khí Hafele)
        tn_r_x = t + dr_bay_w + door_gap + 25.mm
        tn_r_z = toe_h + (h - toe_h) * 0.5 - 60.mm
        tn_r = create_handle_component(root_ents, "TA-11C_TayNamCanhDai", "Tay Nắm Cánh Dài Phải", [tn_r_x, -t - 20.mm, tn_r_z], 15.mm, 20.mm, 120.mm, {
          'x' => 'Parent!Thickness + (Parent!LenX - 2 * Parent!Thickness) * 2 / 3 + 0.0787 + 0.984',
          'y' => '-Parent!Thickness - 0.7874',
          'z' => 'Parent!ToeHeight + (Parent!LenZ - Parent!ToeHeight) * 0.5 - 2.362',
          'lenx' => '0.5906',
          'leny' => '0.7874',
          'lenz' => '4.7244'
        })

        # 4. Các ngăn kéo bên dưới khoang trái
        drawers_cnt.times do |j|
          dr_z = toe_h + 4.mm + j * (single_dr_h + 4.mm)
          j_off_inch = (4.mm + j * (single_dr_h + 4.mm)).to_inch.round(4)
          box_w = dr_bay_w - 2 * dr_gap
          box_depth = w - groove_off - 30.mm

          # Mặt ngăn kéo có tay nắm
          face = create_interactive_drawer(root_ents, "TA-12_MatKeo_#{j+1}", "Mặt Ngăn Kéo #{j+1}", [t + 2.mm, -t, dr_z], dr_bay_w - 4.mm, t, single_dr_h, {
            'grain' => 'horizontal', 'edge_all' => 1.0, 'tier' => 2, 'tier_label' => "Tầng 2: Mặt Kéo #{j+1}"
          }, {
            'x' => 'Parent!Thickness + 0.0787',
            'y' => '-Parent!Thickness',
            'z' => "Parent!ToeHeight + #{j_off_inch}",
            'lenx' => '(Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.1575',
            'leny' => 'Parent!Thickness',
            'lenz' => "#{single_dr_h_inch}"
          })
          face.material = mat_door

          # 2 Tay nắm ngang cho mỗi mặt ngăn kéo (Tầng 3 Phụ Kiện)
          tn_dr1_x = t + 2.mm + (dr_bay_w - 4.mm) * 0.25 - 45.mm
          tn_dr2_x = t + 2.mm + (dr_bay_w - 4.mm) * 0.75 - 45.mm
          tn_dr_z = dr_z + single_dr_h * 0.5 - 7.5.mm

          create_handle_component(root_ents, "TA-11_TayNamKeo_#{j+1}A", "Tay Nắm Kéo #{j+1}-A", [tn_dr1_x, -t - 20.mm, tn_dr_z], 90.mm, 20.mm, 15.mm, {
            'x' => "Parent!Thickness + 0.0787 + ((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.1575) * 0.25 - 1.77",
            'y' => '-Parent!Thickness - 0.7874',
            'z' => "Parent!ToeHeight + #{j_off_inch} + #{single_dr_h_inch} * 0.5 - 0.295",
            'lenx' => '3.5433',
            'leny' => '0.7874',
            'lenz' => '0.5906'
          })

          create_handle_component(root_ents, "TA-11_TayNamKeo_#{j+1}B", "Tay Nắm Kéo #{j+1}-B", [tn_dr2_x, -t - 20.mm, tn_dr_z], 90.mm, 20.mm, 15.mm, {
            'x' => "Parent!Thickness + 0.0787 + ((Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 0.1575) * 0.75 - 1.77",
            'y' => '-Parent!Thickness - 0.7874',
            'z' => "Parent!ToeHeight + #{j_off_inch} + #{single_dr_h_inch} * 0.5 - 0.295",
            'lenx' => '3.5433',
            'leny' => '0.7874',
            'lenz' => '0.5906'
          })

          # Thùng hộc kéo trượt
          box = create_part_component(root_ents, "TA-13_ThungKeo_#{j+1}", "Thùng Hộc Kéo #{j+1}", [t + dr_gap, 20.mm, dr_z], box_w, box_depth, single_dr_h * 0.85, {
            'is_drawer_box' => true, 'tier' => 2, 'tier_label' => "Tầng 2: Thùng Hộc Kéo #{j+1}"
          }, {
            'x' => 'Parent!Thickness + 0.5',
            'y' => '0.7874',
            'z' => "Parent!ToeHeight + #{j_off_inch}",
            'lenx' => '(Parent!LenX - 2 * Parent!Thickness) * 2 / 3 - 1.0',
            'leny' => 'Parent!LenY - Parent!GrooveOffset - 1.181',
            'lenz' => "#{(single_dr_h * 0.85).to_inch.round(4)}"
          })
          box.material = mat_body
        end

      elsif doors_cnt == 2 && drawers_cnt > 0
        # TỦ 2 CÁNH + NGĂN KÉO DƯỚI (Trải rộng toàn bộ chiều dài)
        dr_bay_w = w_carcass_inner
        dr_total_h = [drawers_cnt * 180.mm, 420.mm].min
        dr_total_h_inch = dr_total_h.to_inch.round(4)
        single_dr_h = (dr_total_h - (drawers_cnt - 1) * 4.mm) / drawers_cnt
        single_dr_h_inch = single_dr_h.to_inch.round(4)

        # Đợt nóc ngăn kéo
        dot_dr = create_part_component(root_ents, "TA-08B_DotNocKeo", "Đợt Nóc Ngăn Kéo", [t, 10.mm, toe_h + dr_total_h], dr_bay_w, w - groove_off - 10.mm, t, {
          'grain' => 'horizontal', 'edge_front' => 1.0
        }, {
          'x' => 'Parent!Thickness',
          'y' => '0.3937',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch}",
          'lenx' => 'Parent!LenX - 2 * Parent!Thickness',
          'leny' => 'Parent!LenY - Parent!GrooveOffset - 0.3937',
          'lenz' => 'Parent!Thickness'
        })
        dot_dr.material = mat_body

        # 2 Cánh ngắn trên
        single_short_door_w = (dr_bay_w - 3 * door_gap) / 2.0
        upper_z = toe_h + dr_total_h + 4.mm
        upper_door_h = h - upper_z - door_gap

        d1 = create_interactive_door(root_ents, "TA-10A_CanhNgan1", "Cánh Ngắn 1", [t + door_gap, -t, upper_z], single_short_door_w, t, upper_door_h, true, {
          'x' => 'Parent!Thickness + 0.0787',
          'y' => '-Parent!Thickness',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575",
          'lenx' => '((Parent!LenX - 2 * Parent!Thickness) - 0.2362) / 2',
          'leny' => 'Parent!Thickness',
          'lenz' => "Parent!LenZ - Parent!ToeHeight - #{dr_total_h_inch} - 0.2362"
        })
        d1.material = mat_door

        # Tay nắm đứng cánh ngắn 1
        tn1_x = t + door_gap + single_short_door_w - 35.mm
        create_handle_component(root_ents, "TA-11A_TayNamCanh1", "Tay Nắm Cánh 1", [tn1_x, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, {
          'x' => 'Parent!Thickness + 0.0787 + ((Parent!LenX - 2 * Parent!Thickness) - 0.2362) / 2 - 1.378',
          'y' => '-Parent!Thickness - 0.7874',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575 + 3.1496",
          'lenx' => '0.5906',
          'leny' => '0.7874',
          'lenz' => '4.7244'
        })

        d2 = create_interactive_door(root_ents, "TA-10B_CanhNgan2", "Cánh Ngắn 2", [t + door_gap + single_short_door_w + door_gap, -t, upper_z], single_short_door_w, t, upper_door_h, false, {
          'x' => 'Parent!Thickness + 0.1574 + ((Parent!LenX - 2 * Parent!Thickness) - 0.2362) / 2',
          'y' => '-Parent!Thickness',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575",
          'lenx' => '((Parent!LenX - 2 * Parent!Thickness) - 0.2362) / 2',
          'leny' => 'Parent!Thickness',
          'lenz' => "Parent!LenZ - Parent!ToeHeight - #{dr_total_h_inch} - 0.2362"
        })
        d2.material = mat_door

        # Tay nắm đứng cánh ngắn 2
        tn2_x = t + door_gap + single_short_door_w + door_gap + 20.mm
        create_handle_component(root_ents, "TA-11B_TayNamCanh2", "Tay Nắm Cánh 2", [tn2_x, -t - 20.mm, upper_z + 80.mm], 15.mm, 20.mm, 120.mm, {
          'x' => 'Parent!Thickness + 0.1574 + ((Parent!LenX - 2 * Parent!Thickness) - 0.2362) / 2 + 0.7874',
          'y' => '-Parent!Thickness - 0.7874',
          'z' => "Parent!ToeHeight + #{dr_total_h_inch} + 0.1575 + 3.1496",
          'lenx' => '0.5906',
          'leny' => '0.7874',
          'lenz' => '4.7244'
        })

        # Ngăn kéo dưới
        drawers_cnt.times do |j|
          dr_z = toe_h + 4.mm + j * (single_dr_h + 4.mm)
          j_off_inch = (4.mm + j * (single_dr_h + 4.mm)).to_inch.round(4)
          box_w = dr_bay_w - 2 * dr_gap
          box_depth = w - groove_off - 30.mm

          face = create_interactive_drawer(root_ents, "TA-12_MatKeo_#{j+1}", "Mặt Ngăn Kéo #{j+1}", [t + 2.mm, -t, dr_z], dr_bay_w - 4.mm, t, single_dr_h, {
            'grain' => 'horizontal', 'edge_all' => 1.0, 'tier' => 2, 'tier_label' => "Tầng 2: Mặt Kéo #{j+1}"
          }, {
            'x' => 'Parent!Thickness + 0.0787',
            'y' => '-Parent!Thickness',
            'z' => "Parent!ToeHeight + #{j_off_inch}",
            'lenx' => 'Parent!LenX - 2 * Parent!Thickness - 0.1575',
            'leny' => 'Parent!Thickness',
            'lenz' => "#{single_dr_h_inch}"
          })
          face.material = mat_door

          # Tay nắm ngang ngăn kéo (Tầng 3 Phụ Kiện)
          tn_dr_x = t + 2.mm + (dr_bay_w - 4.mm) * 0.5 - 50.mm
          tn_dr_z = dr_z + single_dr_h * 0.5 - 7.5.mm
          create_handle_component(root_ents, "TA-11_TayNamKeo_#{j+1}", "Tay Nắm Kéo #{j+1}", [tn_dr_x, -t - 20.mm, tn_dr_z], 100.mm, 20.mm, 15.mm, {
            'x' => "Parent!Thickness + 0.0787 + (Parent!LenX - 2 * Parent!Thickness - 0.1575) * 0.5 - 1.9685",
            'y' => '-Parent!Thickness - 0.7874',
            'z' => "Parent!ToeHeight + #{j_off_inch} + #{single_dr_h_inch} * 0.5 - 0.295",
            'lenx' => '3.937',
            'leny' => '0.7874',
            'lenz' => '0.5906'
          })

          box = create_part_component(root_ents, "TA-13_ThungKeo_#{j+1}", "Thùng Hộc Kéo #{j+1}", [t + dr_gap, 20.mm, dr_z], box_w, box_depth, single_dr_h * 0.85, {
            'is_drawer_box' => true, 'tier' => 2, 'tier_label' => "Tầng 2: Thùng Hộc Kéo #{j+1}"
          }, {
            'x' => 'Parent!Thickness + 0.5',
            'y' => '0.7874',
            'z' => "Parent!ToeHeight + #{j_off_inch}",
            'lenx' => 'Parent!LenX - 2 * Parent!Thickness - 1.0',
            'leny' => 'Parent!LenY - Parent!GrooveOffset - 1.181',
            'lenz' => "#{(single_dr_h * 0.85).to_inch.round(4)}"
          })
          box.material = mat_body
        end

      else
        # TRƯỜNG HỢP CÁNH DÀI SUỐT (KHÔNG CÓ NGĂN KÉO)
        door_total_w = l - 2 * door_gap
        single_door_w = (door_total_w - (doors_cnt - 1) * door_gap) / doors_cnt
        door_h = h - toe_h - 2 * door_gap

        doors_cnt.times do |i|
          dx = door_gap + i * (single_door_w + door_gap)
          dy = -t
          dz = toe_h + door_gap
          is_left_hinge = (i % 2 == 0)

          door_x_formula = if doors_cnt == 1
            "0.0787"
          elsif doors_cnt == 2
            i == 0 ? "0.0787" : "0.0787 + (Parent!LenX - 0.236) / 2 + 0.0787"
          else
            if i == 0
              "0.0787"
            elsif i == 1
              "0.0787 + (Parent!LenX - 0.315) / 3 + 0.0787"
            else
              "0.0787 + 2 * ((Parent!LenX - 0.315) / 3 + 0.0787)"
            end
          end

          door_comp = create_interactive_door(root_ents, "TA-10_Canh_#{i+1}", "Cánh Tủ #{i+1}", [dx, dy, dz], single_door_w, t, door_h, is_left_hinge, {
            'x' => door_x_formula,
            'y' => '-Parent!Thickness',
            'z' => 'Parent!ToeHeight + 0.0787',
            'lenx' => "(Parent!LenX - 0.315) / #{doors_cnt}",
            'leny' => 'Parent!Thickness',
            'lenz' => 'Parent!LenZ - Parent!ToeHeight - 0.1575'
          })
          door_comp.material = mat_door

          # Tay nắm đứng cánh tủ (Tầng 3 Phụ Kiện Kim Khí)
          tn_x = is_left_hinge ? (dx + single_door_w - 35.mm) : (dx + 20.mm)
          tn_z = toe_h + door_h * 0.5 - 60.mm
          tn_x_formula = if doors_cnt == 1
            "#{door_x_formula} + (Parent!LenX - 0.315) - 1.378"
          elsif is_left_hinge
            "#{door_x_formula} + (Parent!LenX - 0.315) / #{doors_cnt} - 1.378"
          else
            "#{door_x_formula} + 0.7874"
          end

          create_handle_component(root_ents, "TA-11_TayNamCanh_#{i+1}", "Tay Nắm Cánh #{i+1}", [tn_x, -t - 20.mm, tn_z], 15.mm, 20.mm, 120.mm, {
            'x' => tn_x_formula,
            'y' => '-Parent!Thickness - 0.7874',
            'z' => 'Parent!ToeHeight + (Parent!LenZ - Parent!ToeHeight) * 0.5 - 2.362',
            'lenx' => '0.5906',
            'leny' => '0.7874',
            'lenz' => '4.7244'
          })
        end
      end

      # Đặt Instance vào không gian làm việc chính
      instance = model.active_entities.add_instance(root_def, Geom::Transformation.new)
      instance.name = root_def.name

      # Đồng bộ các thuộc tính DC lên instance
      inst_dict = instance.attribute_dictionary(DICT_DC, true)
      inst_dict['lenx'] = l_mm / 25.4
      inst_dict['leny'] = w_mm / 25.4
      inst_dict['lenz'] = h_mm / 25.4
      inst_dict['thickness'] = t_mm / 25.4
      inst_dict['toe_height'] = toe_h_mm / 25.4
      inst_dict['groove_offset'] = groove_off_mm / 25.4
      inst_dict['back_thickness'] = t_back_mm / 25.4
      inst_dict['canh_bao_kho_van'] = (l_mm > 2440.0 || w_mm > 2440.0 || h_mm > 2440.0) ? "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!" : "✅ ĐẠT CHUẨN CNC (1220x2440mm)"

      # Tự động chọn và zoom vào mô hình
      model.selection.clear
      model.selection.add(instance)
      model.active_view.zoom(instance) if model.active_view

      # Kích hoạt Dynamic Component Redraw
      DynamicComponentBuilder.redraw_dynamic_component(instance) rescue nil

      model.commit_operation
      puts "[Chill AI] Đã dựng thành công Tủ Áo Dynamic Module Chuẩn Mộc (Preset: #{preset['name']})!"
      instance
    end

    # HÀM PHỤ TRỢ: TẠO SOLID COMPONENT CHO TỪNG TẤM VÁN CÓ METADATA DNA & PARAMETRIC DC FORMULAS
    def self.create_part_component(entities, part_id, part_name, origin, dx, dy, dz, dna = {}, dc_formulas = {})
      model = Sketchup.active_model
      unique_id = "#{part_id}_#{Time.now.to_i}_#{rand(1000)}"
      comp_def = model.definitions.add(unique_id)
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

      # Gán DNA dữ liệu sản xuất vào Component (DICT_CHILL)
      comp_def.set_attribute(DICT_CHILL, 'tier', dna['tier'] || 3)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', dna['tier_label'] || "Tầng 3: Tấm Ván [#{part_name}]")
      comp_def.set_attribute(DICT_CHILL, 'part_id', part_id)
      comp_def.set_attribute(DICT_CHILL, 'name', part_name)
      comp_def.set_attribute(DICT_CHILL, 'len_mm', [dx.to_mm, dy.to_mm, dz.to_mm].max.round(1))
      comp_def.set_attribute(DICT_CHILL, 'width_mm', [dx.to_mm, dy.to_mm, dz.to_mm].sort[1].round(1))
      comp_def.set_attribute(DICT_CHILL, 'thick_mm', [dx.to_mm, dy.to_mm, dz.to_mm].min.round(1))
      comp_def.set_attribute(DICT_CHILL, 'grain', dna['grain'] || 'vertical')
      comp_def.set_attribute(DICT_CHILL, 'edge_banding', dna['edge_banding'] || 'PVC 1mm')
      comp_def.set_attribute(DICT_CHILL, 'has_groove', dna['has_groove'] ? true : false)

      # GÁN THUỘC TÍNH DYNAMIC COMPONENT PARAMETRIC FORMULAS (KHÓA ĐỘ DÀY TRÁNH CO DÃN CAO SU)
      comp_def.set_attribute(DICT_DC, '_name', part_name)
      comp_def.set_attribute(DICT_DC, '_scaletool', 0) # Khóa kéo lẻ trực tiếp làm méo tấm

      # Kích thước cơ sở (inches)
      comp_def.set_attribute(DICT_DC, 'lenx', dx.to_inch)
      comp_def.set_attribute(DICT_DC, 'leny', dy.to_inch)
      comp_def.set_attribute(DICT_DC, 'lenz', dz.to_inch)
      comp_def.set_attribute(DICT_DC, 'x', origin[0].to_inch)
      comp_def.set_attribute(DICT_DC, 'y', origin[1].to_inch)
      comp_def.set_attribute(DICT_DC, 'z', origin[2].to_inch)

      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        comp_def.set_attribute(DICT_DC, "_#{k}_formula", formula.to_s)
      end

      # Thêm instance vào cụm cha
      inst = entities.add_instance(comp_def, Geom::Transformation.translation(origin))
      inst.name = part_name

      # Gán đồng bộ cho instance
      inst_dict = inst.attribute_dictionary(DICT_DC, true)
      inst_dict['_name'] = part_name
      inst_dict['lenx'] = dx.to_inch
      inst_dict['leny'] = dy.to_inch
      inst_dict['lenz'] = dz.to_inch
      inst_dict['x'] = origin[0].to_inch
      inst_dict['y'] = origin[1].to_inch
      inst_dict['z'] = origin[2].to_inch
      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        inst_dict["_#{k}_formula"] = formula.to_s
      end

      inst
    end

    # HÀM PHỤ TRỢ: TẠO PHỤ KIỆN TAY NẮM KIM LOẠI ĐỘC LẬP (TẦNG 3)
    def self.create_handle_component(entities, part_id, part_name, origin, dx, dy, dz, dc_formulas = {})
      model = Sketchup.active_model
      unique_id = "#{part_id}_#{Time.now.to_i}_#{rand(1000)}"
      comp_def = model.definitions.add(unique_id)
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

      mat_metal = ModelGenerator.get_or_create_material('metal_black')
      comp_def.entities.grep(Sketchup::Face).each { |f| f.material = mat_metal }

      setup_dc_attr(comp_def, '_name', part_name, 'Tên Phụ Kiện', 'STRING', 'VIEW')
      setup_dc_attr(comp_def, 'lenx', dx.to_inch, 'Độ Rộng (Width)', 'INCHES', 'VIEW')
      setup_dc_attr(comp_def, 'leny', dy.to_inch, 'Độ Sâu (Depth)', 'INCHES', 'VIEW')
      setup_dc_attr(comp_def, 'lenz', dz.to_inch, 'Chiều Dài (Length)', 'INCHES', 'VIEW')
      setup_dc_attr(comp_def, 'x', origin[0].to_inch, 'Vị Trí X', 'INCHES', 'VIEW')
      setup_dc_attr(comp_def, 'y', origin[1].to_inch, 'Vị Trí Y', 'INCHES', 'VIEW')
      setup_dc_attr(comp_def, 'z', origin[2].to_inch, 'Vị Trí Z', 'INCHES', 'VIEW')

      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        comp_def.set_attribute(DICT_DC, "_#{k}_formula", formula.to_s)
      end

      comp_def.set_attribute(DICT_CHILL, 'tier', 3)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', "Tầng 3: Phụ Kiện Kim Khí (Hardware)")
      comp_def.set_attribute(DICT_CHILL, 'name', part_name)
      comp_def.set_attribute(DICT_CHILL, 'category', "Phụ Kiện")
      comp_def.set_attribute(DICT_CHILL, 'icon_type', "hardware")

      tr = Geom::Transformation.new(origin)
      inst = entities.add_instance(comp_def, tr)
      inst.name = part_name
      inst.material = mat_metal

      # Đồng bộ thuộc tính DC và Chill AI trực tiếp lên instance
      inst_dict = inst.attribute_dictionary(DICT_DC, true)
      inst_dict['_name'] = part_name
      inst_dict['lenx'] = dx.to_inch
      inst_dict['leny'] = dy.to_inch
      inst_dict['lenz'] = dz.to_inch
      inst_dict['x'] = origin[0].to_inch
      inst_dict['y'] = origin[1].to_inch
      inst_dict['z'] = origin[2].to_inch
      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        inst_dict["_#{k}_formula"] = formula.to_s
      end

      inst.set_attribute(DICT_CHILL, 'tier', 3)
      inst.set_attribute(DICT_CHILL, 'tier_label', "Tầng 3: Phụ Kiện Kim Khí (Hardware)")
      inst.set_attribute(DICT_CHILL, 'name', part_name)
      inst.set_attribute(DICT_CHILL, 'category', "Phụ Kiện")
      inst.set_attribute(DICT_CHILL, 'icon_type', "hardware")

      inst
    end

    # HÀM PHỤ TRỢ: TẠO CÁNH TỦ CÔNG THỨC PARAMETRIC (VÁN PHẲNG CHUẨN MỘC CNC)
    def self.create_interactive_door(entities, part_id, part_name, origin, dx, dy, dz, is_left_hinge = true, dc_formulas = {})
      model = Sketchup.active_model
      unique_id = "#{part_id}_#{Time.now.to_i}_#{rand(1000)}"
      comp_def = model.definitions.add(unique_id)
      comp_def.name = part_name

      # Thân cánh tủ
      pts = [
        [0, 0, 0],
        [dx, 0, 0],
        [dx, dy, 0],
        [0, dy, 0]
      ]
      face = comp_def.entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)

      # Gán OnClick mở cánh góc 90 độ
      rot_angle = is_left_hinge ? -90 : 90
      comp_def.set_attribute(DICT_DC, 'onclick', "ANIMATE(\"RotZ\", 0, #{rot_angle})")
      comp_def.set_attribute(DICT_DC, 'rotz', 0.0)
      comp_def.set_attribute(DICT_DC, '_name', part_name)
      comp_def.set_attribute(DICT_DC, '_scaletool', 0)

      # Kích thước cơ sở
      comp_def.set_attribute(DICT_DC, 'lenx', dx.to_inch)
      comp_def.set_attribute(DICT_DC, 'leny', dy.to_inch)
      comp_def.set_attribute(DICT_DC, 'lenz', dz.to_inch)
      comp_def.set_attribute(DICT_DC, 'x', origin[0].to_inch)
      comp_def.set_attribute(DICT_DC, 'y', origin[1].to_inch)
      comp_def.set_attribute(DICT_DC, 'z', origin[2].to_inch)

      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        comp_def.set_attribute(DICT_DC, "_#{k}_formula", formula.to_s)
      end

      # Gán nhãn Chill AI
      comp_def.set_attribute(DICT_CHILL, 'tier', 2)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', "Tầng 2: Cánh Tủ Thông Minh [#{part_name}]")
      comp_def.set_attribute(DICT_CHILL, 'is_door', true)
      comp_def.set_attribute(DICT_CHILL, 'len_mm', dz.to_mm.round(1))
      comp_def.set_attribute(DICT_CHILL, 'width_mm', dx.to_mm.round(1))
      comp_def.set_attribute(DICT_CHILL, 'thick_mm', dy.to_mm.round(1))

      inst = entities.add_instance(comp_def, Geom::Transformation.translation(origin))
      inst.name = part_name

      inst_dict = inst.attribute_dictionary(DICT_DC, true)
      inst_dict['onclick'] = "ANIMATE(\"RotZ\", 0, #{rot_angle})"
      inst_dict['rotz'] = 0.0
      inst_dict['_name'] = part_name
      inst_dict['lenx'] = dx.to_inch
      inst_dict['leny'] = dy.to_inch
      inst_dict['lenz'] = dz.to_inch
      inst_dict['x'] = origin[0].to_inch
      inst_dict['y'] = origin[1].to_inch
      inst_dict['z'] = origin[2].to_inch
      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        inst_dict["_#{k}_formula"] = formula.to_s
      end

      inst
    end

    # HÀM PHỤ TRỢ: TẠO MẶT NGĂN KÉO CÓ TAY NẮM LIỀN & ANIMATE TRƯỢT
    def self.create_interactive_drawer(entities, part_id, part_name, origin, dx, dy, dz, dna = {}, dc_formulas = {})
      model = Sketchup.active_model
      unique_id = "#{part_id}_#{Time.now.to_i}_#{rand(1000)}"
      comp_def = model.definitions.add(unique_id)
      comp_def.name = part_name

      # Thân mặt ngăn kéo
      pts = [
        [0, 0, 0],
        [dx, 0, 0],
        [dx, dy, 0],
        [0, dy, 0]
      ]
      face = comp_def.entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(dz)

      # Gán OnClick trượt ngăn kéo ra ngoài
      comp_def.set_attribute(DICT_DC, 'onclick', 'ANIMATE("Y", 0, -13.78)')
      comp_def.set_attribute(DICT_DC, 'y', origin[1].to_inch)
      comp_def.set_attribute(DICT_DC, '_name', part_name)
      comp_def.set_attribute(DICT_DC, '_scaletool', 0)

      # Kích thước cơ sở
      comp_def.set_attribute(DICT_DC, 'lenx', dx.to_inch)
      comp_def.set_attribute(DICT_DC, 'leny', dy.to_inch)
      comp_def.set_attribute(DICT_DC, 'lenz', dz.to_inch)
      comp_def.set_attribute(DICT_DC, 'x', origin[0].to_inch)
      comp_def.set_attribute(DICT_DC, 'z', origin[2].to_inch)

      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        comp_def.set_attribute(DICT_DC, "_#{k}_formula", formula.to_s)
      end

      # Gán nhãn Chill AI
      comp_def.set_attribute(DICT_CHILL, 'tier', dna['tier'] || 2)
      comp_def.set_attribute(DICT_CHILL, 'tier_label', dna['tier_label'] || "Tầng 2: Mặt Kéo [#{part_name}]")
      comp_def.set_attribute(DICT_CHILL, 'is_drawer', true)

      inst = entities.add_instance(comp_def, Geom::Transformation.translation(origin))
      inst.name = part_name

      inst_dict = inst.attribute_dictionary(DICT_DC, true)
      inst_dict['onclick'] = 'ANIMATE("Y", 0, -13.78)'
      inst_dict['_name'] = part_name
      inst_dict['lenx'] = dx.to_inch
      inst_dict['leny'] = dy.to_inch
      inst_dict['lenz'] = dz.to_inch
      inst_dict['x'] = origin[0].to_inch
      inst_dict['y'] = origin[1].to_inch
      inst_dict['z'] = origin[2].to_inch
      dc_formulas.each do |k, formula|
        next unless formula && !formula.to_s.empty?
        inst_dict["_#{k}_formula"] = formula.to_s
      end

      inst
    end

    # THIẾT LẬP THUỘC TÍNH DYNAMIC COMPONENT CẤP CHA (CÓ CẢNH BÁO KHỔ VÁN TRỰC TIẾP)
    def self.setup_dc_root(comp_def, l_mm, w_mm, h_mm, t_mm, desc, toe_h_mm = 60.0, groove_off_mm = 18.0, t_back_mm = 9.0)
      comp_def.set_attribute(DICT_DC, '_formatversion', 1.0)
      comp_def.set_attribute(DICT_DC, '_name', comp_def.name)
      comp_def.set_attribute(DICT_DC, '_description', desc)
      comp_def.set_attribute(DICT_DC, '_scaletool', 127) # Cho phép co kéo 3 trục bằng Scale tool

      # Thêm các tham số cho hộp thoại Component Options
      setup_dc_attr(comp_def, 'lenx', l_mm / 25.4, 'Chiều Dài (Length)', 'MILLIMETERS', 'TEXTBOX')
      setup_dc_attr(comp_def, 'leny', w_mm / 25.4, 'Chiều Sâu (Depth)', 'MILLIMETERS', 'TEXTBOX')
      setup_dc_attr(comp_def, 'lenz', h_mm / 25.4, 'Chiều Cao (Height)', 'MILLIMETERS', 'TEXTBOX')
      setup_dc_attr(comp_def, 'thickness', t_mm / 25.4, 'Độ Dày Ván (Thickness)', 'MILLIMETERS', 'TEXTBOX')
      setup_dc_attr(comp_def, 'toe_height', toe_h_mm / 25.4, 'Chiều Cao Len Chân', 'MILLIMETERS', 'VIEW')
      setup_dc_attr(comp_def, 'groove_offset', groove_off_mm / 25.4, 'Khoảng Cách Rãnh Hậu', 'MILLIMETERS', 'VIEW')
      setup_dc_attr(comp_def, 'back_thickness', t_back_mm / 25.4, 'Độ Dày Tấm Hậu', 'MILLIMETERS', 'VIEW')

      # CẢNH BÁO KHỔ VÁN TIÊU CHUẨN CNC 1220x2440MM (HIỂN THỊ TRỰC TIẾP TRONG COMPONENT OPTIONS)
      is_over = (l_mm > 2440.0 || w_mm > 2440.0 || h_mm > 2440.0)
      status_txt = is_over ? "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!" : "✅ ĐẠT CHUẨN CNC (1220x2440mm)"
      comp_def.set_attribute(DICT_DC, 'canh_bao_kho_van', status_txt)
      comp_def.set_attribute(DICT_DC, '_canh_bao_kho_van_access', 'VIEW')
      comp_def.set_attribute(DICT_DC, '_canh_bao_kho_van_label', 'Kiểm Tra Khổ Ván CNC')
      comp_def.set_attribute(DICT_DC, '_canh_bao_kho_van_formlabel', 'Trạng Thái Khổ Ván 1220x2440mm')
      comp_def.set_attribute(DICT_DC, '_canh_bao_kho_van_formula', 'IF(OR(LenX>96.06, LenY>96.06, LenZ>96.06), "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!", "✅ ĐẠT CHUẨN CNC (1220x2440mm)")')
    end

    def self.setup_dc_attr(comp_def, attr, val, label, units = 'MILLIMETERS', access = 'TEXTBOX')
      comp_def.set_attribute(DICT_DC, attr, val.to_f)
      comp_def.set_attribute(DICT_DC, "_#{attr}_access", access)
      comp_def.set_attribute(DICT_DC, "_#{attr}_label", label)
      comp_def.set_attribute(DICT_DC, "_#{attr}_formlabel", label)
      comp_def.set_attribute(DICT_DC, "_#{attr}_units", units)
    end
  end
end
