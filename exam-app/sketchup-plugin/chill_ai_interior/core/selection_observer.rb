# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Selection Observer (Đấu Nối 2 Chiều Chuẩn Xác Giữa SU & Plugin)
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  # Hot-Reload được quản lý tập trung bởi ModuleLoader

  module SelectionManager
    @observer = nil
    @dialog = nil
    @app_observer = nil
    @model_observer = nil
    @entities_observer = nil
    @throttle_timer = nil
    @last_bounds = nil
    @last_oversized_status = nil
    @has_clamped_dock = false

    def self.remove_accents(str)
      return "" if str.nil?
      str.to_s.downcase.tr(
        'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ',
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      )
    end

    class InternalSelectionObserver < Sketchup::SelectionObserver
      def initialize(dialog)
        @dialog = dialog
      end

      def onSelectionBulkChange(selection)
        SelectionManager.handle_selection(selection, @dialog)
      end

      def onSelectionCleared(selection)
        SelectionManager.handle_cleared(@dialog)
      end

      def onSelectionAdded(selection, entity)
        SelectionManager.handle_selection(selection, @dialog)
      end

      def onSelectionRemoved(selection, entity)
        SelectionManager.handle_selection(selection, @dialog)
      end
    end

    class InternalModelObserver < Sketchup::ModelObserver
      def onTransactionCommit(model)
        SelectionManager.handle_model_modified(model)
      end

      def onTransactionUndo(model)
        SelectionManager.handle_model_modified(model)
      end

      def onTransactionRedo(model)
        SelectionManager.handle_model_modified(model)
      end
    end

    class InternalEntitiesObserver < Sketchup::EntitiesObserver
      def onElementModified(entities, entity)
        SelectionManager.handle_element_modified(entity)
      end
    end

    class InternalAppObserver < Sketchup::AppObserver
      def onNewModel(model)
        SelectionManager.reconnect(model)
      end

      def onOpenModel(model)
        SelectionManager.reconnect(model)
      end

      def onActivateModel(model)
        SelectionManager.reconnect(model)
      end
    end

    def self.handle_model_modified(model)
      return unless @dialog && model
      if model.selection && model.selection.count > 0
        handle_selection(model.selection, @dialog, force: true)
      end
    end

    def self.handle_element_modified(entity)
      return unless @dialog && entity && entity.valid?
      return if @throttle_timer
      @throttle_timer = UI.start_timer(0.18, false) do
        @throttle_timer = nil
        model = Sketchup.active_model
        if model && model.selection && model.selection.count > 0
          handle_selection(model.selection, @dialog, force: true)
        end
      end
    end

    def self.attach(dialog)
      return unless dialog
      @dialog = dialog

      model = Sketchup.active_model
      return unless model

      detach

      @observer = InternalSelectionObserver.new(@dialog)
      model.selection.add_observer(@observer)

      unless @model_observer
        @model_observer = InternalModelObserver.new
        model.add_observer(@model_observer) rescue nil
      end

      unless @entities_observer
        @entities_observer = InternalEntitiesObserver.new
        model.active_entities.add_observer(@entities_observer) rescue nil
      end

      unless @app_observer
        @app_observer = InternalAppObserver.new
        Sketchup.add_observer(@app_observer)
      end

      if model.selection.count > 0
        handle_selection(model.selection, @dialog)
      end
    end

    def self.reconnect(model)
      return unless @dialog
      detach
      attach(@dialog)
    end

    def self.detach
      if @observer && Sketchup.active_model
        begin
          Sketchup.active_model.selection.remove_observer(@observer)
        rescue => e
        end
      end
      @observer = nil

      if @model_observer && Sketchup.active_model
        begin
          Sketchup.active_model.remove_observer(@model_observer)
        rescue => e
        end
      end
      @model_observer = nil

      if @entities_observer && Sketchup.active_model
        begin
          Sketchup.active_model.active_entities.remove_observer(@entities_observer)
        rescue => e
        end
      end
      @entities_observer = nil
    end

    def self.handle_cleared(dialog)
      return unless dialog
      payload = {
        'has_selection' => false,
        'message' => 'Không có đối tượng nào đang được chọn.'
      }
      send_to_js(dialog, payload)
    end

    # Tìm khối tổng lớn nhất (Tầng 1) chứa đối tượng được chọn
    def self.find_root_entity(entity, model)
      return entity unless entity && entity.valid? && model

      # 1. Nếu đang mở group để sửa (active_path)
      if model.active_path && !model.active_path.empty?
        return model.active_path.first
      end

      # 2. Truy ngược cây phân cấp cha để tìm Group / ComponentInstance ở tầng Model cao nhất
      curr = entity
      root = entity
      while curr
        parent = (curr.respond_to?(:parent) ? curr.parent : nil) rescue nil
        if parent.nil? || parent == model || parent.is_a?(Sketchup::Model)
          root = curr
          break
        elsif parent.is_a?(Sketchup::ComponentDefinition)
          instances = parent.instances rescue []
          if instances && !instances.empty?
            curr = instances.first
            root = curr
          else
            break
          end
        else
          break
        end
      end

      # 3. Nếu root vẫn là chính entity nhưng là một chi tiết nhỏ (ví dụ tay nắm/bản lề),
      # tìm khối tổng lớn nhất trong model
      if root == entity
        begin
          bb = entity.bounds
          dim_max = [bb.width.to_mm, bb.height.to_mm, bb.depth.to_mm].max
          if dim_max < 350 # Đối tượng nhỏ, chắc chắn là phụ kiện/chi tiết
            biggest_entity = nil
            biggest_vol = 0
            model.entities.each do |e|
              if (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid?
                vol = e.bounds.width * e.bounds.height * e.bounds.depth
                if vol > biggest_vol
                  biggest_vol = vol
                  biggest_entity = e
                end
              end
            end
            root = biggest_entity if biggest_entity
          end
        rescue => e
        end
      end

      root
    end

    def self.handle_selection(selection, dialog, force: false)
      return unless dialog
      if selection.nil? || selection.empty?
        return handle_cleared(dialog)
      end

      model = Sketchup.active_model
      return handle_cleared(dialog) unless model

      raw_entity = selection.first
      return handle_cleared(dialog) unless raw_entity

      target = raw_entity

      # 1. Nếu người dùng click vào Face hoặc Edge bên trong một Group/Component
      if target.is_a?(Sketchup::Face) || target.is_a?(Sketchup::Edge)
        face_mat = (target.respond_to?(:material) && target.material) ? target.material.display_name.to_s.downcase : ""
        bb = target.bounds
        dim_face = [bb.width.to_mm, bb.height.to_mm, bb.depth.to_mm].sort
        is_metal_face = face_mat.include?('metal') || face_mat.include?('sat') || face_mat.include?('nhom') || face_mat.include?('hafele') ||
                        (dim_face[0] <= 30 && dim_face[1] <= 40 && dim_face[2] <= 200)

        found_parent = nil
        if target.respond_to?(:parent) && target.parent.is_a?(Sketchup::ComponentDefinition)
          instances = target.parent.instances
          if instances && !instances.empty?
            found_parent = instances.first
          end
        end
        if model.active_path && !model.active_path.empty?
          found_parent ||= model.active_path.last
        end

        # Nếu là face kim loại / tay nắm nhưng found_parent lại là Cánh cửa hoặc Khối tủ:
        if is_metal_face && found_parent
          p_name = remove_accents(found_parent.name.to_s.downcase)
          if !p_name.include?('tay nam') && !p_name.include?('ban le') && !p_name.include?('phu kien')
            candidate_hw = nil
            container = (model.active_entities || model.entities)
            container.each do |e|
              next unless (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && e.valid?
              e_name = remove_accents(e.name.to_s.downcase)
              if e_name.include?('tay') || e.get_attribute('chill_ai', 'tier') == 3
                if (e.bounds.center.distance(target.bounds.center)).to_mm < 150
                  candidate_hw = e
                  break
                end
              end
            end
            found_parent = candidate_hw if candidate_hw
          end
        end

        target = found_parent if found_parent
      end

      return handle_cleared(dialog) unless target.is_a?(Sketchup::Drawingelement)

      # Bắt sự thay đổi kích thước khi co kéo 3D (Scale / Dynamic Component)
      bb = target.bounds
      current_bounds = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)]
      bounds_changed = (@last_bounds != current_bounds)
      @last_bounds = current_bounds

      now = Time.now.to_f
      if !force && !bounds_changed && @last_entity_id == target.entityID && (now - (@last_entity_time || 0) < 0.6)
        return
      end
      @last_entity_id = target.entityID
      @last_entity_time = now

      begin
        data = analyze_entity(target)
        return handle_cleared(dialog) unless data

        root_target = find_root_entity(target, model)
        root_data = nil
        if root_target && root_target.valid? && root_target != target
          root_data = analyze_entity(root_target)
        elsif data && data['tier'] == 1
          root_data = data
        end

        # QUÉT PHÁT HIỆN TẤM QUÁ KHỔ VÁN TIÊU CHUẨN 1220x2440MM (REAL-TIME DETECTION)
        scan_target = (root_target && root_target.valid?) ? root_target : target
        oversized_warning = check_oversized_warning(scan_target)

        # Tự động đồng bộ cảnh báo vào Dynamic Attributes (để hiện trong hộp thoại Component Options)
        sync_dc_warning_attributes(scan_target, oversized_warning)
        sync_dc_warning_attributes(target, oversized_warning) if target != scan_target

        # Cập nhật thanh trạng thái SketchUp
        if oversized_warning['has_oversized']
          first_p = oversized_warning['panels'].first
          excess_txt = first_p['excess_l'] > 0 ? "+#{first_p['excess_l']}mm chiều dài" : "+#{first_p['excess_w']}mm chiều rộng"
          Sketchup.status_text = "⚠️ [CHILL AI] CẢNH BÁO QUÁ KHỔ VÁN: #{oversized_warning['total_oversized']} tấm vượt khổ 1220x2440mm! (#{first_p['name']}: #{first_p['length']}x#{first_p['width']}mm, vượt #{excess_txt})"
        else
          Sketchup.status_text = "Chill AI: Đối tượng đạt chuẩn khổ ván công nghiệp 1220x2440mm."
        end

        payload = {
          'has_selection' => true,
          'data' => data,
          'root_data' => root_data,
          'oversized_warning' => oversized_warning
        }
        send_to_js(dialog, payload)
      rescue => e
        puts "[Chill AI] Lỗi phân tích vùng chọn: #{e.message}"
      end
    end

    # Gửi dữ liệu an toàn sang JavaScript
    def self.send_to_js(dialog, payload)
      return unless dialog
      begin
        json_str = payload.to_json
        script = "if(window.onSketchupSelectionChanged){ window.onSketchupSelectionChanged(#{json_str}); }"
        dialog.execute_script(script)
      rescue => e
        puts "[Chill AI] Lỗi gửi dữ liệu sang Plugin: #{e.message}"
      end
    end

    # --- PHÂN TÍCH ĐỐI TƯỢNG 3 TẦNG CHUYÊN SÂU ---
    def self.analyze_entity(entity)
      return nil unless entity && entity.valid?
      model = Sketchup.active_model
      return nil unless model

      bb = entity.bounds
      dim_x = bb.width.to_mm.round(1)
      dim_y = bb.height.to_mm.round(1)
      dim_z = bb.depth.to_mm.round(1)

      dims_sorted = [dim_x, dim_y, dim_z].sort
      thickness = dims_sorted[0]
      width_board = dims_sorted[1]
      length_board = dims_sorted[2]

      area_m2 = ((length_board * width_board) / 1_000_000.0).round(3)
      volume_m3 = ((length_board * width_board * thickness) / 1_000_000_000.0).round(4)
      edge_perimeter_m = (((length_board + width_board) * 2) / 1000.0).round(2)

      # 1. Đọc tên đối tượng
      raw_name = entity.name.to_s.strip
      if raw_name.empty? && entity.respond_to?(:definition)
        raw_name = entity.definition.name.to_s.strip
      end
      raw_name = "Đối tượng 3D" if raw_name.empty?

      # 2. Đọc vật liệu
      material_name = "MDF Lõi Xanh Chống Ẩm"
      if entity.material
        material_name = entity.material.display_name
      end

      # 3. Đọc thuộc tính do Chill AI gán (nếu có)
      custom_tier  = entity.get_attribute('chill_ai', 'tier')
      custom_name  = entity.get_attribute('chill_ai', 'name')
      custom_label = entity.get_attribute('chill_ai', 'tier_label')
      custom_cat   = entity.get_attribute('chill_ai', 'category')
      custom_icon  = entity.get_attribute('chill_ai', 'icon_type')

      raw_name = custom_name if custom_name && !custom_name.strip.empty?

      name_lower = raw_name.to_s.downcase
      name_ascii = remove_accents(name_lower)
      mat_lower  = material_name.to_s.downcase
      mat_ascii  = remove_accents(mat_lower)

      tier = 3
      tier_label = "Tầng 3: Miếng Ván Nhỏ (Part / Panel)"
      category = "Tấm Ván Sản Xuất"
      icon_type = "panel"

      # Nhận diện người mẫu tỷ lệ (Scale Figure như Sree, Stacy, Bryce...) trong SketchUp
      is_scale_figure = name_ascii.include?('sree') || name_ascii.include?('stacy') || name_ascii.include?('bryce') ||
                        name_ascii.include?('figure') || name_ascii.include?('person') || name_ascii.include?('nguoi') ||
                        name_ascii.include?('human') || name_ascii.include?('scale')

      is_wardrobe = !is_scale_figure && (
                    name_ascii.include?('tu ao') || name_ascii.include?('quan ao') || name_ascii.include?('wardrobe') || name_ascii.include?('closet') ||
                    ((name_ascii.include?('tu') || name_ascii.include?('cabinet')) && !name_ascii.include?('bep') && !name_ascii.include?('kitchen') && (dim_z >= 1200 || length_board >= 1200))
                    )
      
      is_kitchen  = !is_scale_figure && (name_ascii.include?('bep') || name_ascii.include?('kitchen'))
      is_bed      = !is_scale_figure && (name_ascii.include?('giuong') || name_ascii.include?('bed'))
      is_shelf    = !is_scale_figure && (name_ascii.include?('ke') || name_ascii.include?('shelf') || name_ascii.include?('gia sach'))
      is_desk     = !is_scale_figure && (name_ascii.include?('ban') || name_ascii.include?('desk') || name_ascii.include?('table'))
      is_cabinet  = !is_scale_figure && (is_wardrobe || is_kitchen || name_ascii.include?('tu') || name_ascii.include?('cabinet'))

      # Nhận diện chi tiết thành phần Tầng 2 & 3
      is_door       = name_ascii.include?('canh') || name_ascii.include?('door')
      is_table_top  = name_ascii.include?('mat ban') || name_ascii.include?('table top')
      is_metal_leg  = name_ascii.include?('chan') || name_ascii.include?('sat') || material_name.downcase.include?('metal') || material_name.downcase.include?('sắt')
      is_drawer_box = name_ascii.include?('hoc') || name_ascii.include?('ngan keo') || name_ascii.include?('drawer')

      model_type = if is_scale_figure
        'scale_figure'
      elsif is_wardrobe
        'wardrobe'
      elsif is_kitchen
        'kitchen_cabinet'
      elsif is_bed
        'bed'
      elsif is_shelf
        'shelf'
      elsif is_desk
        'desk'
      elsif is_cabinet
        'cabinet'
      elsif thickness <= 45
        'panel'
      else
        'cabinet'
      end

      if custom_tier
        tier = custom_tier.to_i
        tier_label = custom_label || "Tầng #{tier}"
        category = custom_cat || "Chi Tiết Nội Thất"
        icon_type = custom_icon || "panel"
      else
        has_sub_groups = entity.respond_to?(:entities) && entity.entities.any? { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        sub_group_count = entity.respond_to?(:entities) ? entity.entities.count { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) } : 0

        if is_scale_figure
          tier = 1
          tier_label = "Mẫu Người Tỷ Lệ (Scale Figure)"
          category = "Người Mẫu Tham Chiếu Không Gian"
          icon_type = "person"
        elsif (has_sub_groups && (sub_group_count >= 2 || name_lower.include?('chill_ai') || name_lower.include?('tổng') || is_cabinet || is_desk || is_bed || is_shelf)) || (is_wardrobe || is_kitchen || is_bed || is_desk)
          tier = 1
          tier_label = if is_wardrobe
            "Tầng 1: Khối Tổng (Hệ Tủ Quần Áo)"
          elsif is_kitchen
            "Tầng 1: Khối Tổng (Hệ Tủ Bếp)"
          elsif is_desk
            "Tầng 1: Khối Tổng (Bàn Làm Việc)"
          elsif is_bed
            "Tầng 1: Khối Tổng (Giường Ngủ)"
          else
            "Tầng 1: Khối Tổng (Composite Assembly)"
          end
          category = if is_wardrobe
            "Hệ Tủ Quần Áo Đa Năng"
          elsif is_kitchen
            "Hệ Tủ Bếp Module"
          elsif is_desk
            "Bàn Làm Việc / Bàn Trà"
          elsif is_bed
            "Giường Ngủ Hiện Đại"
          else
            "Tổ Hợp Khối Tổng"
          end
          icon_type = "assembly"
        elsif is_door
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Cánh Cửa Tủ)"
          category = "Module Cánh Mở / Cánh Kéo"
          icon_type = "door"
        elsif is_drawer_box
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Hộc Ngăn Kéo)"
          category = "Module Ngăn Kéo Trượt"
          icon_type = "module"
        elsif is_table_top
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Mặt Bàn Gỗ)"
          category = "Chi Tiết Mặt Bàn Chịu Lực"
          icon_type = "panel"
        elsif is_metal_leg
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Khung Chân Sắt)"
          category = "Kết Cấu Chịu Lực"
          icon_type = "module"
        elsif has_sub_groups
          tier = 2
          tier_label = "Tầng 2: Khối Module Lẻ"
          category = "Module Thành Phần"
          icon_type = "module"
        else
          tier = 3
          if thickness <= 25 && (name_lower.include?('tay') || name_lower.include?('ban le') || length_board < 150)
            tier_label = "Tầng 3: Phụ Kiện Kim Khí (Hardware)"
            category = "Phụ Kiện"
            icon_type = "hardware"
          else
            tier_label = "Tầng 3: Miếng Ván Nhỏ (Part / Panel)"
            category = "Tấm Ván Sản Xuất"
            icon_type = "panel"
          end
        end
      end

      # 4. Xây dựng Breadcrumb Phân Cấp
      breadcrumb = []
      root_title = if is_wardrobe
        "Hệ Tủ Quần Áo"
      elsif is_kitchen
        "Hệ Tủ Bếp"
      elsif is_desk
        "Bàn Làm Việc"
      elsif is_bed
        "Giường Ngủ"
      else
        raw_name
      end

      case tier
      when 1
        breadcrumb = [raw_name]
      when 2
        breadcrumb = [root_title, raw_name]
      when 3
        module_name = is_door ? "Hệ Cánh Cửa" : (is_drawer_box ? "Khối Ngăn Kéo" : "Thùng Tủ")
        breadcrumb = [root_title, module_name, raw_name]
      end

      # 5. Danh sách phụ kiện liên kết đi kèm
      hardware_list = []
      if is_table_top || (tier == 2 && raw_name.downcase.include?('mặt bàn'))
        hardware_list = [
          { 'name' => 'Pát sắt liên kết chữ Z bắt mặt bàn', 'qty' => '8 bộ', 'type' => 'connect' },
          { 'name' => 'Vít tự khoan gỗ 4x25 bắt vào khung', 'qty' => '16 con', 'type' => 'screw' }
        ]
      elsif tier == 1
        hardware_list = [
          { 'name' => 'Bulong liên kết module M6x30', 'qty' => 12, 'type' => 'connect' },
          { 'name' => 'Chân tăng chỉnh chịu lực', 'qty' => 8, 'type' => 'leg' },
          { 'name' => 'Nẹp viền chống ẩm chân tủ', 'qty' => 2, 'type' => 'plinth' }
        ]
      elsif tier == 2
        hardware_list = [
          { 'name' => 'Bản lề giảm chấn Blum Clip Top 110°', 'qty' => 4, 'type' => 'hinge' },
          { 'name' => 'Tay nắm hợp kim nhôm Hafele 160mm', 'qty' => 2, 'type' => 'handle' },
          { 'name' => 'Ốc cam liên kết & chốt gỗ phi 8', 'qty' => 16, 'type' => 'cam' }
        ]
      else
        hardware_list = [
          { 'name' => 'Chỉ nẹp PVC dán cạnh viền (Dày 1mm)', 'qty' => "#{edge_perimeter_m}m", 'type' => 'edge' },
          { 'name' => 'Đinh vít tự khoan gỗ 4x35mm', 'qty' => 6, 'type' => 'screw' }
        ]
      end

      # 6. Tích hợp dữ liệu Hàng Hóa Chuẩn Shopee & Tìm Nơi Bán Gần Bạn Theo Bán Kính
      goods_info = build_goods_info(raw_name, tier, category, material_name, thickness, length_board, width_board, edge_perimeter_m)

      {
        'entity_id' => entity.entityID,
        'name' => raw_name,
        'model_type' => model_type,
        'tier' => tier,
        'tier_label' => tier_label,
        'category' => category,
        'icon_type' => icon_type,
        'dim_x' => dim_x,
        'dim_y' => dim_y,
        'dim_z' => dim_z,
        'length' => length_board,
        'width' => width_board,
        'thickness' => thickness,
        'material' => material_name,
        'area_m2' => area_m2,
        'volume_m3' => volume_m3,
        'edge_perimeter_m' => edge_perimeter_m,
        'breadcrumb' => breadcrumb,
        'hardware_list' => hardware_list,
        'is_cnc_ready' => (thickness >= 9 && thickness <= 36),
        'goods_info' => goods_info
      }
    end

    # --- HỆ THỐNG THÔNG TIN HÀNG HÓA MUA VẬT TƯ & TÌM NHÀ CUNG CẤP GẦN BẠN ---
    def self.build_goods_info(name, tier, category, material, thickness, length, width, edge_m)
      name_lower = name.to_s.downcase
      name_ascii = remove_accents(name_lower)
      mat_lower  = material.to_s.downcase
      mat_ascii  = remove_accents(mat_lower)

      # Ưu tiên nhận diện chính xác từng loại vật tư (Không để kim loại nhôm inox làm nhầm thành chân bàn)
      is_handle    = name_ascii.include?('tay nam') || name_ascii.include?('tay keo') || name_ascii.include?('handle') || name_ascii.include?('pull') || name_ascii.include?('knob')
      is_hinge     = name_ascii.include?('ban le') || name_ascii.include?('hinge')
      is_slide     = name_ascii.include?('ray') || (name_ascii.include?('ngan keo') && !name_ascii.include?('mat')) || name_ascii.include?('slide')
      is_cam_lock  = name_ascii.include?('cam') || name_ascii.include?('chot') || name_ascii.include?('vit') || name_ascii.include?('oc')
      is_table_top = name_ascii.include?('mat ban') || name_ascii.include?('table top')
      is_metal_leg = (name_ascii.include?('chan') && (name_ascii.include?('sat') || mat_ascii.include?('metal') || mat_ascii.include?('sat'))) || (name_ascii.include?('khung') && name_ascii.include?('ban'))

      if is_handle
        sku = "HDL-ALU-TITAN-#{length.to_i > 0 ? length.to_i : 128}"
        title = "[Chính Hãng Chill Decor / Hafele] Tay Nắm Hợp Kim Nhôm Đúc Nguyên Khối Anode Cao Cấp Cho Tủ Áo & Ngăn Kéo"
        brand = "Chill Hardware & Hafele Standard"
        style_name = "Hiện Đại Tối Giản (Modern Minimalist / Bắc Âu Luxury)"
        origin_country = "OEM Chuẩn Xuất Khẩu Châu Âu"
        color_options = ["Đen Nhám Anode", "Vàng Xước Titan", "Bạc Chrome Sáng", "Xám Gunmetal"]
        size_options = ["Tim 96mm (Dài 115)", "Tim 128mm (Dài 150)", "Tim 160mm (Dài 185)", "Tim 192mm (Dài 220)"]
        price_cur = "32.000 đ"
        price_orig = "45.000 đ"
        discount = "-29%"
        unit = "/ Cái (Kèm 02 ốc vít M4)"
        warranty_text = "Bảo hành 24 tháng chính hãng chống bay màu & gỉ sét mồ hôi tay"
        return_text = "1 đổi 1 trong 30 ngày nếu lỗi ren ốc hoặc trầy xước từ nhà sản xuất"
        durability_score = "9.9 / 10 điểm"
        user_review = "Chất nhôm đúc đầm tay chắc nịch, lớp mạ đen nhám mịn màng không bám vân tay. Bắt vào cánh tủ áo nhìn sang hơn hẳn tay nắm thông thường ngoài chợ!"
        shop_desc = "• Chất liệu: Hợp kim nhôm đặc đúc áp lực cao, không rỗng ruột.\n• Công nghệ mạ: Xử lý điện hóa Anode hóa cứng chịu ma sát mồ hôi tay.\n• Phụ kiện: Tặng kèm 02 ốc vít M4x22 tiêu chuẩn cho ván 17.5mm."
        specs = "Dài #{length.to_i > 0 ? length.to_i : 128}mm • Cao 22mm • Bản rộng 12mm • Tim ốc chuẩn CNC"
        badge = "Shopee Mall"
        rating = 4.96
        sold_count = "18.5k đã bán"
        suppliers = [
          { name: "Tổng Kho Phụ Kiện Kim Khí Mộc Cầu Giấy", city: "Hà Nội", dist_km: 1.1, stock: "Sẵn kho 3.500 cái", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
          { name: "Đại Lý Tay Nắm & Bản Lề Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.3, stock: "Sẵn kho 6.000 cái", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
          { name: "Kho Phụ Kiện Tủ Áo Hóc Môn TP.HCM", city: "TP. Hồ Chí Minh", dist_km: 1.5, stock: "Sẵn kho 5.200 cái", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" },
          { name: "Tổng Kho Bản Lề Tay Nắm Thuận An Bình Dương", city: "Bình Dương", dist_km: 3.6, stock: "Sẵn kho 4.800 cái", phone: "0968.111.444", addr: "Đại lộ Bình Dương, Thuận An, Bình Dương" }
        ]
      elsif is_hinge
        sku = "HW-BLUM-110-SC"
        title = "[Chính Hãng Blum / Ivan] Bản Lề Giảm Chấn Thủy Lực Inox 304 Bật Tháo Lắp Nhanh Cho Tủ Bếp & Tủ Áo"
        brand = "Blum / Ivan Austria Design"
        style_name = "Kỹ Thuật Công Nghiệp Đức"
        origin_country = "Chính Hãng Áo / Đức"
        color_options = ["Inox 304 Sáng Bóng", "Thép Mạ Niken", "Sơn Tĩnh Điện Đen Titan"]
        size_options = ["Cong vừa (Trùm nửa)", "Thẳng (Trùm ngoài)", "Cong nhiều (Lọt lòng)"]
        price_cur = "38.000 đ"
        price_orig = "50.000 đ"
        discount = "-24%"
        unit = "/ Cái (Kèm đế & ốc vít)"
        warranty_text = "Bảo hành trọn đời chống xệ cánh • 1 đổi 1 trong 1 năm"
        return_text = "Đổi mới ngay lập tức nếu piston thủy lực xì dầu hoặc kẹt lò xo"
        durability_score = "9.8 / 10 điểm"
        user_review = "Đóng mở êm ru không 1 tiếng động, cánh tủ tự hít vào nhẹ nhàng. Đã dùng cho hàng trăm công trình chưa từng bị lỗi xệ cánh."
        shop_desc = "• Thép không rỉ Inox 304 dày 1.5mm, piston đồng thủy lực đôi.\n• Góc mở rộng 110 độ, điều chỉnh 3D đa hướng (lên-xuống, ra-vào, trái-phải).\n• Đạt chứng nhận 80.000 lần đóng mở tiêu chuẩn LGA Đức."
        specs = "Góc mở 110° • Giảm chấn thủy lực êm ái • Thử nghiệm 80.000 lần đóng mở"
        badge = "Shopee Mall"
        rating = 4.98
        sold_count = "12.5k đã bán"
        suppliers = [
          { name: "Tổng Kho Phụ Kiện Kim Khí Blum - Hafele Cầu Giấy", city: "Hà Nội", dist_km: 0.9, stock: "Sẵn kho 2.500 bộ", phone: "0982.555.666", addr: "Nguyễn Phong Sắc, Cầu Giấy, Hà Nội" },
          { name: "Trung Tâm Phụ Kiện Ngành Mộc DTC & Ivan Thạch Thất", city: "Hà Nội", dist_km: 2.8, stock: "Sẵn kho 5.000 bộ", phone: "0971.222.333", addr: "Đường tỉnh 419, Thạch Thất, Hà Nội" },
          { name: "Tổng Kho Phụ Kiện Mộc Hóc Môn - Q12", city: "TP. Hồ Chí Minh", dist_km: 1.6, stock: "Sẵn kho 4.200 bộ", phone: "0902.333.444", addr: "Quang Trung, P.14, Gò Vấp / Q12, TP.HCM" }
        ]
      elsif tier == 1
        sku = "KIT-MOD-PRO-#{length.to_i}"
        title = "[Hàng Đặt May Đo] #{name} Cao Cấp Chống Ẩm HMR Đạt Chuẩn Xuất Khẩu"
        brand = "Chill AI & Xưởng Đối Tác Cấp 1"
        style_name = "Hiện Đại May Đo (Bespoke Luxury)"
        origin_country = "Gia Công CNC Tại Xưởng Liên Kết Chill AI"
        color_options = ["Vân Gỗ Sồi Sáng", "Óc Chó Bắc Mỹ", "Trắng Sứ Acrylic", "Xám Ghi Bê Tông"]
        size_options = ["May đo theo kích thước phòng", "Khổ chuẩn 1600x2200", "Khổ chuẩn 1800x2400"]
        price_cur = "4.200.000 đ"
        price_orig = "5.000.000 đ"
        discount = "-16%"
        unit = "Mét dài / Bộ"
        is_wardrobe_item = name_lower.include?('áo') || name_lower.include?('tủ') || name_lower.include?('wardrobe')
        specs = is_wardrobe_item ? "Dài #{length.to_i}mm • Cao 1800-2400mm • Sâu #{width.to_i}mm • Thùng Gỗ Sồi / MDF Chống Ẩm" : "Dài #{length.to_i}mm • Cao 750-810mm • Sâu #{width.to_i}mm • Thùng MDF Chống Ẩm V313"
        warranty_text = "Bảo hành kết cấu 5 năm • Bảo trì trọn đời hệ phụ kiện"
        return_text = "Cam kết đúng mẫu 3D và vật liệu đã duyệt, đền 200% nếu sai vật liệu"
        durability_score = "9.9 / 10 điểm"
        user_review = "Đường cắt CNC sắc lẹm, dán cạnh PUR không đường line kháng nước cực tốt. Thi công lắp ráp cực nhanh nhờ hệ cam chốt chính xác!"
        shop_desc = "• Ván MDF Lõi Xanh chống ẩm V313 phủ Melamine chống trầy xước.\n• Gia công tự động trên dây chuyền CNC 4 đầu trung tâm.\n• Phụ kiện giảm chấn đồng bộ chính hãng Hafele / Blum."
        badge = "Shopee Mall"
        rating = 4.9
        sold_count = "1.8k đã đặt"
        suppliers = [
          { name: "Tổng Kho Nội Thất May Đo Chàng Sơn - Thạch Thất", city: "Hà Nội", dist_km: 2.1, stock: "Sẵn xưởng sản xuất", phone: "0988.123.456", addr: "KCN Làng Nghề Chàng Sơn, Thạch Thất, Hà Nội" },
          { name: "Nhà Máy Gia Công Nội Thất CNC Cầu Giấy", city: "Hà Nội", dist_km: 3.5, stock: "Nhận đơn 24h", phone: "0977.888.999", addr: "Phố Duy Tân, Cầu Giấy, Hà Nội" },
          { name: "Xưởng Mộc Công Nghệ Nam Từ Liêm", city: "Hà Nội", dist_km: 7.2, stock: "Sẵn phôi ván", phone: "0912.345.678", addr: "Đại lộ Thăng Long, Nam Từ Liêm, Hà Nội" },
          { name: "Xưởng Sản Xuất Module Nội Thất Hóc Môn", city: "TP. Hồ Chí Minh", dist_km: 1.8, stock: "Giao ngay 24h", phone: "0909.111.222", addr: "Đường Lê Thị Hà, Hóc Môn, TP.HCM" }
        ]
      elsif is_table_top
        sku = "TOP-OAK-FAS-#{length.to_i}"
        title = "[Gỗ Tự Nhiên] Mặt Bàn Gỗ Sồi Nga (White Oak) Sấy FAS Nguyên Tấm Bo Cạnh Mịn"
        brand = "Gỗ Sồi Bắc Mỹ (White Oak)"
        style_name = "Scandinavian Gỗ Tự Nhiên"
        origin_country = "Gỗ Nhập Khẩu Nga / Mỹ"
        color_options = ["Màu Gỗ Tự Nhiên Lau Dầu", "Màu Óc Chó Lau Dầu", "Sơn PU Mờ 70%"]
        size_options = ["#{length.to_i}x#{width.to_i}mm", "1200x600mm", "1400x700mm", "1600x800mm"]
        price_cur = "1.350.000 đ"
        price_orig = "1.650.000 đ"
        discount = "-18%"
        unit = "Tấm hoàn thiện"
        warranty_text = "Bảo hành 36 tháng không cong vênh, mối mọt"
        return_text = "Đổi mới trong 30 ngày nếu có vết nứt do co ngót tự nhiên"
        durability_score = "9.7 / 10 điểm"
        user_review = "Vân gỗ sồi núi cuộn cực đẹp, thớ gỗ dày đanh. Bo viền vát cạnh mịn màng tì tay làm việc cả ngày không đau."
        shop_desc = "• Gỗ sồi tự nhiên sấy lò chuẩn FAS độ ẩm dưới 12%.\n• Bo cạnh tròn R5 an toàn, chống trầy xước.\n• Sơn phủ dầu lau Osmo nhập khẩu Đức an toàn cho sức khỏe."
        specs = "Quy cách: #{length.to_i}x#{width.to_i}x#{thickness.to_i}mm • Độ ẩm <12% • Sơn lau dầu bóng mờ"
        badge = "Shop Yêu Thích+"
        rating = 4.95
        sold_count = "840 tấm"
        suppliers = [
          { name: "Tổng Kho Gỗ Tự Nhiên Nhập Khẩu Thạch Thất", city: "Hà Nội", dist_km: 1.5, stock: "Sẵn kho 320 tấm", phone: "0988.666.777", addr: "KCN Thạch Thất - Quốc Oai, Hà Nội" },
          { name: "Xưởng Xẻ Sấy Gỗ Sồi Nga Cầu Giấy", city: "Hà Nội", dist_km: 4.2, stock: "Sẵn kho 150 tấm", phone: "0977.333.444", addr: "Đường Trần Thái Tông, Cầu Giấy, Hà Nội" }
        ]
      elsif is_metal_leg
        sku = "LEG-STL-4040-BLK"
        title = "[Thép Hòa Phát] Khung Chân Bàn Sắt Hộp 40x40mm Sơn Tĩnh Điện Đen Nhám Chống Rỉ"
        brand = "Thép Hộp Hòa Phát Chính Hãng"
        style_name = "Industrial Hiện Đại Khỏe Khoắn"
        origin_country = "Gia Công Cơ Khí Hòa Phát"
        color_options = ["Sơn Đen Nhám", "Sơn Trắng Sứ", "Mạ Kẽm Nhúng Nóng"]
        size_options = ["Hộp 40x40mm (Cao 725)", "Hộp 50x25mm (Cao 725)", "Hộp 50x50mm (Cao 725)"]
        price_cur = "520.000 đ"
        price_orig = "650.000 đ"
        discount = "-20%"
        unit = "Bộ khung chân"
        warranty_text = "Bảo hành mối hàn kết cấu 5 năm • Lớp sơn tĩnh điện 24 tháng"
        return_text = "1 đổi 1 trong 30 ngày nếu bập bênh hoặc lỗi mối hàn"
        durability_score = "9.8 / 10 điểm"
        user_review = "Khung sắt hộp dày 1.4ly rất chắc chắn, sơn sần tĩnh điện sờ sướng tay. Chân đế cao su vặn tăng chỉnh được nên bàn đứng vững như bàn thạch."
        shop_desc = "• Thép hộp Hòa Phát 40x40 độ dày 1.4ly.\n• Hàn ngấu công nghệ CO2 mài nhẵn góc cạnh.\n• Sơn sần tĩnh điện outdoor chống xước và oxy hóa."
        specs = "Thép hộp 40x40 độ dày 1.4ly • Sơn sần tĩnh điện outdoor • Tải trọng 300kg"
        badge = "Shopee Mall"
        rating = 4.88
        sold_count = "1.2k bộ"
        suppliers = [
          { name: "Xưởng Cơ Khí Sắt Sơn Tĩnh Điện Cầu Giấy", city: "Hà Nội", dist_km: 1.2, stock: "Sẵn kho 180 bộ", phone: "0966.888.111", addr: "Ngõ 199 Hồ Tùng Mậu, Cầu Giấy, Hà Nội" },
          { name: "Đại Lý Sắt Hộp Hòa Phát Nam Từ Liêm", city: "Hà Nội", dist_km: 3.8, stock: "Sẵn kho 500 bộ", phone: "0977.222.111", addr: "Tố Hữu, Nam Từ Liêm, Hà Nội" }
        ]
      else
        sku = "MDF-HMR-AC-#{thickness.to_i}"
        title = "[Chính Hãng An Cường] Ván Gỗ MDF Lõi Xanh Chống Ẩm Melamine #{thickness}mm Tiêu Chuẩn E1"
        brand = "Gỗ An Cường (Chống Ẩm HMR)"
        style_name = "Hiện Đại Vân Gỗ / Đơn Sắc"
        origin_country = "Nhà Máy An Cường Bình Dương"
        color_options = ["Mã MS 388 (Óc Chó)", "Mã MS 201 (Sồi Nga)", "Mã MS 101 (Trắng Sứ)", "Mã MS 402 (Xám Bê Tông)"]
        size_options = ["Khổ 1220x2440x17.5mm", "Khổ 1220x2440x9mm", "Khổ 1220x2440x25mm"]
        price_cur = "395.000 đ"
        price_orig = "460.000 đ"
        discount = "-14%"
        unit = "Tấm (1220x2440mm)"
        warranty_text = "Bảo hành 10 năm không cong vênh, chống ẩm mốc V313"
        return_text = "1 đổi 1 tận nơi nếu ván bị mẻ cạnh hoặc trầy xước bề mặt khi giao"
        durability_score = "9.9 / 10 điểm"
        user_review = "Ván MDF lõi xanh An Cường thì không cần bàn cãi, lõi đanh khít, cắt CNC không bị mẻ cạnh Melamine. Dùng làm tủ bếp tủ áo cực kỳ yên tâm!"
        shop_desc = "• Ván sợi mật độ cao HMR tỷ trọng 740kg/m³.\n• Đạt chứng chỉ Green Label Singapore và phát thải formaldehyde chuẩn E1.\n• Phủ Melamine 2 mặt chống trầy cấp độ AC3."
        specs = "Khổ ván 1220x2440x#{thickness}mm • Tỷ trọng 730kg/m³ • Keo V313 chống nước • Chỉ dán nẹp #{edge_m}m"
        badge = "Shopee Mall"
        rating = 4.92
        sold_count = "6.8k tấm"
        suppliers = [
          { name: "Đại Lý Cấp 1 Phân Phối Gỗ An Cường Cầu Giấy", city: "Hà Nội", dist_km: 1.4, stock: "Sẵn kho 850 tấm", phone: "0983.999.888", addr: "Đường Cầu Giấy, P. Quan Hoa, Cầu Giấy, Hà Nội" },
          { name: "Tổng Kho Ván Gỗ MDF Chống Ẩm Thạch Thất", city: "Hà Nội", dist_km: 2.6, stock: "Sẵn kho 1.500 tấm", phone: "0975.123.789", addr: "Làng Nghề Canh Nậu, Thạch Thất, Hà Nội" },
          { name: "Kho Ván MDF Melamine Nam Từ Liêm", city: "Hà Nội", dist_km: 5.1, stock: "Sẵn kho 600 tấm", phone: "0916.456.789", addr: "Lê Quang Đạo, Nam Từ Liêm, Hà Nội" },
          { name: "Tổng Đại Lý Ván An Cường & Minh Long Hóc Môn", city: "TP. Hồ Chí Minh", dist_km: 1.9, stock: "Sẵn kho 1.200 tấm", phone: "0907.888.999", addr: "Phan Văn Hớn, Xuân Thới Thượng, Hóc Môn, TP.HCM" }
        ]
      end

      {
        'sku' => sku,
        'title' => title,
        'brand' => brand,
        'style' => style_name,
        'origin' => origin_country,
        'color_options' => color_options,
        'size_options' => size_options,
        'price_current' => price_cur,
        'price_original' => price_orig,
        'discount' => discount,
        'unit' => unit,
        'warranty' => warranty_text,
        'return_policy' => return_text,
        'durability_score' => durability_score,
        'user_review' => user_review,
        'shop_description' => shop_desc,
        'specs' => specs,
        'badge' => badge,
        'rating' => rating,
        'sold_count' => sold_count,
        'suppliers' => suppliers
      }
    end

    # Zoom camera trong SketchUp đến đối tượng
    def self.zoom_to_entity(entity_id)
      model = Sketchup.active_model
      return unless model
      entity = model.find_entity_by_id(entity_id.to_i)
      if entity && model.active_view
        model.selection.clear
        model.selection.add(entity)
        model.active_view.zoom(entity)
        Sketchup.status_text = "Chill AI: Đã zoom tiêu điểm đến #{entity.name}"
      end
    end

    MAX_STANDARD_SHEET_L = 2440.0 # mm (Khổ ván tiêu chuẩn)
    MAX_STANDARD_SHEET_W = 1220.0 # mm (Khổ ván tiêu chuẩn)
    MAX_STANDARD_SHEET_L = 2440.0 # mm
    MAX_STANDARD_SHEET_W = 1220.0 # mm
    MAX_PANEL_THICKNESS   = 45.0   # mm

    # Lấy hệ số tỉ lệ thực tế (World Scale Factor) từ ma trận Transformation
    def self.get_scaling_factor(transformation)
      return [1.0, 1.0, 1.0] unless transformation
      m = transformation.to_a
      sx = Math.sqrt(m[0]**2 + m[1]**2 + m[2]**2)
      sy = Math.sqrt(m[4]**2 + m[5]**2 + m[6]**2)
      sz = Math.sqrt(m[8]**2 + m[9]**2 + m[10]**2)
      [sx > 0.0001 ? sx : 1.0, sy > 0.0001 ? sy : 1.0, sz > 0.0001 ? sz : 1.0]
    end

    # Đệ quy tìm kiếm tất cả tấm ván chi tiết con trong một Group hoặc Component,
    # CÓ TÍNH TOÁN ĐẦY ĐỦ TỶ LỆ CO KÉO THỰC TẾ TRONG KHÔNG GIAN WORLD (WORLD SCALE)
    def self.collect_all_panels(entity, list = [], depth = 0, current_scale = [1.0, 1.0, 1.0])
      return list unless entity && entity.valid?
      return list if depth > 6

      name_str = entity.name.to_s
      return list if name_str.start_with?("CHILL_AI_NESTING")

      combined_scale = current_scale.dup
      if entity.respond_to?(:transformation)
        inst_scale = get_scaling_factor(entity.transformation)
        combined_scale = [
          combined_scale[0] * inst_scale[0],
          combined_scale[1] * inst_scale[1],
          combined_scale[2] * inst_scale[2]
        ]
      end

      bb = entity.bounds
      if depth == 0
        w_real = bb.width.to_mm.round(1)
        h_real = bb.height.to_mm.round(1)
        d_real = bb.depth.to_mm.round(1)
      else
        w_real = (bb.width.to_mm * current_scale[0]).round(1)
        h_real = (bb.height.to_mm * current_scale[1]).round(1)
        d_real = (bb.depth.to_mm * current_scale[2]).round(1)
      end

      dims = [w_real, h_real, d_real].sort
      t = dims[0]
      w = dims[1]
      l = dims[2]

      sub_entities = []
      if entity.is_a?(Sketchup::Group)
        sub_entities = entity.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      elsif entity.is_a?(Sketchup::ComponentInstance)
        sub_entities = entity.definition.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      end

      if sub_entities.empty?
        # Leaf Panel hoặc Chi tiết đơn lẻ
        panel_name = entity.name.to_s.strip
        if panel_name.empty? && entity.respond_to?(:definition)
          panel_name = entity.definition.name.to_s.strip
        end
        panel_name = "Tấm Ván" if panel_name.empty?

        is_oversized_l = (l > MAX_STANDARD_SHEET_L)
        is_oversized_w = (w > MAX_STANDARD_SHEET_W)
        is_oversized = is_oversized_l || is_oversized_w

        list << {
          'entity_id' => entity.entityID,
          'name' => panel_name,
          'length' => l,
          'width' => w,
          'thickness' => t,
          'is_oversized' => is_oversized,
          'is_oversized_l' => is_oversized_l,
          'is_oversized_w' => is_oversized_w,
          'excess_l' => is_oversized_l ? (l - MAX_STANDARD_SHEET_L).round(1) : 0.0,
          'excess_w' => is_oversized_w ? (w - MAX_STANDARD_SHEET_W).round(1) : 0.0,
          'reason' => if is_oversized_l && is_oversized_w
            "Dài #{l}mm > 2440mm (+#{(l - MAX_STANDARD_SHEET_L).round(1)}mm) & Rộng #{w}mm > 1220mm (+#{(w - MAX_STANDARD_SHEET_W).round(1)}mm)"
          elsif is_oversized_l
            "Chiều dài #{l}mm vượt quá khổ tiêu chuẩn 2440mm (quá +#{(l - MAX_STANDARD_SHEET_L).round(1)}mm)"
          elsif is_oversized_w
            "Chiều rộng #{w}mm vượt quá khổ tiêu chuẩn 1220mm (quá +#{(w - MAX_STANDARD_SHEET_W).round(1)}mm)"
          else
            "Đạt chuẩn khổ ván 1220x2440mm"
          end,
          'solution' => if is_oversized_l
            "Khuyến nghị: Chia nhỏ chi tiết, ghép mộng/cam chốt hoặc dùng ván khổ lớn 2745mm."
          elsif is_oversized_w
            "Khuyến nghị: Cắt giảm chiều rộng hoặc ghép nối 2 mảnh ván."
          else
            "Sẵn sàng cắt CNC."
          end
        }
      else
        sub_entities.each do |sub|
          collect_all_panels(sub, list, depth + 1, combined_scale)
        end
      end

      list
    end

    # Kiểm tra tổng thể cảnh báo tấm quá khổ (Cả cấp độ chi tiết lẫn cấp độ khối tổng thể)
    def self.check_oversized_warning(entity)
      return { 'has_oversized' => false, 'panels' => [] } unless entity && entity.valid?

      all_panels = collect_all_panels(entity)
      oversized_panels = all_panels.select { |p| p['is_oversized'] }

      # KIỂM TRA THÊM CẤP ĐỘ KHỐI TỔNG (MACRO CHECK):
      # Nếu bản thân Bounding Box của đối tượng ngoài viewport vượt 2440mm hoặc 1220mm,
      # thì CHẮC CHẮN chứa thành phần vượt khổ ván công nghiệp!
      bb = entity.bounds
      root_dims = [bb.width.to_mm.round(1), bb.height.to_mm.round(1), bb.depth.to_mm.round(1)].sort
      root_t = root_dims[0]
      root_w = root_dims[1]
      root_l = root_dims[2]

      root_is_oversized_l = (root_l > MAX_STANDARD_SHEET_L)
      root_is_oversized_w = (root_w > MAX_STANDARD_SHEET_W)

      if (root_is_oversized_l || root_is_oversized_w) && oversized_panels.empty?
        obj_name = entity.name.to_s.strip
        if obj_name.empty? && entity.respond_to?(:definition)
          obj_name = entity.definition.name.to_s.strip
        end
        obj_name = "Khối Đối Tượng 3D" if obj_name.empty?

        oversized_panels << {
          'entity_id' => entity.entityID,
          'name' => obj_name,
          'length' => root_l,
          'width' => root_w,
          'thickness' => root_t,
          'is_oversized' => true,
          'is_oversized_l' => root_is_oversized_l,
          'is_oversized_w' => root_is_oversized_w,
          'excess_l' => root_is_oversized_l ? (root_l - MAX_STANDARD_SHEET_L).round(1) : 0.0,
          'excess_w' => root_is_oversized_w ? (root_w - MAX_STANDARD_SHEET_W).round(1) : 0.0,
          'reason' => if root_is_oversized_l && root_is_oversized_w
            "Chiều dài #{root_l}mm > 2440mm (+#{(root_l - MAX_STANDARD_SHEET_L).round(1)}mm) & Rộng #{root_w}mm > 1220mm (+#{(root_w - MAX_STANDARD_SHEET_W).round(1)}mm)"
          elsif root_is_oversized_l
            "Chiều dài #{root_l}mm vượt quá khổ ván tiêu chuẩn 2440mm (quá +#{(root_l - MAX_STANDARD_SHEET_L).round(1)}mm)"
          else
            "Chiều rộng #{root_w}mm vượt quá khổ ván tiêu chuẩn 1220mm (quá +#{(root_w - MAX_STANDARD_SHEET_W).round(1)}mm)"
          end,
          'solution' => "Khuyến nghị: Thu bớt chiều dài hoặc đổi cấu hình sang ván khổ lớn 2745mm."
        }
      end

      {
        'has_oversized' => !oversized_panels.empty?,
        'total_oversized' => oversized_panels.length,
        'total_scanned_panels' => [all_panels.length, 1].max,
        'standard_sheet' => { 'length' => MAX_STANDARD_SHEET_L, 'width' => MAX_STANDARD_SHEET_W },
        'panels' => oversized_panels
      }
    end

    # Đồng bộ cảnh báo trực tiếp vào Dynamic Attributes để hiện lên hộp thoại Component Options
    def self.sync_dc_warning_attributes(entity, warning)
      return unless entity && entity.valid? && entity.is_a?(Sketchup::ComponentInstance)
      comp_def = entity.definition rescue nil
      return unless comp_def

      dict = comp_def.attribute_dictionary('dynamic_attributes', true)
      has_over = warning['has_oversized']
      if has_over
        p0 = warning['panels'].first
        excess_txt = p0['excess_l'] > 0 ? "+#{p0['excess_l'].to_i}mm" : "+#{p0['excess_w'].to_i}mm"
        status_str = "⚠️ QUÁ KHỔ VÁN: #{p0['length'].to_i}x#{p0['width'].to_i}mm (#{excess_txt})"
      else
        status_str = "✅ ĐẠT CHUẨN KHỔ VÁN (1220x2440mm)"
      end

      dict['canh_bao_kho_van'] = status_str
      dict['_canh_bao_kho_van_access'] = 'VIEW'
      dict['_canh_bao_kho_van_label'] = 'Trạng Thái Khổ Ván CNC'
      dict['_canh_bao_kho_van_formlabel'] = 'Khổ Ván 1220x2440mm'
      dict['_canh_bao_kho_van_formula'] = 'IF(OR(LenX>96.06, LenY>96.06, LenZ>96.06), "⚠️ CẢNH BÁO: QUÁ KHỔ VÁN 2440MM!", "✅ ĐẠT CHUẨN CNC (1220x2440mm)")'

      inst_dict = entity.attribute_dictionary('dynamic_attributes', true)
      inst_dict['canh_bao_kho_van'] = status_str
    rescue => e
      puts "[Chill AI] Lỗi sync DC warning: #{e.message}"
    end

    # Tự động co giới hạn chiều dài về 2440mm
    def self.clamp_to_standard(target_entity = nil)
      model = Sketchup.active_model
      return unless model
      target = target_entity || (model.selection.first if model.selection && model.selection.count > 0)
      return unless target && target.valid?

      bb = target.bounds
      dims = [bb.width.to_mm, bb.height.to_mm, bb.depth.to_mm]
      max_dim = dims.max

      if max_dim > MAX_STANDARD_SHEET_L
        model.start_operation("Chill AI: Thu Về Khổ Ván 2440mm", true)
        scale_ratio = MAX_STANDARD_SHEET_L / max_dim

        # Nếu là Dynamic Component có thuộc tính lenx/leny/lenz
        if target.is_a?(Sketchup::ComponentInstance) && target.definition.attribute_dictionary('dynamic_attributes')
          dict = target.definition.attribute_dictionary('dynamic_attributes')
          inst_dict = target.attribute_dictionary('dynamic_attributes')
          ['lenx', 'leny', 'lenz'].each do |attr|
            val = (dict[attr] || (inst_dict ? inst_dict[attr] : nil)).to_f
            if val * 25.4 > MAX_STANDARD_SHEET_L
              target.set_attribute('dynamic_attributes', attr, MAX_STANDARD_SHEET_L / 25.4) rescue nil
            end
          end
          $dc_observers.get_latest_class.redraw_with_undo(target) rescue nil
        end

        tr = Geom::Transformation.scaling(bb.min, scale_ratio, scale_ratio, scale_ratio)
        target.transform!(tr)
        model.commit_operation
        Sketchup.status_text = "Chill AI: Đã thu kích thước đối tượng về tối đa 2440mm!"
        handle_selection(model.selection, @dialog, force: true) if @dialog
      end
    end
  end
end
