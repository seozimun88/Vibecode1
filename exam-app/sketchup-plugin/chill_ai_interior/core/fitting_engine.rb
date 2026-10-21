# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Fitting Engine (Chuyên Gia Phụ Kiện: Cam Chốt & Bản Lề)
# Chưng cất tinh hoa từ ABF Solutions & Chuẩn hóa Châu Âu System 32
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module FittingEngine
    LAYER_CAM_15       = 'DRILL_CAM_15'.freeze
    LAYER_DOWEL_8      = 'DRILL_DOWEL_8'.freeze
    LAYER_PIN_5        = 'DRILL_PIN_5'.freeze
    LAYER_HINGE_35     = 'DRILL_HINGE_35'.freeze
    LAYER_HINGE_BASE_5 = 'DRILL_HINGE_BASE_5'.freeze

    # 1. TỰ ĐỘNG TẠO / LẤY CÁC LAYER KHOAN LỖ CHO MÁY CNC / ASPIRE
    def self.ensure_layers(model)
      layers = {}
      [LAYER_CAM_15, LAYER_DOWEL_8, LAYER_PIN_5, LAYER_HINGE_35, LAYER_HINGE_BASE_5].each do |name|
        layers[name] = model.layers[name] || model.layers.add(name)
      end
      layers
    end

    # 2. BÓC TÁCH TOÀN BỘ CÁC TẤM VÁN TRONG VÙNG CHỌN
    def self.collect_panels(selection)
      panels = []
      selection.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # Nếu đây là tổ hợp tủ cha (Root Cabinet), duyệt các tấm con bên trong
          sub_entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          has_subs = false
          sub_entities.each do |sub|
            if sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
              # Bỏ qua các group lỗ khoan cũ nếu có
              next if sub.name =~ /Chill_AI_Fittings/i
              panels << { entity: sub, parent: entity, transform: entity.transformation * sub.transformation }
              has_subs = true
            end
          end
          # Nếu là tấm ván đơn lẻ
          panels << { entity: entity, parent: nil, transform: entity.transformation } unless has_subs
        end
      end
      panels
    end

    # Phân loại hướng của tấm ván (Đứng - Vertical hay Ngang - Horizontal)
    def self.analyze_panel_orientation(panel_info)
      ent = panel_info[:entity]
      bb = ent.bounds
      # Kích thước theo toạ độ địa phương (mm)
      dx = bb.width.to_m * 1000.0
      dy = bb.height.to_m * 1000.0
      dz = bb.depth.to_m * 1000.0

      # Tìm trục có độ dày mỏng nhất (15mm - 25mm)
      dims = [{ axis: :x, val: dx }, { axis: :y, val: dy }, { axis: :z, val: dz }].sort_by { |d| d[:val] }
      thickness = dims[0][:val]
      length    = dims[2][:val]
      width     = dims[1][:val]
      thin_axis = dims[0][:axis]

      # Phân loại:
      # thin_axis == :x -> Tấm Hồi Đứng (Vách trái, vách phải, vách giữa)
      # thin_axis == :z -> Tấm Ngang (Đáy, Nóc, Đợt tầng)
      # thin_axis == :y -> Tấm Hậu hoặc Cánh Cửa
      type = case thin_axis
             when :x then :vertical
             when :z then :horizontal
             when :y then :front_back
             else :unknown
             end

      {
        type: type,
        thickness: thickness,
        length: length,
        width: width,
        thin_axis: thin_axis,
        bounds_world: get_world_bounds(ent, panel_info[:transform])
      }
    end

    def self.get_world_bounds(entity, transform)
      bb = entity.bounds
      pts = [
        Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
        Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
      ].map { |p| p.transform(transform) }
      Geom::BoundingBox.new.add(pts)
    end

    # ==========================================================================
    # 🎯 3. THUẬT TOÁN ĐỤC LỖ CAM CHỐT MINIFIX (CHƯNG CẤT TỪ ABF)
    # ==========================================================================
    def self.apply_cam_locks(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Tủ Áo hoặc các Tấm Ván trong SketchUp để khoan cam chốt!' }
      end

      model.start_operation("Chill AI: Khoan Cam Chốt Tự Động", true)

      layers = ensure_layers(model)
      panels_raw = collect_panels(selection)

      if panels_raw.empty?
        model.abort_operation
        return { status: 'warning', message: 'Không tìm thấy chi tiết tấm ván phù hợp trong vùng chọn.' }
      end

      # Phân tích thông số từng tấm
      analyzed = panels_raw.map do |p|
        info = analyze_panel_orientation(p)
        p.merge(info)
      end

      verticals   = analyzed.select { |p| p[:type] == :vertical }
      horizontals = analyzed.select { |p| p[:type] == :horizontal }

      total_cams = 0
      total_dowels = 0

      # Nhóm chứa toàn bộ các lỗ khoan để dễ quản lý & bật tắt
      fittings_group = model.active_entities.add_group
      fittings_group.name = "Chill_AI_Fittings_CamLock_#{Time.now.strftime('%H%M%S')}"

      # Duyệt tìm các điểm giao nhau vuông góc giữa Tấm Ngang (Đáy/Đợt) và Tấm Đứng (Hồi)
      horizontals.each do |horiz|
        h_bb = horiz[:bounds_world]
        h_center_z = (h_bb.min.z + h_bb.max.z) / 2.0
        h_depth_y  = (h_bb.max.y - h_bb.min.y)

        verticals.each do |vert|
          v_bb = vert[:bounds_world]

          # Kiểm tra xem Tấm Ngang có chạm vào Tấm Đứng theo trục X không (khoảng cách < 2mm)
          touch_left  = (h_bb.min.x - v_bb.max.x).abs < 0.1.m # Chạm hồi trái
          touch_right = (h_bb.max.x - v_bb.min.x).abs < 0.1.m # Chạm hồi phải

          if touch_left || touch_right
            # Kiểm tra xem có giao nhau theo trục Y và Z không
            overlap_y = [h_bb.max.y, v_bb.max.y].min - [h_bb.min.y, v_bb.min.y].max
            if overlap_y > 200.mm && h_center_z >= (v_bb.min.z - 10.mm) && h_center_z <= (v_bb.max.z + 10.mm)
              # ĐÂY LÀ KHỚP NỐI VUÔNG GÓC! TÍNH TOÁN RẢI LỖ CAM
              contact_y_min = [h_bb.min.y, v_bb.min.y].max
              contact_y_max = [h_bb.max.y, v_bb.max.y].min
              contact_len = contact_y_max - contact_y_min

              # Tọa độ X liên kết:
              joint_x = touch_left ? h_bb.min.x : h_bb.max.x
              cam_direction = touch_left ? 1 : -1 # Bầu cam nằm về phía trong tấm ngang

              # Tính danh sách tọa độ Y rải cam (Cách đầu/cuối 50mm, nếu dài rải thêm ở giữa)
              y_positions = []
              margin = 50.mm
              if contact_len > 150.mm
                y_positions << (contact_y_min + margin)
                y_positions << (contact_y_max - margin)
                # Nếu chiều sâu > 400mm, thêm 1 cam ở giữa
                if contact_len > 400.mm
                  y_positions << (contact_y_min + contact_len / 2.0)
                end
              end

              # Sinh lỗ cam và chốt định vị
              y_positions.each do |y_pos|
                # 1. VỊ TRÍ TÂM BẦU CAM PHI 15MM (Cách mép 34mm chuẩn Hafele)
                cam_center_x = joint_x + (cam_direction * 34.mm)
                # Bầu cam khoét ở mặt dưới tấm ngang (h_bb.min.z)
                cam_center = Geom::Point3d.new(cam_center_x, y_pos, h_bb.min.z)

                create_cylinder_hole(
                  fittings_group.entities,
                  cam_center,
                  Geom::Vector3d.new(0, 0, 1),
                  7.5.mm,    # Bán kính 7.5mm -> Phi 15mm
                  13.5.mm,   # Độ sâu 13.5mm
                  layers[LAYER_CAM_15],
                  "Cam_15_Depth13.5"
                )
                total_cams += 1

                # 2. VỊ TRÍ CHỐT GỖ PHI 8MM (Cách tâm cam 32mm theo chuẩn System 32)
                dowel_y = (y_pos + 32.mm <= contact_y_max - 15.mm) ? (y_pos + 32.mm) : (y_pos - 32.mm)
                dowel_center_x = joint_x + (cam_direction * 9.5.mm) # Nằm ở mép ván
                dowel_center = Geom::Point3d.new(dowel_center_x, dowel_y, h_center_z)

                create_cylinder_hole(
                  fittings_group.entities,
                  dowel_center,
                  Geom::Vector3d.new(cam_direction, 0, 0),
                  4.0.mm,    # Bán kính 4mm -> Phi 8mm
                  25.0.mm,   # Độ sâu chốt gỗ 25mm
                  layers[LAYER_DOWEL_8],
                  "Dowel_8_Depth25"
                )
                total_dowels += 1

                # 3. VỊ TRÍ LỖ CẮM TY CAM PHI 5MM TRÊN VÁCH HỒI
                pin_center_x = joint_x
                pin_center = Geom::Point3d.new(pin_center_x, y_pos, h_center_z)
                create_cylinder_hole(
                  fittings_group.entities,
                  pin_center,
                  Geom::Vector3d.new(-cam_direction, 0, 0),
                  2.5.mm,    # Bán kính 2.5mm -> Phi 5mm
                  12.0.mm,   # Sâu 12mm
                  layers[LAYER_PIN_5],
                  "Pin_5_Depth12"
                )
              end
            end
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_cams} cụm Cam Minifix 15mm và #{total_dowels} Chốt gỗ 8mm chuẩn System 32!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      # Phản hồi âm thanh & Toast về UI
      if dialog
        dialog.execute_script("if(window.onFittingsApplied) window.onFittingsApplied(#{ { cams: total_cams, dowels: total_dowels, message: msg }.to_json });")
      end

      { status: 'success', cams: total_cams, dowels: total_dowels, message: msg }
    rescue => e
      model.abort_operation rescue nil
      err_msg = "Lỗi khi tạo lỗ cam chốt: #{e.message}"
      puts "[Chill AI FittingEngine Error] #{err_msg}\n#{e.backtrace.first(3).join("\n")}"
      UI.messagebox(err_msg)
      { status: 'error', message: err_msg }
    end

    # ==========================================================================
    # 🚪 4. THUẬT TOÁN ĐỤC LỖ BẢN LỀ GIẢM CHẤN CHÉN 35MM
    # ==========================================================================
    def self.apply_hinges(params = {}, dialog = nil)
      model = Sketchup.active_model
      return { status: 'error', message: 'Chưa mở bản vẽ SketchUp!' } unless model

      selection = model.selection
      if selection.empty?
        return { status: 'warning', message: 'Vui lòng chọn Cánh Tủ để đục lỗ chén bản lề 35mm!' }
      end

      model.start_operation("Chill AI: Khoan Bản Lề 35mm", true)
      layers = ensure_layers(model)

      total_hinges = 0
      fittings_group = model.active_entities.add_group
      fittings_group.name = "Chill_AI_Fittings_Hinges_#{Time.now.strftime('%H%M%S')}"

      selection.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        bb = entity.bounds
        h = (bb.max.z - bb.min.z).to_m * 1000.0 # Chiều cao cánh (mm)
        w = (bb.max.x - bb.min.x).to_m * 1000.0 # Chiều rộng cánh (mm)

        # Kiểm tra đây có phải là cánh tủ không (Chiều cao lớn hơn 400mm)
        if h > 400.0
          # Xác định số lượng bản lề theo chiều cao cánh
          count = if h <= 900.0
                    2
                  elsif h <= 1600.0
                    3
                  elsif h <= 2000.0
                    4
                  else
                    5
                  end

          # Tính toán vị trí rải bản lề theo chiều cao Z
          z_positions = []
          margin_top = 100.mm
          margin_bottom = 100.mm

          z_positions << (bb.min.z + margin_bottom) # Bản lề đáy
          z_positions << (bb.max.z - margin_top)    # Bản lề đỉnh

          if count >= 3
            z_positions << (bb.min.z + (bb.max.z - bb.min.z) / 2.0) # Bản lề giữa
          end
          if count >= 4
            gap = (bb.max.z - bb.min.z - margin_top - margin_bottom) / (count - 1)
            z_positions = (0...count).map { |i| bb.min.z + margin_bottom + (i * gap) }
          end

          # Mặt sau cánh tủ (nơi khoét chén bản lề)
          back_face_y = bb.min.y
          # Cạnh bắt bản lề (Mép trái của cánh)
          hinge_edge_x = bb.min.x + 22.5.mm # Tâm chén cách mép đúng 22.5mm (Biên K=5mm)

          z_positions.each do |z_pos|
            cup_center = Geom::Point3d.new(hinge_edge_x, back_face_y, z_pos)

            # 1. CHÉN BẢN LỀ PHI 35MM (Sâu 11.5mm)
            create_cylinder_hole(
              fittings_group.entities,
              cup_center,
              Geom::Vector3d.new(0, 1, 0),
              17.5.mm,  # Bán kính 17.5mm -> Phi 35mm
              11.5.mm,  # Sâu 11.5mm
              layers[LAYER_HINGE_35],
              "Hinge_Cup_35_Depth11.5"
            )

            # 2. HAI LỖ BẮT VÍT TAI BẢN LỀ (Khoảng cách tâm 45mm, cách tâm chén 9.5mm)
            [-22.5.mm, 22.5.mm].each do |z_offset|
              screw_center = Geom::Point3d.new(hinge_edge_x + 9.5.mm, back_face_y, z_pos + z_offset)
              create_cylinder_hole(
                fittings_group.entities,
                screw_center,
                Geom::Vector3d.new(0, 1, 0),
                1.5.mm,   # Mồi vít phi 3mm
                10.0.mm,
                layers[LAYER_HINGE_35],
                "Hinge_Screw_3mm"
              )
            end

            total_hinges += 1
          end
        end
      end

      model.commit_operation

      msg = "Chill AI: Đã tự động tạo #{total_hinges} chén bản lề 35mm chuẩn Hafele/Blum!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onHingesApplied) window.onHingesApplied(#{ { hinges: total_hinges, message: msg }.to_json });")
      end

      { status: 'success', hinges: total_hinges, message: msg }
    rescue => e
      model.abort_operation rescue nil
      err_msg = "Lỗi khi tạo bản lề: #{e.message}"
      puts "[Chill AI FittingEngine Error] #{err_msg}"
      UI.messagebox(err_msg)
      { status: 'error', message: err_msg }
    end

    # ==========================================================================
    # 🧹 5. XÓA CÁC LỖ KHOAN PHỤ KIỆN (KHI CẦN QUAY LẠI 3D SẠCH SẼ)
    # ==========================================================================
    def self.clear_fittings(dialog = nil)
      model = Sketchup.active_model
      return unless model

      model.start_operation("Chill AI: Xóa Phụ Kiện Lỗ Khoan", true)
      deleted = 0
      model.active_entities.grep(Sketchup::Group).each do |g|
        if g.name =~ /^Chill_AI_Fittings_/i
          g.erase! rescue nil
          deleted += 1
        end
      end
      model.commit_operation

      msg = "Đã dọn sạch #{deleted} cụm lỗ khoan phụ kiện để tối ưu tốc độ 3D!"
      Sketchup.status_text = msg
      puts "[Chill AI FittingEngine] #{msg}"

      if dialog
        dialog.execute_script("if(window.onFittingsCleared) window.onFittingsCleared(#{ { deleted: deleted }.to_json });")
      end
      { status: 'success', deleted: deleted }
    end

    # ==========================================================================
    # HÀM TRỢ GIÚP: VẼ KHỐI TRỤ RỖNG 3D MÔ PHỎNG LỖ KHOAN THỰC TẾ
    # ==========================================================================
    def self.create_cylinder_hole(entities, center, normal, radius, depth, layer, label)
      group = entities.add_group
      group.name = label
      group.layer = layer if layer

      # Tạo vòng tròn đáy
      edges = group.entities.add_circle(center, normal, radius, 24)
      face = group.entities.add_face(edges)

      # Đẩy khối âm xuống theo chiều sâu mũi khoan
      if face
        # Đảo mặt nếu normal ngược chiều
        face.reverse! if face.normal.dot(normal) > 0
        face.pushpull(-depth) rescue nil
      end

      # Gán thuộc tính nhận diện cho CNC Nesting & DXF Exporter
      group.set_attribute('chill_ai_drill', 'diameter', radius * 2.0.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'depth', depth.to_m * 1000.0)
      group.set_attribute('chill_ai_drill', 'type', label)
      group
    rescue => _e
      nil
    end
  end
end
