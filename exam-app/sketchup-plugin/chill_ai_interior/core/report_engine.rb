# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Report Engine (Chuyên Gia Thống Kê & Báo Giá Vật Tư Chuẩn ABF)
# Cung cấp 2 Tab chuyên nghiệp:
#   - Tab 1: Phụ Kiện & Bảng Dự Toán Chi Phí (Phụ kiện, Tiết diện ngàm, Chỉ dán, Tấm, Chi phí khác)
#   - Tab 2: Cấu Kiện & Danh Sách Tấm Ván Cắt CNC (CutList chi tiết: LxWxT, Vân, Dán cạnh, Mặt phay)
# Xuất trực tiếp file Excel (.xls) tương thích 100% Microsoft Excel & Google Sheets
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module ReportEngine
    COST_FILE = File.join(File.dirname(__FILE__), '..', 'knowledge_base', 'cost_presets.json')
    SHEET_AREA_SQM = 1.22 * 2.44 # 2.9768 m2/khổ ván tiêu chuẩn 1220x2440

    # 1. ĐỌC & LƯU CẤU HÌNH ĐƠN GIÁ MẶC ĐỊNH
    def self.load_cost_presets
      if File.exist?(COST_FILE)
        begin
          data = JSON.parse(File.read(COST_FILE, encoding: 'UTF-8'))
          return data if data.is_a?(Hash) && !data.empty?
        rescue => e
          puts "[Chill AI ReportEngine] Lỗi đọc cost_presets.json: #{e.message}"
        end
      end
      default_cost_structure
    end

    def self.save_cost_presets(cost_data)
      dir = File.dirname(COST_FILE)
      Dir.mkdir(dir) unless Dir.exist?(dir)
      File.open(COST_FILE, 'w:UTF-8') do |f|
        f.write(JSON.pretty_generate(cost_data))
      end
      { "status" => "success", "message" => "Đã lưu bảng đơn giá mẫu thành công!" }
    rescue => e
      { "status" => "error", "message" => e.message }
    end

    # 2. THU THẬP TOÀN BỘ SỐ LIỆU TỪ MÔ HÌNH SKETCHUP
    def self.collect_statistics(selection_only = false)
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy mô hình SketchUp!" } unless model

      target_ents = []
      if selection_only && model.selection && model.selection.count > 0
        model.selection.each { |e| target_ents << e }
      else
        target_ents = (model.selection && model.selection.count > 0) ? model.selection.to_a : model.active_entities.to_a
      end

      # A. Thu thập các tấm ván lá mộc
      leaf_parts = []
      if defined?(LabelingEngine)
        target_ents.each do |ent|
          next if ent.name.to_s.start_with?("CHILL_AI_NESTING")
          LabelingEngine.collect_leaf_panels(ent, leaf_parts)
        end
      end

      # Đếm Module tủ
      module_count = 0
      target_ents.each do |ent|
        module_count += 1 if defined?(RenameEngine) && RenameEngine.is_module_assembly(ent)
      end
      module_count = 1 if module_count == 0 && leaf_parts.any?

      # B. Đếm phụ kiện liên kết (Cam chốt, Dowel, Bản lề)
      cam_count = 0
      dowel_count = 0
      hinge_count = 0

      # Quét các group con bên trong từng tấm ván hoặc trong model
      leaf_parts.each do |p|
        ent = p[:entity]
        next unless ent && ent.valid?
        ents_pool = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.respond_to?(:definition) ? ent.definition.entities : [])

        # 1. Đếm từ group Chill_AI_Fittings / ABF_Minifix
        fittings_grps = ents_pool.grep(Sketchup::Group).select { |g| g.name =~ /^(Chill_AI_Fitting|ABF_Minifix)/i }
        fittings_grps.each do |fg|
          sub_pool = fg.entities
          cams = sub_pool.grep(Sketchup::Group).select { |sg| sg.layer.name =~ /CAM_15/i || sg.name =~ /cam/i }
          cam_count += [cams.length, 1].max
          dowels = sub_pool.grep(Sketchup::Group).select { |sg| sg.layer.name =~ /DOWEL_8/i || sg.name =~ /dowel/i }
          dowel_count += dowels.length
        end

        # 2. Đếm từ group Chill_AI_Hinges / Hinge
        hinge_grps = ents_pool.grep(Sketchup::Group).select { |g| g.name =~ /^(Chill_AI_Hinge|Chill_AI_Joint)/i }
        hinge_grps.each do |hg|
          if hg.name =~ /Hinge/i || hg.layer.name =~ /HINGE/i
            hinge_count += 1
          end
        end

        # 3. Thuộc tính đã lưu
        c_cam = ent.get_attribute("Chill_AI_Fitting", "cam_count")
        cam_count += c_cam.to_i if c_cam

        c_hinge = ent.get_attribute("Chill_AI_Fitting", "hinge_count")
        hinge_count += c_hinge.to_i if c_hinge
      end

      # Tự động ước lượng thông minh nếu mô hình mộc cơ bản chưa khoan cam:
      # Trung bình 1 liên kết ván gồm 4-6 bộ cam chốt
      if cam_count == 0 && leaf_parts.length >= 3
        # Ước lượng: trung bình mỗi tấm đợt/đáy có 4 cam chốt
        cam_count = [leaf_parts.length * 2, 4].max
        dowel_count = cam_count
      end

      # C. Đếm rãnh tiết diện giao nhau (Rãnh ngàm âm dương, rãnh hậu, rãnh LED)
      intersect_grooves = 0
      intersect_len_m = 0.0
      back_grooves = 0
      back_len_m = 0.0

      leaf_parts.each do |p|
        ent = p[:entity]
        next unless ent && ent.valid?
        ents_pool = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.respond_to?(:definition) ? ent.definition.entities : [])

        groove_grps = ents_pool.grep(Sketchup::Group).select { |g| g.name =~ /^(_ABF_INTERSECT|Chill_AI_Joint)/i }
        groove_grps.each do |gg|
          bb = gg.bounds
          len = [bb.width, bb.height, bb.depth].max.to_mm / 1000.0
          if gg.layer.name =~ /RANH_HAU/i
            back_grooves += 1
            back_len_m += len
          else
            intersect_grooves += 1
            intersect_len_m += len
          end
        end
      end

      # Nếu mô hình có tấm hậu thì tự động tính mét rãnh hậu
      if back_len_m == 0.0
        back_panels = leaf_parts.select { |p| p[:t] <= 10.0 }
        back_panels.each do |bp|
          back_len_m += (bp[:l] + bp[:w]) * 2 / 1000.0
          back_grooves += 1
        end
      end

      # D. Tính tổng mét chỉ dán cạnh (Nẹp PVC)
      total_edge_m = 0.0
      leaf_parts.each do |p|
        # 4 cạnh = 2 dài + 2 rộng
        perimeter_m = (p[:l] * 2.0 + p[:w] * 2.0) / 1000.0
        total_edge_m += perimeter_m
      end

      # E. Thống kê theo khổ ván (1220x2440) và phân loại độ dày
      sheets_by_thick = {}
      components_list = []

      leaf_parts.each_with_index do |p, idx|
        ent = p[:entity]
        raw_name = p[:original_name]
        clean_n = defined?(LabelingEngine) ? LabelingEngine.clean_raw_name(raw_name) : raw_name
        clean_n = "Tấm ván #{idx + 1}" if clean_n.empty?

        l = p[:l].to_f.round(1)
        w = p[:w].to_f.round(1)
        t = normalize_thickness(p[:t].to_f)

        area_sqm = (l * w) / 1_000_000.0

        sheets_by_thick[t] ||= { total_area: 0.0, parts_count: 0 }
        sheets_by_thick[t][:total_area] += area_sqm
        sheets_by_thick[t][:parts_count] += 1

        id_num = ent.get_attribute("Chill_AI_CNC", "id_number") || (idx + 1)
        part_code = ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)
        grain_mode = ent.get_attribute("Chill_AI_CNC", "grain") || "length"
        grain_angle = (ent.get_attribute("Chill_AI_CNC", "grain_angle") || 0.0).to_f
        grain_str = (grain_angle == 90.0 || grain_mode == "width") ? "Vân Ngang ⬌" : "Vân Dọc ⬍"

        face_str = (ent.get_attribute("Chill_AI_CNC", "machining_face") == "bottom") ? "Mặt Dưới ⤵" : "Mặt Trên ⤴"

        components_list << {
          "stt" => idx + 1,
          "id" => part_code,
          "name" => clean_n,
          "l" => l,
          "w" => w,
          "t" => t,
          "qty" => 1,
          "grain" => grain_str,
          "edge_band" => (ent.get_attribute('ABF_EDGE_BANDING', 'edge_band_summary') || (ent.respond_to?(:definition) ? ent.definition.get_attribute('ABF_EDGE_BANDING', 'edge_band_summary') : nil) || "Không dán"),
          "face" => face_str,
          "area" => area_sqm.round(3),
          "material" => "MDF Lõi Xanh Melamine #{t.to_i}mm"
        }
      end

      # Đọc đơn giá và ghép thành bảng Phụ Kiện hoàn chỉnh
      cost_cfg = load_cost_presets
      accessories_table = build_accessories_table(
        leaf_parts.length,
        module_count,
        cam_count,
        dowel_count,
        hinge_count,
        intersect_grooves,
        intersect_len_m,
        back_grooves,
        back_len_m,
        total_edge_m,
        sheets_by_thick,
        cost_cfg
      )

      {
        "status" => "success",
        "total_parts" => leaf_parts.length,
        "total_modules" => module_count,
        "accessories" => accessories_table,
        "components" => components_list,
        "cost_presets" => cost_cfg
      }
    rescue => e
      puts "[Chill AI ReportEngine Collect Error]: #{e.message}\n#{e.backtrace.join("\n")}"
      { "status" => "error", "message" => e.message }
    end

    # 3. DỰNG BẢNG PHỤ KIỆN VÀ CHI PHÍ ĐẦY ĐỦ 6 NHÓM
    def self.build_accessories_table(parts_qty, mod_qty, cam_qty, dowel_qty, hinge_qty, inter_qty, inter_m, back_qty, back_m, edge_m, sheets_dict, cost_cfg)
      rows = []
      stt = 1

      # ------------------------------------------------------------------------
      # NHÓM 1: PHỤ KIỆN LIÊN KẾT
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "PHỤ KIỆN LIÊN KẾT", "total" => 0 }

      hw = cost_cfg["hardware_costs"] || {}
      # Cam liên kết
      c_cam = hw["cam_minifix"] || { "name" => "Cam liên kết (Ốc cam + chốt)", "unit" => "bộ", "price" => 2500, "factor" => 1.0 }
      amt_cam = (cam_qty * c_cam["price"].to_f * c_cam["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Phụ kiện", "name" => c_cam["name"],
        "qty" => cam_qty, "unit" => c_cam["unit"], "price" => c_cam["price"],
        "factor" => c_cam["factor"], "amount" => amt_cam, "key" => "cam_minifix"
      }
      stt += 1

      # Chốt gỗ
      c_dowel = hw["wooden_dowel"] || { "name" => "Chốt gỗ (Dowel 8x30mm)", "unit" => "cái", "price" => 500, "factor" => 1.0 }
      amt_dowel = (dowel_qty * c_dowel["price"].to_f * c_dowel["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Phụ kiện", "name" => c_dowel["name"],
        "qty" => dowel_qty, "unit" => c_dowel["unit"], "price" => c_dowel["price"],
        "factor" => c_dowel["factor"], "amount" => amt_dowel, "key" => "wooden_dowel"
      }
      stt += 1

      # Bản lề
      if hinge_qty > 0
        c_hinge = hw["hinge_soft_close"] || { "name" => "Bản lề giảm chấn chén 35mm", "unit" => "cái", "price" => 25000, "factor" => 1.0 }
        amt_hinge = (hinge_qty * c_hinge["price"].to_f * c_hinge["factor"].to_f).round
        rows << {
          "stt" => stt, "type" => "Phụ kiện", "name" => c_hinge["name"],
          "qty" => hinge_qty, "unit" => c_hinge["unit"], "price" => c_hinge["price"],
          "factor" => c_hinge["factor"], "amount" => amt_hinge, "key" => "hinge_soft_close"
        }
        stt += 1
      end

      # Vít liên kết
      screw_qty = [parts_qty * 4, 12].max
      c_screw = hw["screw_4x50"] || { "name" => "Vít liên kết 4x50mm", "unit" => "cái", "price" => 300, "factor" => 1.0 }
      amt_screw = (screw_qty * c_screw["price"].to_f * c_screw["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Phụ kiện", "name" => c_screw["name"],
        "qty" => screw_qty, "unit" => c_screw["unit"], "price" => c_screw["price"],
        "factor" => c_screw["factor"], "amount" => amt_screw, "key" => "screw_4x50"
      }
      stt += 1

      # ------------------------------------------------------------------------
      # NHÓM 2: TIẾT DIỆN GIAO NHAU
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "TIẾT DIỆN GIAO NHAU", "total" => 0 }

      ic = cost_cfg["intersect_costs"] || {}
      # Rãnh ngàm âm dương
      inter_m_round = [inter_m.round(2), (inter_qty * 0.45).round(2)].max
      c_inter = ic["groove_joint"] || { "name" => "Rãnh ngàm âm dương (Overcut 3.5mm)", "unit" => "m", "price" => 15000, "factor" => 1.0 }
      amt_inter = (inter_m_round * c_inter["price"].to_f * c_inter["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Tiết diện", "name" => c_inter["name"],
        "qty" => inter_m_round, "unit" => c_inter["unit"], "price" => c_inter["price"],
        "factor" => c_inter["factor"], "amount" => amt_inter, "key" => "groove_joint"
      }
      stt += 1

      # Rãnh soi hậu
      if back_m > 0 || back_qty > 0
        back_m_round = back_m.round(2)
        c_back = ic["groove_back"] || { "name" => "Rãnh soi hậu ván 9mm/6mm", "unit" => "m", "price" => 10000, "factor" => 1.0 }
        amt_back = (back_m_round * c_back["price"].to_f * c_back["factor"].to_f).round
        rows << {
          "stt" => stt, "type" => "Tiết diện", "name" => c_back["name"],
          "qty" => back_m_round, "unit" => c_back["unit"], "price" => c_back["price"],
          "factor" => c_back["factor"], "amount" => amt_back, "key" => "groove_back"
        }
        stt += 1
      end

      # ------------------------------------------------------------------------
      # NHÓM 3: ĐỐI TƯỢNG THỐNG KÊ
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "ĐỐI TƯỢNG THỐNG KÊ", "total" => 0 }

      rows << {
        "stt" => stt, "type" => "Thống kê", "name" => "Tổng số cụm Module / Khối tủ",
        "qty" => mod_qty, "unit" => "khối", "price" => 0,
        "factor" => 1.0, "amount" => 0, "key" => "stat_modules"
      }
      stt += 1

      rows << {
        "stt" => stt, "type" => "Thống kê", "name" => "Tổng số chi tiết tấm ván mộc",
        "qty" => parts_qty, "unit" => "tấm chi tiết", "price" => 0,
        "factor" => 1.0, "amount" => 0, "key" => "stat_parts"
      }
      stt += 1

      # ------------------------------------------------------------------------
      # NHÓM 4: CHỈ DÁN CẠNH
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "CHỈ DÁN CẠNH", "total" => 0 }

      eb = cost_cfg["edge_band_costs"] || {}
      edge_m_round = edge_m.round(1)
      c_edge = eb["edge_1mm"] || { "name" => "Chỉ dán cạnh dày (Nẹp PVC 1.0mm)", "unit" => "m", "price" => 6000, "factor" => 1.0 }
      amt_edge = (edge_m_round * c_edge["price"].to_f * c_edge["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Chỉ dán", "name" => c_edge["name"],
        "qty" => edge_m_round, "unit" => c_edge["unit"], "price" => c_edge["price"],
        "factor" => c_edge["factor"], "amount" => amt_edge, "key" => "edge_1mm"
      }
      stt += 1

      c_labor_edge = eb["edge_labor"] || { "name" => "Công dán nẹp tự động & phay bo góc", "unit" => "m", "price" => 5000, "factor" => 1.0 }
      amt_labor_edge = (edge_m_round * c_labor_edge["price"].to_f * c_labor_edge["factor"].to_f).round
      rows << {
        "stt" => stt, "type" => "Chỉ dán", "name" => c_labor_edge["name"],
        "qty" => edge_m_round, "unit" => c_labor_edge["unit"], "price" => c_labor_edge["price"],
        "factor" => c_labor_edge["factor"], "amount" => amt_labor_edge, "key" => "edge_labor"
      }
      stt += 1

      # ------------------------------------------------------------------------
      # NHÓM 5: TẤM (QUY ĐỔI KHỔ VÁN 1220x2440 TIÊU CHUẨN)
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "TẤM", "total" => 0 }

      sc = cost_cfg["sheet_costs"] || {}
      total_cnc_sheets = 0

      sheets_dict.each do |thick, sdata|
        area_m2 = sdata[:total_area]
        # Hệ số hao hụt phôi ván 15% (1.15)
        needed_sheets = (area_m2 * 1.15 / SHEET_AREA_SQM).ceil
        needed_sheets = 1 if needed_sheets == 0 && area_m2 > 0
        total_cnc_sheets += needed_sheets

        cfg_key = if thick >= 20.0
                    "mdf_25"
                  elsif thick >= 14.0
                    "mdf_17"
                  elsif thick >= 8.0
                    "mdf_9"
                  else
                    "mdf_6"
                  end

        c_sheet = sc[cfg_key] || { "name" => "Ván MDF Melamine #{thick.to_i}mm (1220x2440)", "unit" => "tấm", "price" => 450000, "factor" => 1.0 }
        amt_sheet = (needed_sheets * c_sheet["price"].to_f * c_sheet["factor"].to_f).round

        desc = "#{c_sheet["name"]} (Diện tích: #{area_m2.round(2)} m²)"
        rows << {
          "stt" => stt, "type" => "Khổ ván", "name" => desc,
          "qty" => needed_sheets, "unit" => c_sheet["unit"], "price" => c_sheet["price"],
          "factor" => c_sheet["factor"], "amount" => amt_sheet, "key" => cfg_key
        }
        stt += 1
      end

      # ------------------------------------------------------------------------
      # NHÓM 6: CHI PHÍ KHÁC (Gia công CNC, Đóng gói, Vận chuyển, Lắp đặt)
      # ------------------------------------------------------------------------
      rows << { "is_header" => true, "category" => "CHI PHÍ KHÁC", "total" => 0 }

      others = cost_cfg["other_costs"] || []
      others.each do |item|
        qty = item["qty"] || 1
        qty = total_cnc_sheets if item["name"] =~ /Nesting CNC/i && total_cnc_sheets > 0
        price = item["price"].to_f
        factor = (item["factor"] || 1.0).to_f
        amt = (qty * price * factor).round

        rows << {
          "stt" => stt, "type" => "Chi phí khác", "name" => item["name"],
          "qty" => qty, "unit" => item["unit"], "price" => price.to_i,
          "factor" => factor, "amount" => amt, "key" => "other_#{stt}"
        }
        stt += 1
      end

      # Tính tổng từng nhóm và tổng chi phí toàn dự án
      calculate_totals(rows)
      rows
    end

    # Tính toán tổng tiền theo từng nhóm danh mục và tổng chi phí chung
    def self.calculate_totals(rows)
      current_header = nil
      current_group_total = 0
      grand_total = 0

      rows.each do |r|
        if r["is_header"]
          if current_header
            current_header["total"] = current_group_total
          end
          current_header = r
          current_group_total = 0
        else
          amt = (r["amount"] || 0).to_i
          current_group_total += amt
          grand_total += amt
        end
      end

      current_header["total"] = current_group_total if current_header
      grand_total
    end

    # 4. XUẤT RA EXCEL (.XLS) ĐẦY ĐỦ 2 BẢNG BIỂU ĐẸP MẮT
    def self.export_to_excel(stats_data, default_name = nil)
      default_filename = default_name || "BANG_THONG_KE_CHILL_AI_#{Time.now.strftime('%d%m_%H%M%S')}.xls"
      chosen_path = UI.savepanel("Xuất Bảng Thống Kê & Báo Giá Sang Excel", "", default_filename)
      return { "status" => "cancelled" } unless chosen_path

      chosen_path += ".xls" unless chosen_path.downcase.end_with?(".xls", ".xlsx")

      html_excel = build_html_excel_content(stats_data)
      File.open(chosen_path, "w:UTF-8") do |f|
        f.write(html_excel)
      end

      UI.messagebox("Đã xuất file Excel thành công tại:\n#{chosen_path}\nBạn có thể mở trực tiếp bằng Microsoft Excel hoặc Google Sheets!")
      { "status" => "success", "path" => chosen_path }
    rescue => e
      UI.messagebox("Lỗi khi xuất file Excel: #{e.message}")
      { "status" => "error", "message" => e.message }
    end

    # Dựng nội dung Excel HTML Spreadsheet chuẩn MIME tương thích 100% Microsoft Excel
    def self.build_html_excel_content(data)
      accessories = data["accessories"] || []
      components = data["components"] || []
      time_str = Time.now.strftime("%d/%m/%Y %H:%M")

      grand_total = 0
      accessories.each { |r| grand_total += (r["amount"] || 0).to_i unless r["is_header"] }

      html = <<~HTML
        <html xmlns:o="urn:schemas-microsoft-com:office:office"
              xmlns:x="urn:schemas-microsoft-com:office:excel"
              xmlns="http://www.w3.org/TR/REC-html40">
        <head>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
          <style>
            body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 11pt; }
            table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
            th, td { border: 0.5pt solid #cbd5e1; padding: 6px 10px; }
            th { background-color: #0284c7; color: #ffffff; font-weight: bold; text-align: center; }
            .header-cat { background-color: #e2e8f0; font-weight: bold; color: #0f172a; }
            .text-center { text-align: center; }
            .text-right { text-align: right; }
            .font-bold { font-weight: bold; }
            .title-main { font-size: 16pt; font-weight: bold; color: #0369a1; text-align: center; padding: 10px 0; }
            .sub-title { font-size: 10pt; color: #64748b; text-align: center; margin-bottom: 15px; }
            .grand-total { background-color: #fef08a; font-weight: bold; font-size: 12pt; color: #854d0e; }
          </style>
        </head>
        <body>
          <div class="title-main">BẢNG DỰ TOÁN VẬT TƯ & PHỤ KIỆN NỘI THẤT</div>
          <div class="sub-title">Chill AI Interior (Chuẩn ABF) - Xuất ngày: #{time_str}</div>

          <!-- BẢNG 1: PHỤ KIỆN & CHI PHÍ -->
          <table>
            <thead>
              <tr>
                <th style="width: 50px;">STT</th>
                <th style="width: 120px;">Loại</th>
                <th style="width: 320px;">Mô tả chi tiết</th>
                <th style="width: 80px;">Số lượng</th>
                <th style="width: 80px;">Đơn vị</th>
                <th style="width: 120px;">Đơn giá (VNĐ)</th>
                <th style="width: 70px;">Hệ số</th>
                <th style="width: 140px;">Thành tiền (VNĐ)</th>
                <th style="width: 140px;">Tổng Nhóm</th>
              </tr>
            </thead>
            <tbody>
      HTML

      accessories.each do |row|
        if row["is_header"]
          tot_str = format_currency(row["total"])
          html << <<~ROW
            <tr class="header-cat">
              <td colspan="8">#{row["category"]}</td>
              <td class="text-right font-bold">#{tot_str}</td>
            </tr>
          ROW
        else
          amt_str = format_currency(row["amount"])
          price_str = format_currency(row["price"])
          html << <<~ROW
            <tr>
              <td class="text-center">#{row["stt"]}</td>
              <td>#{row["type"]}</td>
              <td>#{row["name"]}</td>
              <td class="text-center">#{row["qty"]}</td>
              <td class="text-center">#{row["unit"]}</td>
              <td class="text-right">#{price_str}</td>
              <td class="text-center">#{row["factor"]}</td>
              <td class="text-right font-bold">#{amt_str}</td>
              <td></td>
            </tr>
          ROW
        end
      end

      grand_str = format_currency(grand_total)
      html << <<~HTML
            <tr class="grand-total">
              <td colspan="7" class="text-right font-bold">TỔNG CHI PHÍ DỰ ÁN:</td>
              <td colspan="2" class="text-right font-bold">#{grand_str} VNĐ</td>
            </tr>
            </tbody>
          </table>

          <br /><br />
          <!-- BẢNG 2: DANH SÁCH CẤU KIỆN TẤM VÁN CẮT CNC (CUTLIST) -->
          <div class="title-main" style="color:#0f766e;">DANH SÁCH CẤU KIỆN TẤM VÁN CẮT CNC</div>
          <div class="sub-title">Tổng số chi tiết: #{components.length} tấm</div>

          <table>
            <thead>
              <tr style="background-color: #0f766e;">
                <th style="width: 45px;">STT</th>
                <th style="width: 75px;">Mã</th>
                <th style="width: 250px;">Tên tấm ván</th>
                <th style="width: 85px;">Dài (mm)</th>
                <th style="width: 85px;">Rộng (mm)</th>
                <th style="width: 75px;">Dày (mm)</th>
                <th style="width: 60px;">SL</th>
                <th style="width: 110px;">Chiều vân</th>
                <th style="width: 140px;">Dán cạnh</th>
                <th style="width: 110px;">Mặt gia công</th>
                <th style="width: 95px;">Diện tích (m²)</th>
                <th style="width: 180px;">Vật liệu</th>
              </tr>
            </thead>
            <tbody>
      HTML

      total_area_sqm = 0.0
      components.each do |c|
        total_area_sqm += c["area"].to_f
        html << <<~ROW
          <tr>
            <td class="text-center">#{c["stt"]}</td>
            <td class="text-center font-bold">#{c["id"]}</td>
            <td>#{c["name"]}</td>
            <td class="text-right">#{c["l"]}</td>
            <td class="text-right">#{c["w"]}</td>
            <td class="text-center font-bold">#{c["t"]}</td>
            <td class="text-center">#{c["qty"]}</td>
            <td class="text-center">#{c["grain"]}</td>
            <td class="text-center">#{c["edge_band"]}</td>
            <td class="text-center">#{c["face"]}</td>
            <td class="text-right">#{c["area"]}</td>
            <td>#{c["material"]}</td>
          </tr>
        ROW
      end

      html << <<~HTML
            <tr class="header-cat">
              <td colspan="6" class="font-bold">TỔNG CỘNG DIỆN TÍCH PHÔI VÁN:</td>
              <td class="text-center font-bold">#{components.length}</td>
              <td colspan="3"></td>
              <td class="text-right font-bold">#{total_area_sqm.round(2)} m²</td>
              <td></td>
            </tr>
            </tbody>
          </table>
        </body>
        </html>
      HTML

      html
    end

    def self.format_currency(num)
      num.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def self.normalize_thickness(t)
      val = t.to_f
      if val <= 7.0
        6.0
      elsif val <= 10.5
        9.0
      elsif val <= 13.5
        12.0
      elsif val <= 19.5
        17.0
      elsif val <= 26.0
        25.0
      else
        val.round(1)
      end
    end

    def self.default_cost_structure
      {
        "currency" => "VNĐ",
        "hardware_costs" => {},
        "intersect_costs" => {},
        "edge_band_costs" => {},
        "sheet_costs" => {},
        "other_costs" => []
      }
    end
  end
end
