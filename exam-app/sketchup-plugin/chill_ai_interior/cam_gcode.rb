# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - CAM & G-Code CNC Exporter
# Tự động bóc tách tấm 2D (Nesting) & Xuất file G-Code cho máy phay CNC gỗ
# ==============================================================================

module ChillAIInterior
  module CamGCodeExporter
    SHEET_W = 1220.0 # Chiều rộng khổ ván công nghiệp tiêu chuẩn (mm)
    SHEET_H = 2440.0 # Chiều dài khổ ván công nghiệp tiêu chuẩn (mm)
    BORDER_MARGIN = 10.0 # Chừa lề mép ván (mm)
    BIT_KERF = 6.0       # Độ dày mạch cắt mũi dao phay (mm)

    def self.process(params)
      # 1. Thu thập danh sách các chi tiết tấm phẳng từ thông số hoặc mô hình
      parts = extract_parts(params)

      # 2. Thuật toán xếp ván tối ưu 2D (Nesting Algorithm)
      nested_data = perform_nesting(parts)

      # 3. Tạo mã lệnh G-Code tiêu chuẩn ISO
      gcode_str = generate_iso_gcode(nested_data, params)

      {
        "status" => "success",
        "sheet_w" => SHEET_W,
        "sheet_h" => SHEET_H,
        "total_parts" => parts.length,
        "sheets" => nested_data[:sheets],
        "utilization" => nested_data[:utilization],
        "cut_length_m" => nested_data[:total_perimeter_m],
        "estimated_time_min" => nested_data[:estimated_time_min],
        "gcode" => gcode_str
      }
    end

    # --- 1. Sinh danh sách chi tiết tấm phôi ---
    def self.extract_parts(params)
      type = (params['type'] || 'desk').to_s.downcase
      l = (params['length'] || 1200).to_f
      w = (params['width']  || 600).to_f
      h = (params['height'] || 750).to_f
      t = (params['thickness'] || 18).to_f

      parts = []
      case type
      when 'desk', 'table'
        parts << { name: "Mặt bàn chính", w: l, h: w, t: t, color: "#d97706" }
        parts << { name: "Yếm bàn dài 1", w: l - 100, h: 100, t: t, color: "#b45309" }
        parts << { name: "Yếm bàn dài 2", w: l - 100, h: 100, t: t, color: "#b45309" }
        parts << { name: "Yếm hông trái", w: w - 100, h: 100, t: t, color: "#92400e" }
        parts << { name: "Yếm hông phải", w: w - 100, h: 100, t: t, color: "#92400e" }
        if (params['drawers'] || 0).to_i > 0
          dr_num = params['drawers'].to_i
          parts << { name: "Hông hộc tủ trái", w: w - 50, h: 420, t: t, color: "#78350f" }
          parts << { name: "Hông hộc tủ phải", w: w - 50, h: 420, t: t, color: "#78350f" }
          parts << { name: "Đáy hộc tủ", w: 380, h: w - 50, t: t, color: "#78350f" }
          dr_num.times do |i|
            parts << { name: "Mặt ngăn kéo #{i+1}", w: 370, h: (400 / dr_num).round - 5, t: t, color: "#f59e0b" }
          end
        end
      when 'wardrobe', 'cabinet'
        parts << { name: "Hông tủ trái", w: h, h: w, t: t, color: "#1e3a8a" }
        parts << { name: "Hông tủ phải", w: h, h: w, t: t, color: "#1e3a8a" }
        parts << { name: "Đáy tủ", w: l - 2 * t, h: w, t: t, color: "#1d4ed8" }
        parts << { name: "Nóc tủ", w: l - 2 * t, h: w, t: t, color: "#1d4ed8" }
        parts << { name: "Đợt chia ngang 1", w: l - 2 * t, h: w - 15, t: t, color: "#2563eb" }
        parts << { name: "Đợt chia ngang 2", w: l - 2 * t, h: w - 15, t: t, color: "#2563eb" }
        doors = (params['doors'] || 2).to_i
        door_w = (l - 6) / doors
        doors.times do |i|
          parts << { name: "Cánh tủ #{i+1}", w: h - 70, h: door_w, t: t, color: "#60a5fa" }
        end
      else
        # Kệ / Mẫu chung
        parts << { name: "Tấm mặt đỉnh", w: l, h: w, t: t, color: "#047857" }
        parts << { name: "Tấm đáy", w: l, h: w, t: t, color: "#059669" }
        parts << { name: "Hông trái", w: h - 2 * t, h: w, t: t, color: "#10b981" }
        parts << { name: "Hông phải", w: h - 2 * t, h: w, t: t, color: "#10b981" }
        parts << { name: "Đợt giữa", w: l - 2 * t, h: w, t: t, color: "#34d399" }
      end
      parts
    end

    # --- 2. Thuật toán Xếp ván 2D (Shelf Bin Packing) ---
    def self.perform_nesting(parts)
      # Sắp xếp các chi tiết theo chiều dài giảm dần
      sorted_parts = parts.sort_by { |p| -[p[:w], p[:h]].max }

      sheets = []
      current_sheet = { id: 1, items: [], used_area: 0.0 }
      
      cur_x = BORDER_MARGIN
      cur_y = BORDER_MARGIN
      shelf_height = 0.0

      sorted_parts.each do |part|
        # Luôn định hướng chiều dài dọc theo thớ gỗ (hoặc xoay để vừa khổ ván)
        p_len = [part[:w], part[:h]].max
        p_wid = [part[:w], part[:h]].min

        # Kiểm tra xem có vừa vào hàng hiện tại không
        if (cur_x + p_wid + BIT_KERF) > (SHEET_W - BORDER_MARGIN)
          # Hết chỗ theo chiều ngang -> Xuống dòng mới (new shelf)
          cur_x = BORDER_MARGIN
          cur_y += shelf_height + BIT_KERF
          shelf_height = 0.0
        end

        # Kiểm tra xem có vượt quá chiều dài khổ ván không
        if (cur_y + p_len + BIT_KERF) > (SHEET_H - BORDER_MARGIN)
          # Hết tấm ván hiện tại -> Sang tấm ván tiếp theo
          sheets << current_sheet
          current_sheet = { id: sheets.length + 1, items: [], used_area: 0.0 }
          cur_x = BORDER_MARGIN
          cur_y = BORDER_MARGIN
          shelf_height = 0.0
        end

        # Đặt tấm chi tiết vào tọa độ
        current_sheet[:items] << {
          name: part[:name],
          x: cur_x.round(1),
          y: cur_y.round(1),
          w: p_wid.round(1),
          h: p_len.round(1),
          t: part[:t],
          color: part[:color]
        }

        current_sheet[:used_area] += (p_wid * p_len)
        cur_x += p_wid + BIT_KERF
        shelf_height = [shelf_height, p_len].max
      end

      sheets << current_sheet unless current_sheet[:items].empty?

      total_part_area = parts.reduce(0.0) { |sum, p| sum + (p[:w] * p[:h]) }
      total_sheet_area = sheets.length * (SHEET_W * SHEET_H)
      utilization = ((total_part_area / total_sheet_area) * 100.0).round(1)

      total_perimeter_mm = parts.reduce(0.0) { |sum, p| sum + 2 * (p[:w] + p[:h]) }
      total_perimeter_m = (total_perimeter_mm / 1000.0).round(2)

      # Ước tính thời gian cắt (Tốc độ cắt trung bình F=2400mm/phút, cắt 2 pass)
      feed_rate = 2400.0
      cut_time_min = ((total_perimeter_mm * 2) / feed_rate + (parts.length * 0.3)).round(1)

      {
        sheets: sheets,
        utilization: utilization,
        total_perimeter_m: total_perimeter_m,
        estimated_time_min: cut_time_min
      }
    end

    # --- 3. Trình tạo mã G-Code (ISO CNC Code) ---
    def self.generate_iso_gcode(nested_data, params)
      thickness = (params['thickness'] || 18.0).to_f
      spindle_speed = 18000
      cut_feed = 2400
      plunge_feed = 800
      safe_z = 15.0
      pass1_z = -(thickness / 2.0).round(2)
      pass2_z = -(thickness + 0.5).round(2) # Cắt thủng ván thêm 0.5mm xuống mặt bàn hút chân không

      lines = []
      lines << "( ========================================================== )"
      lines << "(  CHILL AI INTERIOR - G-CODE GENERATOR FOR CNC ROUTER       )"
      lines << "(  NGÀY XUẤT: #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}                     )"
      lines << "(  KHỔ VÁN: #{SHEET_W.to_i} x #{SHEET_H.to_i} x #{thickness.to_i} mm                      )"
      lines << "(  SỐ TẤM VÁN: #{nested_data[:sheets].length} | HIỆU SUẤT XẾP: #{nested_data[:utilization]}%      )"
      lines << "(  DAO CẮT: MŨI PHAY TRỰC TIẾP ENDMILL D6 (ĐƯỜNG KÍNH 6mm)     )"
      lines << "( ========================================================== )"
      lines << ""
      lines << "G90 G21 G17 G54 (TOA DO TUYET DOI - HE MET - MAT PHANG XY)"
      lines << "G00 Z#{safe_z} (NANG DAO AN TOAN)"
      lines << "M03 S#{spindle_speed} (KHOI DONG TRUC CHINH #{spindle_speed} RPM)"
      lines << "G04 P2 (DUNG 2 GIAY CHO TRUC DAT TOC DO TOI DA)"
      lines << ""

      nested_data[:sheets].each_with_index do |sheet, s_idx|
        lines << "( ---------------------------------------------------------- )"
        lines << "( BAT DAU CAT TAM VAN THU #{s_idx + 1} - TONG SO CHI TIET: #{sheet[:items].length} )"
        lines << "( ---------------------------------------------------------- )"

        sheet[:items].each_with_index do |item, p_idx|
          x1 = item[:x]
          y1 = item[:y]
          x2 = item[:x] + item[:w]
          y2 = item[:y] + item[:h]

          lines << ""
          lines << "( CHI TIET #{p_idx + 1}: #{item[:name]} [#{item[:w]}x#{item[:h]}mm] )"
          
          # Di chuyển không ăn phôi đến góc bắt đầu
          lines << "G00 X#{x1} Y#{y1}"
          
          # --- Pass 1: Cắt phá nửa độ dày ván ---
          lines << "G01 Z#{pass1_z} F#{plunge_feed}"
          lines << "G01 X#{x2} Y#{y1} F#{cut_feed}"
          lines << "G01 X#{x2} Y#{y2}"
          lines << "G01 X#{x1} Y#{y2}"
          lines << "G01 X#{x1} Y#{y1}"

          # --- Pass 2: Cắt đứt hoàn toàn ---
          lines << "G01 Z#{pass2_z} F#{plunge_feed}"
          lines << "G01 X#{x2} Y#{y1} F#{cut_feed}"
          lines << "G01 X#{x2} Y#{y2}"
          lines << "G01 X#{x1} Y#{y2}"
          lines << "G01 X#{x1} Y#{y1}"

          # Nhấc dao lên cao độ an toàn
          lines << "G00 Z#{safe_z}"
        end
      end

      lines << ""
      lines << "( ---------------------------------------------------------- )"
      lines << "( HOAN TAT QUA TRINH GIA CONG )"
      lines << "M05 (TAT TRUC CHINH)"
      lines << "G00 Z30.000 (NHAC DAO VE DO CAO AN TOAN KET THUC)"
      lines << "G00 X0.000 Y#{SHEET_H} (TRA CONG VE DIEM DO LAY PHOI)"
      lines << "M30 (KET THUC CHUONG TRINH)"

      lines.join("\n")
    end
  end
end
