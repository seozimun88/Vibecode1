# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Selection Observer (Đấu Nối 2 Chiều Chuẩn Xác Giữa SU & Plugin)
# ==============================================================================

require 'sketchup.rb'
require 'json'

# Tự động nạp lại main.rb và áp dụng kích thước mặc định 385x870 (Chuẩn ảnh khoanh đỏ anh Huy)
begin
  main_path = File.join(File.dirname(__FILE__), 'main.rb')
  load main_path if File.exist?(main_path)
  if defined?(ChillAIInterior) && ChillAIInterior.dialog
    ChillAIInterior.dialog.set_size(320, 515)
    ChillAIInterior.dialog.set_position(1208, 58)
  end
rescue => e
end

module ChillAIInterior
  module SelectionManager
    @observer = nil
    @dialog = nil
    @app_observer = nil
    @has_clamped_dock = false

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

    def self.attach(dialog)
      return unless dialog
      @dialog = dialog

      model = Sketchup.active_model
      return unless model

      detach

      @observer = InternalSelectionObserver.new(@dialog)
      model.selection.add_observer(@observer)

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
      if @observer && model
        begin
          model.selection.remove_observer(@observer)
        rescue => e
        end
        begin
          model.selection.add_observer(@observer)
        rescue => e
        end
      end
    end

    def self.detach
      if @observer && Sketchup.active_model
        begin
          Sketchup.active_model.selection.remove_observer(@observer)
        rescue => e
        end
      end
      @observer = nil
    end

    def self.handle_cleared(dialog)
      return unless dialog
      payload = {
        'has_selection' => false,
        'message' => 'Không có đối tượng nào đang được chọn.'
      }
      send_to_js(dialog, payload)
    end

    def self.handle_selection(selection, dialog)
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
        target = found_parent if found_parent
      end

      return handle_cleared(dialog) unless target.is_a?(Sketchup::Drawingelement)

      begin
        data = analyze_entity(target)
        return handle_cleared(dialog) unless data

        payload = {
          'has_selection' => true,
          'data' => data
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

      tier = 3
      tier_label = "Tầng 3: Miếng Ván Nhỏ (Part / Panel)"
      category = "Tấm Ván Sản Xuất"
      icon_type = "panel"

      # Nhận diện đặc tính hình học thông minh
      is_table_top = raw_name.downcase.include?('mặt bàn') || raw_name.downcase.include?('table top') || (thickness <= 45 && length_board >= 500 && width_board >= 300)
      is_metal_leg = raw_name.downcase.include?('chân') || raw_name.downcase.include?('sat') || material_name.downcase.include?('metal') || material_name.downcase.include?('sắt')
      is_drawer_box = raw_name.downcase.include?('hộc') || raw_name.downcase.include?('ngăn kéo') || raw_name.downcase.include?('drawer')

      if custom_tier
        tier = custom_tier.to_i
        tier_label = custom_label || "Tầng #{tier}"
        category = custom_cat || "Chi Tiết Nội Thất"
        icon_type = custom_icon || "panel"
      else
        has_sub_groups = entity.respond_to?(:entities) && entity.entities.any? { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        sub_group_count = entity.respond_to?(:entities) ? entity.entities.count { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) } : 0

        if has_sub_groups && (sub_group_count >= 2 || raw_name.downcase.include?('chill_ai') || raw_name.downcase.include?('tổng') || raw_name.downcase.include?('bàn') || raw_name.downcase.include?('tủ'))
          tier = 1
          tier_label = "Tầng 1: Khối Tổng (Composite Assembly)"
          category = "Tổ Hợp Khối Tổng"
          icon_type = "assembly"
        elsif is_table_top
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Mặt Bàn Gỗ Sồi)"
          category = "Chi Tiết Mặt Bàn Chịu Lực"
          icon_type = "panel"
          raw_name = "Mặt Bàn Gỗ Tự Nhiên Sồi Nga" if raw_name == "Đối tượng 3D" || raw_name == "Panel"
        elsif is_metal_leg
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Khung Chân Sắt U)"
          category = "Kết Cấu Chịu Lực"
          icon_type = "module"
          raw_name = "Khung Chân Sắt Hộp 40x40 Sơn Tĩnh Điện" if raw_name == "Đối tượng 3D"
        elsif is_drawer_box || has_sub_groups
          tier = 2
          tier_label = "Tầng 2: Khối Lẻ (Hộc Ngăn Kéo)"
          category = "Module Lưu Trữ"
          icon_type = "module"
          raw_name = "Hộc Tủ Ngăn Kéo Di Động" if raw_name == "Đối tượng 3D"
        else
          tier = 3
          if thickness <= 25 && (raw_name.downcase.include?('tay') || raw_name.downcase.include?('ban le') || length_board < 150)
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
      case tier
      when 1
        breadcrumb = [raw_name]
      when 2
        root_name = "Khối Tổng Bàn Làm Việc"
        breadcrumb = [root_name, raw_name]
      when 3
        root_name = "Khối Tổng Bàn Làm Việc"
        module_name = "Khối Module Lẻ"
        breadcrumb = [root_name, module_name, raw_name]
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

      {
        'entity_id' => entity.entityID,
        'name' => raw_name,
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
        'is_cnc_ready' => (thickness >= 9 && thickness <= 36)
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
  end
end
