# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Exploded View Engine (Sơ Đồ Rã Khối / Bản Vẽ Lắp Ráp 3D)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# Chuẩn: ABF Extension (Real-time Exploded View kèm Leader Text chỉ dẫn)
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  module ExplodedViewEngine
    LAYER_NAME = "Chill_AI_Exploded_Labels".freeze

    @original_data = {}      # Lưu transformation và bounds gốc: { entity_id => { entity, transform, center } }
    @parts_info = []         # Danh sách chi tiết tấm ván bóc tách
    @labels_group = nil      # Group duy nhất chứa toàn bộ Leader Text chú thích
    @model_center = nil      # Tâm hình học tổng thể của cụm mô hình
    @model_dims = [1000.0, 1000.0, 1000.0] # Kích thước bao (width, height, depth)
    @current_params = { 'x' => 120.0, 'y' => 80.0, 'z' => 150.0, 't' => 100.0, 'r' => 0.0 }
    @is_active = false

    def self.active?
      @is_active
    end

    def self.current_params
      @current_params
    end

    # --- KIỂM TRA ĐỐI TƯỢNG CÓ PHẢI LÀ TẤM VÁN MỘC HAY KHÔNG ---
    def self.is_cabinet_panel?(entity)
      return false unless entity && entity.valid?
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      name = entity.name.to_s.strip
      defn_name = (entity.respond_to?(:definition) && entity.definition) ? entity.definition.name.to_s.strip : ""

      # Bỏ qua các đối tượng phụ trợ / rác / nhãn / khổ ván nesting sàn
      return false if name =~ /^(CHILL_AI_NESTING|ABF_NESTING|Khổ Ván|Chill_AI_Exploded)/i ||
                      defn_name =~ /^(CHILL_AI_NESTING|ABF_NESTING|Khổ Ván|Chill_AI_Exploded)/i
      return false if name =~ /^(Chill_AI_Label|_ABF_|ABF_Label|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i ||
                      defn_name =~ /^(Chill_AI_Label|_ABF_|ABF_Label|Chill_AI_Fitting|Chill_AI_Joint|Chill_AI_Hinge)/i

      # 1. Nhận diện qua thuộc tính CNC (Chill AI hoặc ABF gốc)
      return true if entity.get_attribute("Chill_AI_CNC", "label_id") ||
                     entity.get_attribute("Chill_AI_CNC", "id_number") ||
                     entity.get_attribute("Chill_AI_CNC", "part_name") ||
                     entity.get_attribute("abf_part", "id") ||
                     entity.get_attribute("ABF_ATTRIBUTES", "part_name")

      # 2. Nhận diện qua tên có định dạng mã tấm ván [P01], [P1], v.v...
      return true if name =~ /\[P\d+\]/i || defn_name =~ /\[P\d+\]/i

      # 3. Nhận diện qua kích thước Local Definition Bounds hoặc World Bounds
      defn = entity.respond_to?(:definition) ? entity.definition : (entity.entities.parent rescue nil)
      bb = (defn && defn.respond_to?(:bounds)) ? defn.bounds : entity.bounds
      dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
      t = dims[0]; w = dims[1]; l = dims[2]

      # Tiêu chuẩn tấm ván mộc nội thất: Độ dày 4mm - 65mm, Chiều rộng >= 30mm, Chiều dài >= 30mm
      if t >= 4.0 && t <= 65.0 && w >= 30.0 && l >= 30.0
        # Kiểm tra có Face nào không (trực tiếp hoặc đệ quy 1 cấp con)
        ents = entity.is_a?(Sketchup::Group) ? entity.entities : (defn ? defn.entities : [])
        has_face = ents.grep(Sketchup::Face).any? || ents.grep(Sketchup::Group).any? { |g| g.entities.grep(Sketchup::Face).any? }
        return true if has_face
      end

      false
    end

    # --- THU THẬP TẤT CẢ CÁC TẤM VÁN (KỂ CẢ CỤM CON LỒNG NHAU) ---
    def self.collect_all_panels(entities, collected = [])
      entities.each do |ent|
        next unless ent && ent.valid?
        next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)

        if is_cabinet_panel?(ent)
          collected << ent unless collected.include?(ent)
        else
          # Là cụm tủ / Assembly cha: duyệt đệ quy tìm các tấm ván con bên trong
          sub_ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
          collect_all_panels(sub_ents, collected)
        end
      end
      collected
    end

    # ==============================================================================
    # 1. KHỞI TẠO PHIÊN EXPLODED VIEW (BÓC TÁCH TẤM VÁN & TỰ ĐỘNG CHỌN VIỀN XANH 100%)
    # ==============================================================================
    def self.init_exploded_view
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model SketchUp!" } unless model

      # Xóa sạch phiên cũ nếu có
      cleanup_texts(model)
      @original_data = {}
      @parts_info = []

      # Thu thập tấm ván thông minh:
      # - Nếu người dùng đang chọn đối tượng: thu thập từ vùng chọn
      # - Nếu chỉ chọn 1-2 tấm hoặc chọn cụm tủ: tự động gom đủ toàn bộ các tấm trong cụm
      target_ents = []
      if model.selection && model.selection.count > 0
        selected = model.selection.to_a
        panels = collect_all_panels(selected)

        # Nếu vùng chọn chỉ tìm được ít hơn 3 tấm mà trong model có cụm tủ hoàn chỉnh:
        # Tự động quét thêm các tấm ván anh em trong cùng context để bung cả cụm
        if panels.length < 3
          context_panels = collect_all_panels(model.active_entities.to_a)
          if context_panels.length > panels.length && context_panels.length <= 40
            panels = context_panels
          end
        end
        target_ents = panels
      else
        target_ents = collect_all_panels(model.active_entities.to_a)
      end

      # Fallback an toàn nếu chưa tìm thấy: Quét trực tiếp các Group/Component trong model
      if target_ents.empty?
        model.active_entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.name.to_s =~ /^(CHILL_AI_NESTING|ABF_NESTING|Khổ Ván|Chill_AI_Label)/i
          target_ents << e
        end
      end

      if target_ents.empty?
        return { "status" => "warning", "message" => "Không tìm thấy cấu kiện tấm ván nào để bung sơ đồ lắp ráp!" }
      end

      # Tính BoundingBox tổng thể của toàn bộ cụm
      total_bounds = Geom::BoundingBox.new
      target_ents.each do |ent|
        next unless ent && ent.valid?
        total_bounds.add(ent.bounds)
      end

      @model_center = total_bounds.center
      bw = [total_bounds.width, 50.mm].max
      bh = [total_bounds.height, 50.mm].max
      bd = [total_bounds.depth, 50.mm].max
      @model_dims = [bw, bh, bd]

      # Lưu toạ độ và chuẩn hoá thông tin nhãn từng tấm
      target_ents.each_with_index do |ent, idx|
        next unless ent && ent.valid?

        ent_id = ent.persistent_id rescue ent.entity_id
        orig_center = ent.bounds.center
        @original_data[ent_id] = {
          entity: ent,
          transform: ent.transformation.clone,
          orig_center: orig_center
        }

        # Đọc thông số định danh chuẩn ABF
        id_num = ent.get_attribute("Chill_AI_CNC", "id_number") || (idx + 1)
        part_code = ent.get_attribute("Chill_AI_CNC", "label_id") || sprintf("P%02d", id_num)

        raw_name = ent.get_attribute("Chill_AI_CNC", "part_name") || ent.name.to_s
        clean_name = defined?(LabelingEngine) ? LabelingEngine.clean_raw_name(raw_name) : raw_name.to_s
        clean_name = "Tấm ván #{id_num}" if clean_name.empty? || clean_name =~ /^Group/i

        bb = ent.bounds
        dim_l = (ent.get_attribute("Chill_AI_CNC", "dim_l") || bb.width.to_mm).round(0).to_i
        dim_w = (ent.get_attribute("Chill_AI_CNC", "dim_w") || bb.height.to_mm).round(0).to_i
        dim_t = (ent.get_attribute("Chill_AI_CNC", "dim_t") || bb.depth.to_mm).round(0).to_i

        # Cú pháp định dạng nhãn leader chuẩn 100% ảnh ABF anh Huy gửi:
        # Ví dụ: "1. [P01] __ 1. TB1_Tủ Áo_1 (802x496x17)"
        full_title = "#{id_num}. [#{part_code}] __ #{id_num}. #{clean_name} (#{dim_l}x#{dim_w}x#{dim_t})"

        @parts_info << {
          id: id_num,
          code: part_code,
          name: clean_name,
          full_title: full_title,
          entity: ent,
          ent_id: ent_id,
          orig_center: orig_center,
          orig_transform: ent.transformation.clone
        }
      end

      # Đảm bảo Layer/Tag cho nhãn tồn tại
      model.layers.add(LAYER_NAME) unless model.layers[LAYER_NAME]

      # ------------------------------------------------------------------------
      # CỰC KỲ QUAN TRỌNG: CẬP NHẬT LẠI MODEL SELECTION ĐỂ TẤT CẢ CÁC TẤM VÁN
      # (BAO GỒM CẢ TẤM ĐỢT NẰM NGANG Ở GIỮA) ĐỀU SÁNG VIỀN XANH 100%!
      # ------------------------------------------------------------------------
      begin
        model.selection.clear
        valid_ents = @parts_info.map { |p| p[:entity] }.compact.select(&:valid?)
        model.selection.add(valid_ents) unless valid_ents.empty?
      rescue => _e
      end

      @is_active = true

      # Mặc định khởi tạo vị trí ban đầu theo ảnh mẫu (X ~ 120, Y ~ 80, Z ~ 150, t ~ 100, r ~ 0)
      initial = {
        'x' => 120.0,
        'y' => 80.0,
        'z' => 150.0,
        't' => 100.0,
        'r' => 0.0
      }
      @current_params = initial
      update_explosion(initial)

      {
        "status" => "success",
        "total_parts" => @parts_info.length,
        "initial_params" => initial,
        "message" => "Đã kích hoạt Chế độ Rã Mô Hình (Exploded View) cho #{@parts_info.length} tấm ván!"
      }
    rescue => err
      puts "[Chill AI ExplodedViewEngine Error]: #{err.message}\n#{err.backtrace ? err.backtrace.first(4).join("\n") : ''}"
      { "status" => "error", "message" => err.message }
    end

    # ==============================================================================
    # 2. CẬP NHẬT ĐỘ BUNG THEO 5 THANH TRƯỢT (REAL-TIME X, Y, Z, t, r)
    # ==============================================================================
    def self.update_explosion(params = {})
      return unless @is_active && !@parts_info.empty?
      model = Sketchup.active_model
      return unless model

      # Hợp nhất thông số an toàn (chấp nhận cả key String lẫn Symbol)
      params.each do |k, v|
        @current_params[k.to_s] = v.to_f
      end

      val_x = (@current_params['x'] || 0.0).to_f.mm
      val_y = (@current_params['y'] || 0.0).to_f.mm
      val_z = (@current_params['z'] || 0.0).to_f.mm
      val_t = (@current_params['t'] || 100.0).to_f.mm
      val_r = (@current_params['r'] || 0.0).to_f

      tag_label = model.layers[LAYER_NAME]

      half_w = [@model_dims[0] / 2.0, 50.mm].max
      half_h = [@model_dims[1] / 2.0, 50.mm].max
      half_d = [@model_dims[2] / 2.0, 50.mm].max

      model.start_operation("Chill AI Explode", true, false, true)
      begin
        # 1. DỌN SẠCH CÁC LEADER TEXT CŨ TRONG CÙNG OPERATION (CHỐNG LỖI TRANSACTION)
        if @labels_group && @labels_group.valid?
          @labels_group.erase! rescue nil
        end
        @labels_group = nil

        # Tạo Group riêng chứa toàn bộ Leader Text nếu val_t > 5mm
        if val_t > 5.mm
          @labels_group = model.active_entities.add_group
          @labels_group.name = "Chill_AI_Exploded_Labels_Group"
          @labels_group.layer = tag_label if tag_label
        end

        # 2. DI CHUYỂN TỪNG TẤM VÁN THEO THUẬT TOÁN PHÂN RÃ KHÔNG GIAN CHUẨN ABF
        @parts_info.each_with_index do |p, idx|
          ent = p[:entity]
          next unless ent && ent.valid?

          orig_c = p[:orig_center]
          orig_tr = p[:orig_transform]

          # Tính vector tương đối từ tâm cụm đến tâm tấm ván
          dx = orig_c.x - @model_center.x
          dy = orig_c.y - @model_center.y
          dz = orig_c.z - @model_center.z

          # --- TRỤC X: Phân tách sang trái (-X) và sang phải (+X) ---
          if dx < -15.mm
            fx = (dx / half_w).clamp(-2.5, -0.6)
          elsif dx > 15.mm
            fx = (dx / half_w).clamp(0.6, 2.5)
          else
            # Tấm nằm ngay chính giữa (như tấm đợt ngang hoặc vách giữa)
            # Nếu chỉ có 1 tấm ở giữa: giữ nguyên tâm X (fx = 0)
            # Nếu có nhiều tấm ở giữa: so le nhẹ
            fx = (@parts_info.length > 2) ? ((idx % 2 == 0) ? 0.2 : -0.2) : 0.0
          end

          # --- TRỤC Y: Phân tách theo chiều sâu (Hậu tủ dời sau, Cánh dời trước) ---
          if dy < -15.mm
            fy = (dy / half_h).clamp(-2.5, -0.6)
          elsif dy > 15.mm
            fy = (dy / half_h).clamp(0.6, 2.5)
          else
            # ĐẶC BIỆT: Nếu tất cả các tấm có cùng chiều sâu Y (như 2 vách và 1 đợt ngang):
            # Cho tấm giữa trượt nhẹ ra phía trước để lộ rõ các lỗ cam chốt liên kết!
            if fx.abs < 0.3
              fy = 0.65 # Tấm giữa trượt ra phía trước
            else
              fy = -0.15 # Hai tấm vách dịch nhẹ ra sau
            end
          end

          # --- TRỤC Z: Phân tách theo chiều cao (Nóc dời lên, Đáy dời xuống, Đợt dời theo tầng) ---
          if dz > 20.mm
            fz = (dz / half_d).clamp(0.6, 2.5)
          elsif dz < -20.mm
            fz = (dz / half_d).clamp(-2.5, -0.6)
          else
            # Tấm đợt nằm ngang ở giữa: cho phép hạ xuống nhẹ khi kéo Z để lộ lỗ liên kết
            fz = (fx.abs < 0.3) ? -0.45 : 0.0
          end

          # Vector dịch chuyển cho tấm ván này
          disp_x = val_x * fx
          disp_y = val_y * fy
          disp_z = val_z * fz
          disp_vec = Geom::Vector3d.new(disp_x, disp_y, disp_z)

          # Áp dụng Transformation dời tấm ván mượt mà
          ent.make_unique rescue nil if ent.is_a?(Sketchup::Group)
          trans_disp = Geom::Transformation.translation(disp_vec)
          ent.transformation = trans_disp * orig_tr

          # ------------------------------------------------------------------
          # 3. VẼ ĐƯỜNG DẪN CHÚ THÍCH (LEADER TEXT) CHUẨN ABF
          # ------------------------------------------------------------------
          if @labels_group && @labels_group.valid? && val_t > 5.mm
            attach_pt = orig_c + disp_vec

            # Góc xoay val_r của thanh trượt
            r_rad = val_r * Math::PI / 180.0
            cos_r = Math.cos(r_rad)
            sin_r = Math.sin(r_rad)

            base_dir_x = (fx >= 0) ? 1.0 : -1.0
            base_dir_y = (fy >= 0) ? 0.3 : -0.3

            lead_x = (base_dir_x * cos_r - base_dir_y * sin_r) * val_t
            lead_y = (base_dir_x * sin_r + base_dir_y * cos_r) * val_t
            lead_z = 25.mm
            leader_vec = Geom::Vector3d.new(lead_x, lead_y, lead_z)

            # Thêm Text vào group nhãn
            txt = @labels_group.entities.add_text(p[:full_title], attach_pt, leader_vec)
            if txt
              # Gán mũi tên kiểu 3 (Closed Arrowhead) an toàn
              txt.arrow_type = 3 rescue nil
              txt.leader_type = 1 rescue nil
            end
          end
        end

        model.commit_operation
        model.active_view.invalidate
      rescue => err
        model.abort_operation
        puts "[Chill AI Exploded Update Error]: #{err.message}"
      end
    end

    # ==============================================================================
    # 3. KHÔI PHỤC VỊ TRÍ GỐC (RESET TO ASSEMBLED STATE)
    # ==============================================================================
    def self.reset_to_original
      return unless @is_active && !@parts_info.empty?
      model = Sketchup.active_model
      return unless model

      cleanup_texts(model)

      model.start_operation("Chill AI - Khôi Phục Vị Trí Gốc", true)
      begin
        @parts_info.each do |p|
          ent = p[:entity]
          next unless ent && ent.valid?
          ent.transformation = p[:orig_transform]
        end
        model.commit_operation
        model.active_view.invalidate
        @current_params = { 'x' => 0.0, 'y' => 0.0, 'z' => 0.0, 't' => 0.0, 'r' => 0.0 }
        Sketchup.status_text = "Chill AI: Đã khôi phục toàn bộ mô hình về vị trí ban đầu!"
        { "status" => "success", "message" => "Đã khôi phục toàn bộ mô hình về vị trí lắp ráp ban đầu!" }
      rescue => err
        model.abort_operation
        { "status" => "error", "message" => err.message }
      end
    end

    # ==============================================================================
    # 4. CHẤP NHẬN SƠ ĐỒ LẮP RÁP & TỰ ĐỘNG TẠO SCENE 3D (OK / COMMIT)
    # ==============================================================================
    def self.commit_and_create_scene
      model = Sketchup.active_model
      return { "status" => "error", "message" => "Không tìm thấy model!" } unless model

      scene_name = "Bản Vẽ Lắp Ráp"
      pages = model.pages
      existing_page = pages[scene_name]
      if existing_page
        pages.selected_page = existing_page
        existing_page.update
      else
        new_page = pages.add(scene_name)
        new_page.use_camera = true
        new_page.use_hidden_layers = true
        new_page.update
      end

      Sketchup.status_text = "Chill AI: Đã lưu Sơ Đồ Lắp Ráp vào Scene '#{scene_name}'!"
      { "status" => "success", "message" => "Đã tạo thành công Scene '#{scene_name}' để in bản vẽ lắp ráp!" }
    rescue => err
      { "status" => "error", "message" => err.message }
    end

    # ==============================================================================
    # 5. DỌN SẠCH CÁC TEXT VÀ GROUP NHÃN
    # ==============================================================================
    def self.cleanup_texts(model = nil)
      model ||= Sketchup.active_model
      return unless model

      if @labels_group && @labels_group.valid?
        @labels_group.erase! rescue nil
      end
      @labels_group = nil

      # Dọn dẹp phụ các group nhãn cũ trên Layer nếu có
      tag_label = model.layers[LAYER_NAME]
      if tag_label
        model.active_entities.grep(Sketchup::Group).each do |g|
          if g.name =~ /^Chill_AI_Exploded_Labels/i || g.layer == tag_label
            g.erase! rescue nil
          end
        end
      end
    rescue => _e
    end

    # ==============================================================================
    # 6. ĐÓNG PHIÊN VÀ DỌN DẸP
    # ==============================================================================
    def self.close_session
      cleanup_texts
      @original_data.clear
      @parts_info.clear
      @is_active = false
    end
  end
end
