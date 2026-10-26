# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Edge Banding Engine (Quản Lý Chỉ Dán Cạnh Chuẩn ABF)
# Chuẩn hoá 100% theo phong cách ABF & Kiến trúc Lego 4 Tầng:
#   - Quản lý danh mục 12 loại chỉ dán cạnh (Màu sắc, Độ dày, Giá tiền)
#   - Phân tích hình học tấm ván: Tự động tách 2 mặt ván & 4 mặt cạnh (2 Dài + 2 Ngắn)
#   - Hiển thị trực quan qua Draw Callback: Bấm phím SPACE là màu chỉ tự động ẩn 100%
#   - Trừ hao độ dày dán chỉ khi Nesting: Tấm ván tự động hụt đi theo các cạnh được dán
#   - Lưu trữ Attributes chuẩn ABF ('ABF_EDGE_BANDING') phục vụ Báo cáo & Nesting CNC
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module EdgeBandingEngine
    class << self
      attr_accessor :last_selected_panel
    end
    CONFIG_FILE_NAME = 'edge_banding_config.json'.freeze

    # 12 Loại chỉ dán cạnh chuẩn ABF (Chuẩn ảnh 1 & ảnh 2 của anh Huy)
    DEFAULT_PRESETS = [
      { "id" => "eb_1",  "name" => "Chỉ Cánh - 1mm",            "thickness" => 1.0,  "color" => "#a3e635", "price" => 3000, "active" => true },
      { "id" => "eb_2",  "name" => "Chỉ Đen - 1mm",             "thickness" => 1.0,  "color" => "#f1f5f9", "price" => 3000, "active" => true },
      { "id" => "eb_3",  "name" => "Vát Cánh 45 - 1mm",         "thickness" => 1.0,  "color" => "#ef4444", "price" => 5000, "active" => true },
      { "id" => "eb_4",  "name" => "Chỉ 2P - 1mm",              "thickness" => 1.0,  "color" => "#c084fc", "price" => 4000, "active" => true },
      { "id" => "eb_5",  "name" => "Không Dán - 0mm",           "thickness" => 0.0,  "color" => "#22d3ee", "price" => 0,    "active" => true },
      { "id" => "eb_6",  "name" => "Chỉ Cánh 2 - 1mm",          "thickness" => 1.0,  "color" => "#fb923c", "price" => 3000, "active" => true },
      { "id" => "eb_7",  "name" => "Chỉ 4P - 1mm",              "thickness" => 1.0,  "color" => "#34d399", "price" => 6000, "active" => true },
      { "id" => "eb_8",  "name" => "GHÉP XONG DÁN CHỈ 4P - 1mm","thickness" => 1.0,  "color" => "#fde047", "price" => 6000, "active" => true },
      { "id" => "eb_9",  "name" => "VÁT CÁNH 2 - 1mm",          "thickness" => 1.0,  "color" => "#f43f5e", "price" => 5000, "active" => true },
      { "id" => "eb_10", "name" => "GHÉP XONG DÁN CHỈ 2P - 1mm","thickness" => 1.0,  "color" => "#6ee7b7", "price" => 4000, "active" => true },
      { "id" => "eb_11", "name" => "Chỉ 2P Nhựa - 1mm",         "thickness" => 1.0,  "color" => "#d8b4fe", "price" => 4500, "active" => true },
      { "id" => "eb_12", "name" => "Chỉ 2 Phân Nhựa - 1mm",     "thickness" => 1.0,  "color" => "#3b82f6", "price" => 4500, "active" => true }
    ].freeze

    # 4 Nhóm độ dày mặc định
    DEFAULT_THICKNESSES = [
      { "thickness" => 1.0,  "label" => "1mm",    "color" => "#c084fc" },
      { "thickness" => 2.0,  "label" => "2mm",    "color" => "#3b82f6" },
      { "thickness" => 0.45, "label" => "0.45mm", "color" => "#84cc16" },
      { "thickness" => 0.8,  "label" => "0.8mm",  "color" => "#b45309" }
    ].freeze

    DICT_ABF = 'ABF_EDGE_BANDING'.freeze
    DICT_CHILL = 'CHILL_AI_EDGE_BANDING'.freeze

    @config = nil
    @active_preset_id = "eb_1" # Mặc định: Chỉ Cánh - 1mm

    # Đường dẫn file config JSON
    def self.config_path
      root = ChillAIInterior.const_defined?(:PLUGIN_ROOT) ? ChillAIInterior::PLUGIN_ROOT : File.expand_path(File.join(File.dirname(__FILE__), '..'))
      File.join(root, CONFIG_FILE_NAME)
    end

    # Nạp cấu hình từ đĩa
    def self.load_config
      path = config_path
      if File.exist?(path)
        begin
          content = File.read(path, encoding: 'UTF-8')
          data = JSON.parse(content)
          presets = data['presets'] && !data['presets'].empty? ? data['presets'] : DEFAULT_PRESETS
          thicknesses = data['thicknesses'] && !data['thicknesses'].empty? ? data['thicknesses'] : DEFAULT_THICKNESSES
          @active_preset_id = data['active_preset_id'] || "eb_1"
          @config = {
            'presets' => presets,
            'thicknesses' => thicknesses,
            'active_preset_id' => @active_preset_id
          }
        rescue => e
          puts "[Chill AI EdgeBandingEngine] Lỗi đọc config: #{e.message}. Sử dụng mặc định."
          @config = {
            'presets' => DEFAULT_PRESETS.dup,
            'thicknesses' => DEFAULT_THICKNESSES.dup,
            'active_preset_id' => "eb_1"
          }
        end
      else
        @config = {
          'presets' => DEFAULT_PRESETS.dup,
          'thicknesses' => DEFAULT_THICKNESSES.dup,
          'active_preset_id' => "eb_1"
        }
        save_config(@config)
      end
      @config
    end

    def self.get_config
      @config || load_config
    end

    def self.save_config(new_cfg)
      @config = get_config.merge(new_cfg || {})
      @active_preset_id = @config['active_preset_id'] || @active_preset_id
      begin
        File.open(config_path, 'w:UTF-8') do |f|
          f.write(JSON.pretty_generate(@config))
        end
        puts "[Chill AI EdgeBandingEngine] Đã lưu cấu hình chỉ dán cạnh thành công."
      rescue => e
        puts "[Chill AI EdgeBandingEngine] Lỗi ghi file config: #{e.message}"
      end
      @config
    end

    def self.get_active_preset
      cfg = get_config
      presets = cfg['presets'] || DEFAULT_PRESETS
      presets.find { |p| p['id'] == @active_preset_id } || presets.first
    end

    def self.set_active_preset(preset_id)
      @active_preset_id = preset_id.to_s
      get_config['active_preset_id'] = @active_preset_id
      save_config(@config)
      get_active_preset
    end

    # ==========================================================================
    # PHÂN TÍCH HÌNH HỌC TẤM VÁN: TÁCH 2 MẶT CHÍNH & 4 MẶT CẠNH BÊN
    # ==========================================================================
    def self.analyze_panel_edges(panel_entity)
      return nil unless panel_entity && panel_entity.valid?

      ents = panel_entity.is_a?(Sketchup::Group) ? panel_entity.entities : panel_entity.definition.entities
      faces = ents.grep(Sketchup::Face)
      return nil if faces.length < 6

      # Sắp xếp các Face theo diện tích giảm dần
      sorted_faces = faces.sort_by { |f| -f.area }

      # 2 Face lớn nhất là 2 mặt ván chính (Mặt Trước / Mặt Sau)
      main_faces = sorted_faces[0..1]

      # 4 Face còn lại chính là 4 mặt cạnh của tấm ván!
      edge_faces = sorted_faces[2..5]
      return nil if edge_faces.length < 4

      # Tính chiều dài cạnh dài nhất trong mỗi Face cạnh
      edge_info = edge_faces.map do |face|
        longest_edge = face.edges.max_by(&:length)
        edge_len = longest_edge ? longest_edge.length : 0.0
        {
          face: face,
          normal: face.normal,
          area: face.area,
          length: edge_len,
          center: face.bounds.center
        }
      end

      # Sắp xếp 4 mặt cạnh theo chiều dài giảm dần
      edge_info.sort_by! { |item| -item[:length] }

      # 2 mặt cạnh có chiều dài lớn hơn là L1, L2
      # 2 mặt cạnh có chiều dài nhỏ hơn là W1, W2
      l_faces = edge_info[0..1]
      w_faces = edge_info[2..3]

      l_faces.sort_by! { |item| [item[:center].x, item[:center].y, item[:center].z] }
      w_faces.sort_by! { |item| [item[:center].x, item[:center].y, item[:center].z] }

      {
        panel: panel_entity,
        main_faces: main_faces,
        edge_faces: {
          'L1' => l_faces[0][:face],
          'L2' => l_faces[1][:face],
          'W1' => w_faces[0][:face],
          'W2' => w_faces[1][:face]
        },
        edge_details: {
          'L1' => { face: l_faces[0][:face], length: l_faces[0][:length], name: 'Cạnh Dài 1' },
          'L2' => { face: l_faces[1][:face], length: l_faces[1][:length], name: 'Cạnh Dài 2' },
          'W1' => { face: w_faces[0][:face], length: w_faces[0][:length], name: 'Cạnh Ngắn 1' },
          'W2' => { face: w_faces[1][:face], length: w_faces[1][:length], name: 'Cạnh Ngắn 2' }
        }
      }
    rescue => e
      puts "[Chill AI EdgeBandingEngine analyze_panel_edges Error]: #{e.message}"
      nil
    end

    # ==========================================================================
    # ÁP DỤNG DÁN CHỈ CẠNH (LƯU THUỘC TÍNH CHUẨN ABF & TỰ ĐỘNG ẨN KHI BẤM SPACE)
    # ==========================================================================
    def self.apply_edge_banding(panel_entity, edge_key, preset = nil)
      return false unless panel_entity && panel_entity.valid?

      preset ||= get_active_preset
      return false unless preset

      geom = analyze_panel_edges(panel_entity)
      return false unless geom

      model = Sketchup.active_model
      model.start_operation("Chill AI - Dán Chỉ Cạnh", true)

      if panel_entity.is_a?(Sketchup::ComponentInstance) && panel_entity.definition.count_instances > 1
        panel_entity.make_unique
        geom = analyze_panel_edges(panel_entity)
      end

      keys_to_apply = (edge_key == 'ALL' || edge_key == :all) ? ['L1', 'L2', 'W1', 'W2'] : [edge_key.to_s]

      keys_to_apply.each do |k|
        face = geom[:edge_faces][k]
        if face && face.valid?
          # Gỡ bỏ Material EB_ cũ nếu có để giữ mô hình mộc sạch sẽ
          face.material = nil if face.material && face.material.name =~ /^EB_/i
          save_edge_attribute(panel_entity, k, preset)
        end
      end

      update_panel_edge_summary(panel_entity)

      model.commit_operation
      true
    rescue => e
      puts "[Chill AI EdgeBandingEngine apply_edge_banding Error]: #{e.message}"
      false
    end

    # ==========================================================================
    # XÓA DÁN CHỈ CẠNH
    # ==========================================================================
    def self.remove_edge_banding(panel_entity, edge_key = 'ALL')
      return false unless panel_entity && panel_entity.valid?

      geom = analyze_panel_edges(panel_entity)
      return false unless geom

      model = Sketchup.active_model
      model.start_operation("Chill AI - Xóa Dán Chỉ Cạnh", true)

      if panel_entity.is_a?(Sketchup::ComponentInstance) && panel_entity.definition.count_instances > 1
        panel_entity.make_unique
        geom = analyze_panel_edges(panel_entity)
      end

      keys_to_clear = (edge_key == 'ALL' || edge_key == :all) ? ['L1', 'L2', 'W1', 'W2'] : [edge_key.to_s]

      keys_to_clear.each do |k|
        face = geom[:edge_faces][k]
        if face && face.valid?
          face.material = nil if face.material && face.material.name =~ /^EB_/i
          remove_edge_attribute(panel_entity, k)
        end
      end

      update_panel_edge_summary(panel_entity)

      model.commit_operation
      true
    rescue => e
      puts "[Chill AI EdgeBandingEngine remove_edge_banding Error]: #{e.message}"
      false
    end

    def self.save_edge_attribute(panel_entity, edge_key, preset)
      dict_data = {
        'id' => preset['id'],
        'name' => preset['name'],
        'thickness' => preset['thickness'].to_f,
        'color' => preset['color'],
        'price' => preset['price'].to_f
      }
      json_str = JSON.generate(dict_data)

      [DICT_ABF, DICT_CHILL].each do |dict|
        panel_entity.set_attribute(dict, edge_key, json_str)
        if panel_entity.respond_to?(:definition)
          panel_entity.definition.set_attribute(dict, edge_key, json_str) rescue nil
        end
      end
    end

    def self.remove_edge_attribute(panel_entity, edge_key)
      [DICT_ABF, DICT_CHILL].each do |dict|
        panel_entity.delete_attribute(dict, edge_key) rescue nil
        if panel_entity.respond_to?(:definition)
          panel_entity.definition.delete_attribute(dict, edge_key) rescue nil
        end
      end
    end

    # Đọc thông tin dán cạnh hiện tại của tấm ván
    def self.get_panel_edge_bandings(panel_entity)
      return {} unless panel_entity && panel_entity.valid?

      res = {}
      ['L1', 'L2', 'W1', 'W2'].each do |k|
        val = panel_entity.get_attribute(DICT_ABF, k) || panel_entity.get_attribute(DICT_CHILL, k)
        if val.nil? && panel_entity.respond_to?(:definition)
          val = panel_entity.definition.get_attribute(DICT_ABF, k) || panel_entity.definition.get_attribute(DICT_CHILL, k)
        end

        if val
          begin
            res[k] = JSON.parse(val)
          rescue
            res[k] = { 'name' => val.to_s, 'thickness' => 1.0, 'color' => '#a3e635' }
          end
        else
          res[k] = nil
        end
      end
      res
    end

    # ==========================================================================
    # TÍNH TOÁN LƯỢNG HỤT ĐỘ DÀY DÁN CHỈ (EDGE BANDING OFFSET / DEDUCTION)
    # Dùng cho Nesting, cắt phôi CNC, xuất file DXF và trải phẳng trên SketchUp
    # ==========================================================================
    def self.calculate_edge_deductions(panel_entity)
      bands = get_panel_edge_bandings(panel_entity)
      
      # Cạnh Dài L1, L2 chạy dọc chiều dài L -> Dán vào làm tăng chiều Rộng W
      # -> Cắt phôi CNC chiều rộng W phải hụt đi đúng tổng độ dày nẹp dán!
      deduct_w = 0.0
      deduct_w += bands['L1']['thickness'].to_f if bands['L1'] && bands['L1']['thickness']
      deduct_w += bands['L2']['thickness'].to_f if bands['L2'] && bands['L2']['thickness']

      # Cạnh Ngắn W1, W2 chạy dọc chiều rộng W -> Dán vào làm tăng chiều Dài L
      # -> Cắt phôi CNC chiều dài L phải hụt đi đúng tổng độ dày nẹp dán!
      deduct_l = 0.0
      deduct_l += bands['W1']['thickness'].to_f if bands['W1'] && bands['W1']['thickness']
      deduct_l += bands['W2']['thickness'].to_f if bands['W2'] && bands['W2']['thickness']

      {
        deduct_l: deduct_l.round(2),
        deduct_w: deduct_w.round(2),
        bands: bands
      }
    end

    # Cập nhật chuỗi tóm tắt dán cạnh (dùng cho Bảng Thống Kê & Cắt CNC)
    def self.update_panel_edge_summary(panel_entity)
      bands = get_panel_edge_bandings(panel_entity)
      applied_count = bands.values.compact.length

      summary_str = if applied_count == 0
                      "Không dán"
                    elsif applied_count == 4
                      first_name = bands['L1'] ? bands['L1']['name'] : "1mm"
                      "4 cạnh (#{first_name})"
                    else
                      parts = []
                      parts << "L1" if bands['L1']
                      parts << "L2" if bands['L2']
                      parts << "W1" if bands['W1']
                      parts << "W2" if bands['W2']
                      "#{applied_count} cạnh (#{parts.join('+')})"
                    end

      panel_entity.set_attribute(DICT_ABF, 'edge_band_summary', summary_str)
      panel_entity.set_attribute(DICT_CHILL, 'edge_banding', summary_str)
      summary_str
    end

    # Dọn sạch các Material EB_ cũ trên mô hình
    def self.clean_legacy_eb_materials
      model = Sketchup.active_model
      return unless model
      mats_to_remove = []
      model.materials.each do |m|
        mats_to_remove << m if m.name =~ /^EB_/i
      end
      mats_to_remove.each { |m| model.materials.remove(m) rescue nil }
    end
  end
end
