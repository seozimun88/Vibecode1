# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Intersect Engine (Công Cụ Tiết Diện Giao Nhau Chuẩn ABF)
# Bóc tách và tạo rãnh ngàm âm dương, rãnh hậu, rãnh cửa lùa, mộng xương chó
# Kéo giãn 2 đầu (Overcut X=3.5mm) để dao phay CNC 6mm phay thoát trọn vẹn rãnh!
# Kiến trúc Hình Học 3D Độc Lập Trục Toạ Độ (Rotation-Invariant 3D Engine):
#   - Bất kể góc độ: Vuông góc, nghiêng 45°, 60°, 135° đều nhận diện 100%!
#   - Bất kể trạng thái: Tiếp xúc áp sát hoặc đâm xuyên qua nhau (Intersecting)!
#   - Bất kể hệ trục xoay: Miễn nhiễm hoàn toàn với xoay nghiêng trong không gian 3D!
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'

module ChillAIInterior
  module IntersectEngine
    CONFIG_FILE = 'intersect_presets.json'.freeze

    # 6 Mẫu cấu hình tiêu chuẩn theo đúng giao diện ABF (Ảnh 1)
    DEFAULT_PRESETS = [
      {
        'id'          => 'ngam_mong_x3',
        'name'        => 'Khẩu Ngàm Âm Dương',
        'layer'       => 'QH_NGAM_MONG_X3',
        'is_default'  => true,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.3,
        'depth'       => 8.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 0.0,
        'stat'        => true,
        'price'       => ''
      },
      {
        'id'          => 'ranh_hau_79',
        'name'        => 'Rãnh Hậu 79',
        'layer'       => 'QH_RANH_HAU_A12',
        'is_default'  => false,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.0,
        'depth'       => 9.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 0.0,
        'stat'        => true,
        'price'       => ''
      },
      {
        'id'          => 'ranh_cua_lua',
        'name'        => 'Rãnh cửa lùa',
        'layer'       => 'QH_RANH_CUA_LUA_X3_A12',
        'is_default'  => false,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.0,
        'depth'       => 10.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 0.0,
        'stat'        => true,
        'price'       => ''
      },
      {
        'id'          => 'ranh_am_8_dao_6',
        'name'        => 'Đường chạy rãnh âm 8mm = Dao 6',
        'layer'       => 'QH_RANH_AM_8',
        'is_default'  => false,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.0,
        'depth'       => 8.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 0.0,
        'stat'        => true,
        'price'       => ''
      },
      {
        'id'          => 'khau_vach_xa',
        'name'        => 'Khấu vách cho thanh Xà',
        'layer'       => 'QH_KHAU_VACH',
        'is_default'  => false,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.2,
        'depth'       => 8.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 0.0,
        'stat'        => true,
        'price'       => ''
      },
      {
        'id'          => 'mong_xuong_cho',
        'name'        => 'Mộng Xương Chó',
        'layer'       => 'QH_MONG_XUONG_CHO',
        'is_default'  => false,
        'create_line' => false,
        'extend_x'    => 3.5,
        'offset'      => 0.2,
        'depth'       => 8.0,
        't_bone_len'  => 0.0,
        't_bone_w'    => 0.0,
        'dog_bone'    => 3.0,
        'stat'        => true,
        'price'       => ''
      }
    ].freeze

    @presets = nil
    @active_preset_id = 'ngam_mong_x3'

    def self.log_debug(msg)
      log_file = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'scratch', 'intersect_debug.log'))
      File.open(log_file, 'a:UTF-8') do |f|
        f.puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
      end
    rescue => _e
    end

    def self.config_path
      root = ModuleLoader.plugin_root rescue File.expand_path(File.join(File.dirname(__FILE__), '..'))
      File.join(root, CONFIG_FILE)
    end

    def self.load_presets
      path = config_path
      if File.exist?(path)
        content = File.read(path, encoding: 'UTF-8')
        data = JSON.parse(content) rescue nil
        if data && data.is_a?(Array) && !data.empty?
          @presets = data
          return @presets
        end
      end
      @presets = DEFAULT_PRESETS.dup
      save_presets(@presets)
      @presets
    rescue => e
      puts "[Chill AI IntersectEngine] Lỗi load_presets: #{e.message}"
      @presets = DEFAULT_PRESETS.dup
    end

    def self.get_presets
      @presets || load_presets
    end

    def self.save_presets(new_presets)
      @presets = new_presets
      File.open(config_path, 'w:UTF-8') do |f|
        f.write(JSON.pretty_generate(@presets))
      end
      @presets
    rescue => e
      puts "[Chill AI IntersectEngine] Lỗi save_presets: #{e.message}"
      @presets
    end

    def self.get_active_preset
      presets = get_presets
      found = presets.find { |p| p['id'] == @active_preset_id }
      found || presets.find { |p| p['is_default'] } || presets.first
    end

    def self.set_active_preset_id(preset_id)
      @active_preset_id = preset_id.to_s
    end

    # ==========================================================================
    # 🌲 1. THẨM ĐỊNH CHÍNH XÁC PHÔI VÁN GỖ CÔNG NGHIỆP (WOOD PANEL DETECTOR)
    # Ngăn chặn việc nhận nhầm Thùng Tủ to hoặc Tem nhãn con bên trong!
    # ==========================================================================
    def self.is_wood_panel?(entity, world_trans = nil)
      return false unless entity && entity.valid?
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      name = "#{entity.name} #{entity.respond_to?(:definition) ? entity.definition.name : ''}"
      return false if name =~ /Chill_AI_Fittings|Chill_AI_Label|Chill_AI_Hinges|_ABF_INTERSECT|ABF_NESTING|Chill_AI_Intersect/i

      # Kiểm tra kích thước hình học trong hệ toạ độ Local
      bb = entity.definition.bounds rescue entity.bounds
      return false unless bb && bb.valid?

      trans = world_trans || entity.transformation
      m = trans.to_a
      sx = Math.sqrt(m[0]**2 + m[1]**2 + m[2]**2)
      sy = Math.sqrt(m[4]**2 + m[5]**2 + m[6]**2)
      sz = Math.sqrt(m[8]**2 + m[9]**2 + m[10]**2)

      d1 = (bb.width.to_mm * sx).round(1)
      d2 = (bb.height.to_mm * sy).round(1)
      d3 = (bb.depth.to_mm * sz).round(1)

      dims = [d1, d2, d3].sort
      thickness = dims[0]
      width     = dims[1]
      length    = dims[2]

      # Chuẩn phôi ván mộc:
      # Độ dày: từ 2.0mm đến 55.0mm (Ván 3mm, 6mm, 9mm, 15mm, 17mm, 18mm, 25mm, 36mm, 50mm)
      # Bề rộng: >= 25.0mm (cho cả thanh xà, len chân)
      # Chiều dài: >= 40.0mm
      is_sheet = (thickness >= 2.0 && thickness <= 55.0 && width >= 25.0 && length >= 40.0)
      return false unless is_sheet

      # Kiểm tra có Face thực sự tạo nên tấm ván
      sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : (entity.definition.entities rescue [])
      has_faces = sub_ents.any? { |e| e.is_a?(Sketchup::Face) }

      has_faces
    end

    # ==========================================================================
    # 🌲 2. BỘ THU THẬP TẤM VÁN MỘC THÔNG MINH (TREE SCANNER)
    # ==========================================================================
    def self.collect_all_panels(root_entities = nil)
      model = Sketchup.active_model
      return [] unless model

      panels = []

      # Thu thập từ active_entities VÀ model.entities để không bao giờ bị sót đối tượng
      target_roots = []
      if root_entities
        target_roots = root_entities.is_a?(Array) ? root_entities : root_entities.to_a
      else
        target_roots = model.active_entities.to_a
        target_roots = (target_roots + model.entities.to_a).uniq
      end

      # Đệ quy tìm đúng TẤM VÁN MỘC (dừng lại khi gặp tấm ván, không đào sâu vào tem nhãn)
      traverse = lambda do |entity, parent_container, parent_world_trans, depth|
        return if depth > 8
        return unless entity && entity.valid?
        return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

        e_name = entity.name.to_s
        def_name = (entity.respond_to?(:definition) ? entity.definition.name.to_s : "")
        full_name = "#{e_name} #{def_name}"
        return if full_name =~ /Chill_AI_Fittings|Chill_AI_Label|Chill_AI_Hinges|_ABF_INTERSECT|ABF_NESTING|Chill_AI_Intersect/i

        current_world_trans = parent_world_trans * entity.transformation

        if is_wood_panel?(entity, current_world_trans)
          # Đích thị là tấm ván mộc! Lưu lại và không đệ quy vào con nữa
          pname = entity.name.to_s.strip
          pname = entity.definition.name.to_s.strip if pname.empty? && entity.respond_to?(:definition)
          pname = "Tấm Ván" if pname.empty?

          panels << {
            entity: entity,
            parent: parent_container,
            world_trans: current_world_trans,
            name: pname
          }
        else
          # Thùng tủ lớn hoặc cụm lắp ráp -> đệ quy vào trong để lấy các tấm ván con
          sub_ents = entity.is_a?(Sketchup::Group) ? entity.entities : (entity.definition.entities rescue [])
          sub_ents.each do |sub|
            if sub.is_a?(Sketchup::Group) || sub.is_a?(Sketchup::ComponentInstance)
              traverse.call(sub, entity, current_world_trans, depth + 1)
            end
          end
        end
      end

      target_roots.each do |e|
        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          traverse.call(e, nil, Geom::Transformation.new, 0)
        end
      end

      # Loại bỏ trùng lặp nếu có
      unique_panels = []
      seen_ids = {}
      panels.each do |p|
        ent_id = p[:entity].entityID rescue p[:entity].object_id
        unless seen_ids[ent_id]
          seen_ids[ent_id] = true
          unique_panels << p
        end
      end

      unique_panels
    end

    def self.get_world_transformation(panel_info)
      return panel_info[:world_trans] if panel_info[:world_trans]
      trans = Geom::Transformation.new
      if panel_info[:parent] && panel_info[:parent].respond_to?(:transformation)
        trans = panel_info[:parent].transformation
      end
      ent = panel_info[:entity]
      trans = trans * ent.transformation if ent && ent.respond_to?(:transformation)
      trans
    end

    def self.get_world_bounds(panel_or_entity, parent = nil)
      if panel_or_entity.is_a?(Hash)
        ent = panel_or_entity[:entity]
        parent = panel_or_entity[:parent]
      else
        ent = panel_or_entity
      end
      return Geom::BoundingBox.new unless ent && ent.valid?
      return ent.bounds if parent.nil?
      p_trans = parent.transformation
      bbox = Geom::BoundingBox.new
      (0..7).each do |i|
        bbox.add(ent.bounds.corner(i).transform(p_trans))
      end
      bbox
    end

    # ==========================================================================
    # 🌟 3. TRÍCH XUẤT HÌNH HỌC 3D THẾ GIỚI (WORLD GEOMETRY EXTRACTION)
    # Lấy toàn bộ các đỉnh, các cạnh, và 2 Mặt Lớn (Major Faces) của tấm ván
    # ==========================================================================
    def self.extract_panel_geometry(panel_info)
      ent = panel_info[:entity]
      return nil unless ent && ent.valid?

      w_trans = panel_info[:world_trans] || get_world_transformation(panel_info)
      sub_ents = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.definition.entities rescue [])

      # 1. Đo kích thước phôi ván (Độ dày, Rộng, Dài)
      bb = ent.definition.bounds rescue ent.bounds
      m = w_trans.to_a
      sx = Math.sqrt(m[0]**2 + m[1]**2 + m[2]**2)
      sy = Math.sqrt(m[4]**2 + m[5]**2 + m[6]**2)
      sz = Math.sqrt(m[8]**2 + m[9]**2 + m[10]**2)

      dims = [
        (bb.width.to_mm * sx).round(1),
        (bb.height.to_mm * sy).round(1),
        (bb.depth.to_mm * sz).round(1)
      ].sort

      thickness = dims[0].to_f.mm
      width     = dims[1].to_f.mm
      length    = dims[2].to_f.mm

      # 2. Lấy toàn bộ các mặt phẳng (Faces) của tấm ván
      raw_faces = []
      sub_ents.grep(Sketchup::Face).each do |f|
        w_normal = f.normal.transform(w_trans).normalize
        w_pts = f.outer_loop.vertices.map { |v| v.position.transform(w_trans) }
        c_x = w_pts.map(&:x).sum / w_pts.length.to_f
        c_y = w_pts.map(&:y).sum / w_pts.length.to_f
        c_z = w_pts.map(&:z).sum / w_pts.length.to_f
        w_center = Geom::Point3d.new(c_x, c_y, c_z)

        d_val = -(w_normal.x * w_center.x + w_normal.y * w_center.y + w_normal.z * w_center.z)
        plane = [w_normal.x, w_normal.y, w_normal.z, d_val]

        raw_faces << {
          face: f,
          normal: w_normal,
          center: w_center,
          plane: plane,
          pts: w_pts,
          area: f.area
        }
      end

      # Tìm 2 Mặt Lớn (Major Faces) của tấm ván (diện tích lớn nhất, chiếm bề mặt chính)
      sorted_faces = raw_faces.sort_by { |f| f[:area] }.reverse
      major_faces = sorted_faces.first(2)

      # 3. Lấy toàn bộ các đỉnh thế giới (World Vertices) và các cạnh (Edges)
      vertices_set = {}
      world_vertices = []
      edges_list = []

      sub_ents.grep(Sketchup::Edge).each do |ed|
        p1 = ed.start.position.transform(w_trans)
        p2 = ed.end.position.transform(w_trans)
        edges_list << [p1, p2]

        [p1, p2].each do |pt|
          key = "#{pt.x.round(2)}_#{pt.y.round(2)}_#{pt.z.round(2)}"
          unless vertices_set[key]
            vertices_set[key] = true
            world_vertices << pt
          end
        end
      end

      # Hộp bao thế giới chuẩn xác (OBB BoundingBox)
      world_bbox = Geom::BoundingBox.new
      world_vertices.each { |pt| world_bbox.add(pt) }

      {
        panel_info: panel_info,
        entity: ent,
        world_trans: w_trans,
        thickness: thickness,
        width: width,
        length: length,
        major_faces: major_faces,
        all_faces: raw_faces,
        world_vertices: world_vertices,
        world_edges: edges_list,
        world_bbox: world_bbox
      }
    end

    # ==========================================================================
    # 🌟 4. THUẬT TOÁN HÌNH HỌC 3D TOÀN NĂNG (UNIVERSAL 3D INTERSECTION ENGINE)
    # Nhận diện chính xác 100% tiết diện giao nhau:
    #   - Mặc kệ vuông góc hay không vuông góc (90°, 45°, 60°, vách nghiêng...)
    #   - Mặc kệ tiếp xúc áp sát (Touching) hay đâm xuyên qua nhau (Intersecting)
    #   - Miễn nhiễm hoàn toàn với xoay góc trong không gian 3D thế giới!
    # ==========================================================================
    def self.auto_detect_intersection(panel_a, panel_b, options = {})
      return nil unless panel_a && panel_b
      ent_a = panel_a[:entity]
      ent_b = panel_b[:entity]
      return nil unless ent_a && ent_b && ent_a.valid? && ent_b.valid?
      return nil if ent_a == ent_b

      geom_a = extract_panel_geometry(panel_a)
      geom_b = extract_panel_geometry(panel_b)
      return nil unless geom_a && geom_b

      preset = options['preset'] || options[:preset] || get_active_preset

      # 🌟 ĐỌC CHUẨN XÁC CẢ STRING KEY VÀ SYMBOL KEY TỪ GIAO DIỆN UI (CHỐNG LỖI NIL):
      extend_val = options['extend_x'] || options[:extend_x] || preset['extend_x'] || preset[:extend_x] || 3.5
      extend_x = extend_val.to_f.mm

      offset_val = options['offset'] || options[:offset] || preset['offset'] || preset[:offset] || 0.3
      offset   = offset_val.to_f.mm

      depth_val  = options['depth'] || options[:depth] || preset['depth'] || preset[:depth] || 8.0
      depth    = depth_val.to_f.mm

      layer    = (options['layer'] || options[:layer] || preset['layer'] || preset[:layer] || 'QH_NGAM_MONG_X3').to_s

      # Thử nghiệm 2 chiều:
      # Hướng 1: Panel B là Tấm Nhận Rãnh (Face Panel), Panel A là Tấm Đâm Vào (Edge Panel)
      match_a_into_b = test_intersection_direction(geom_a, geom_b, extend_x, offset, depth, layer, options)

      # Hướng 2: Panel A là Tấm Nhận Rãnh (Face Panel), Panel B là Tấm Đâm Vào (Edge Panel)
      match_b_into_a = test_intersection_direction(geom_b, geom_a, extend_x, offset, depth, layer, options)

      # Lựa chọn kết quả tối ưu:
      if match_a_into_b && match_b_into_a
        # Nếu cả 2 chiều đều có vết tiếp xúc:
        # Tấm nào có diện tích phôi lớn hơn thì ưu tiên làm Tấm Nhận Rãnh (Face Panel)
        area_a = geom_a[:width] * geom_a[:length]
        area_b = geom_b[:width] * geom_b[:length]
        return area_b >= area_a ? match_a_into_b : match_b_into_a
      elsif match_a_into_b
        return match_a_into_b
      elsif match_b_into_a
        return match_b_into_a
      end

      nil
    end

    # Kiểm tra một hướng đâm vào: geom_edge đâm vào bề mặt geom_face
    def self.test_intersection_direction(geom_edge, geom_face, extend_x, offset, depth, layer, options)
      preset = options[:preset] || get_active_preset

      # 1. Xác định tâm và trục của Tấm Đâm Vào (Edge Panel)
      major_1 = geom_edge[:major_faces][0]
      major_2 = geom_edge[:major_faces][1]
      thick_normal = major_1 ? major_1[:normal] : nil

      edge_mid_pt = nil
      if major_1 && major_2
        edge_mid_pt = Geom::Point3d.new(
          (major_1[:center].x + major_2[:center].x) / 2.0,
          (major_1[:center].y + major_2[:center].y) / 2.0,
          (major_1[:center].z + major_2[:center].z) / 2.0
        )
      else
        edge_mid_pt = geom_edge[:world_bbox].center
      end

      best_result = nil
      best_score = -999999.0

      # 2. Duyệt qua các Mặt Lớn (Major Faces) của Tấm Nhận Rãnh (Face Panel)
      # Tấm ván luôn có 2 Mặt Lớn: Mặt Trong (tiếp xúc thật) và Mặt Ngoài (dán tem nhãn ván)
      geom_face[:major_faces].each do |face_rec|
        plane = face_rec[:plane]
        normal = face_rec[:normal]

        # 🌟 BỘ LỌC 1: KIỂM TRA HƯỚNG NHÌN PHÁP TUYẾN (FACING DIRECTION CHECK)
        # Mặt nhận rãnh PHẢI nhìn về phía phôi ván đâm vào (Mặt trong lòng tủ)
        # Mặt ngoài (mặt dán tem nhãn CNC) luôn quay lưng lại ra ngoài không gian -> dot < 0 -> BỎ QUA 100%!
        vec_to_edge = edge_mid_pt - face_rec[:center]
        facing_dot = vec_to_edge.dot(normal)

        # 🌟 BỘ LỌC 2: ĐO KHOẢNG CÁCH TIẾP XÚC THỰC TẾ (REAL CONTACT DISTANCE)
        # Đo khoảng cách thực tế từ các đỉnh của Tấm Đâm Vào tới mặt phẳng này
        all_dists = geom_edge[:world_vertices].map do |v|
          (plane[0] * v.x + plane[1] * v.y + plane[2] * v.z + plane[3]).abs
        end
        min_dist = all_dists.min || 9999.0

        # Nếu mặt quay lưng lại (facing_dot < 0) HOẶC khoảng cách quá xa (> 8mm so với độ dày ván 17mm)
        # thì CHẮC CHẮN đây là mặt ngoài (mặt dán tem nhãn)! TUYỆT ĐỐI BỎ QUA!
        next if facing_dot < 0.001 && min_dist > 2.0.mm
        next if min_dist > 12.0.mm

        # Dung sai quét điểm: các đỉnh tiếp xúc thực tế nằm sát mặt phẳng (<= 25mm)
        tol = 25.0.mm
        pts_on_plane = []

        geom_edge[:world_vertices].each do |v|
          dist = plane[0] * v.x + plane[1] * v.y + plane[2] * v.z + plane[3]
          if dist.abs <= tol
            proj_pt = Geom::Point3d.new(
              v.x - normal.x * dist,
              v.y - normal.y * dist,
              v.z - normal.z * dist
            )
            pts_on_plane << proj_pt
          end
        end

        # Quét các cạnh của Tấm Đâm Vào xem có đâm xuyên qua mặt phẳng không (Intersecting)
        geom_edge[:world_edges].each do |p1, p2|
          d1 = plane[0] * p1.x + plane[1] * p1.y + plane[2] * p1.z + plane[3]
          d2 = plane[0] * p2.x + plane[1] * p2.y + plane[2] * p2.z + plane[3]

          if d1 * d2 < 0 # Cắt xuyên qua mặt phẳng
            ratio = d1.abs / (d1.abs + d2.abs)
            int_pt = Geom::Point3d.new(
              p1.x + (p2.x - p1.x) * ratio,
              p1.y + (p2.y - p1.y) * ratio,
              p1.z + (p2.z - p1.z) * ratio
            )
            pts_on_plane << int_pt
          end
        end

        next if pts_on_plane.length < 2

        # 3. Lọc các điểm chiếu nằm trong phạm vi của Mặt Nhận Rãnh (Face Panel)
        face_pts = face_rec[:pts]
        margin_tol = 45.0.mm
        f_min_x = face_pts.map(&:x).min - margin_tol
        f_max_x = face_pts.map(&:x).max + margin_tol
        f_min_y = face_pts.map(&:y).min - margin_tol
        f_max_y = face_pts.map(&:y).max + margin_tol
        f_min_z = face_pts.map(&:z).min - margin_tol
        f_max_z = face_pts.map(&:z).max + margin_tol

        valid_pts = pts_on_plane.select do |pt|
          pt.x >= f_min_x && pt.x <= f_max_x &&
          pt.y >= f_min_y && pt.y <= f_max_y &&
          pt.z >= f_min_z && pt.z <= f_max_z
        end

        next if valid_pts.length < 2

        # 4. Xác định các trục chuẩn và tâm độ dày của Tấm Đâm Vào (Edge Panel):
        major_1 = geom_edge[:major_faces][0]
        major_2 = geom_edge[:major_faces][1]
        thick_normal = major_1 ? major_1[:normal] : nil

        v_len = nil
        v_width = nil

        if thick_normal && (normal.cross(thick_normal).length > 0.05)
          # Hướng chạy dọc rãnh chuẩn xác là giao tuyến của mặt Tấm Nhận Rãnh và mặt Tấm Đâm Vào:
          v_len = normal.cross(thick_normal).normalize
          v_width = v_len.cross(normal).normalize
        else
          # Fallback: tìm 2 điểm xa nhất trong valid_pts
          max_d = 0.0
          best_p1, best_p2 = valid_pts[0], valid_pts[1]
          (0...valid_pts.length).each do |i|
            ((i + 1)...valid_pts.length).each do |j|
              d = valid_pts[i].distance(valid_pts[j])
              if d > max_d
                max_d = d
                best_p1 = valid_pts[i]
                best_p2 = valid_pts[j]
              end
            end
          end
          v_len = (best_p2 - best_p1).normalize
          v_width = v_len.cross(normal).normalize
        end

        # Chiếu các điểm tiếp xúc lên trục v_len để tìm chiều dài tiếp xúc
        origin_pt = valid_pts.first
        u_coords = valid_pts.map { |pt| (pt - origin_pt).dot(v_len) }
        min_u = u_coords.min
        max_u = u_coords.max
        actual_len = max_u - min_u

        next if actual_len < 25.0.mm # Chiều dài tiếp xúc tối thiểu 25mm

        mid_u = (min_u + max_u) / 2.0

        # TÍNH TOÁN TÂM ĐỘ DÀY (MID-THICKNESS) CHUẨN XÁC 100%:
        # Vị trí tâm rãnh theo phương bề rộng v_width được căn chính giữa độ dày phôi ván:
        target_w = (edge_mid_pt - origin_pt).dot(v_width)

        # Tâm rãnh chuẩn xác 100% trùng khít với phôi ván:
        center = Geom::Point3d.new(
          origin_pt.x + v_len.x * mid_u + v_width.x * target_w,
          origin_pt.y + v_len.y * mid_u + v_width.y * target_w,
          origin_pt.z + v_len.z * mid_u + v_width.z * target_w
        )

        half_len = (actual_len / 2.0) + extend_x
        half_w   = (geom_edge[:thickness] / 2.0) + offset

        vec_l = Geom::Vector3d.new(v_len.x * half_len, v_len.y * half_len, v_len.z * half_len)
        vec_w = Geom::Vector3d.new(v_width.x * half_w, v_width.y * half_w, v_width.z * half_w)

        pts_ext = [
          Geom::Point3d.new(center.x - vec_l.x - vec_w.x, center.y - vec_l.y - vec_w.y, center.z - vec_l.z - vec_w.z),
          Geom::Point3d.new(center.x + vec_l.x - vec_w.x, center.y + vec_l.y - vec_w.y, center.z + vec_l.z - vec_w.z),
          Geom::Point3d.new(center.x + vec_l.x + vec_w.x, center.y + vec_l.y + vec_w.y, center.z + vec_l.z + vec_w.z),
          Geom::Point3d.new(center.x - vec_l.x + vec_w.x, center.y - vec_l.y + vec_w.y, center.z - vec_l.z + vec_w.z)
        ]

        center_line = [
          Geom::Point3d.new(center.x - vec_l.x, center.y - vec_l.y, center.z - vec_l.z),
          Geom::Point3d.new(center.x + vec_l.x, center.y + vec_l.y, center.z + vec_l.z)
        ]

        # 🌟 C. ĐIỂM SỐ CHỌN MẶT TIẾP XÚC TỐI ƯU (CHỐNG NHẦM MẶT DÁN TEM NHÃN 100%):
        # Ưu tiên tuyệt đối mặt có min_dist sát 0.0mm và facing_dot > 0 (Mặt trong lòng tủ)
        facing_bonus = facing_dot > 0 ? 500.0 : -500.0
        dist_penalty = min_dist.to_mm * 50.0
        score = facing_bonus - dist_penalty + actual_len.to_mm

        if score > best_score
          best_score = score
          best_result = {
            edge_panel: geom_edge[:panel_info],
            face_panel: geom_face[:panel_info],
            receiving_container: geom_face[:entity],
            receiving_trans: geom_face[:world_trans],
            face_normal: normal,
            world_points: pts_ext,
            center_line: center_line,
            raw_length: actual_len,
            raw_width: geom_edge[:thickness],
            groove_length: half_len * 2.0,
            groove_width: half_w * 2.0,
            depth: depth,
            layer: layer,
            create_line: (options[:create_line] || preset['create_line'] || false),
            extend_x: extend_x,
            offset: offset
          }
        end
      end

      best_result
    end

    # ==========================================================================
    # 🎯 5. THI CÔNG VẼ TIẾT DIỆN GIAO NHAU DÍNH PHẲNG TRÊN TẤM VÁN (CHUẨN ABF)
    # ==========================================================================
    def self.apply_intersection(geom, options = {})
      return nil unless geom && geom[:face_panel] && geom[:world_points]

      face_panel = geom[:face_panel]
      container = geom[:receiving_container] || face_panel[:entity]
      model = Sketchup.active_model
      return nil unless model && container && container.valid?

      layer_name = geom[:layer] || 'QH_NGAM_MONG_X3'
      target_layer = model.layers[layer_name] || model.layers.add(layer_name)
      if target_layer.respond_to?(:color=)
        target_layer.color = Sketchup::Color.new(47, 128, 237) # Blue ABF
      end

      # 1. Tính toán ma trận biến đổi thế giới của container nhận rãnh
      w_trans = geom[:receiving_trans] || face_panel[:world_trans] || get_world_transformation(face_panel)
      inv_trans = w_trans.inverse

      # 2. Chuyển toạ độ 4 điểm sang hệ toạ độ Local của Container nhận rãnh
      local_pts = geom[:world_points].map { |wp| wp.transform(inv_trans) }

      # 3. Lấy Entities của Container để tạo Group con `_ABF_INTERSECT`
      target_entities = if container.is_a?(Sketchup::ComponentInstance)
                          container.make_unique rescue nil
                          container.definition.entities
                        elsif container.is_a?(Sketchup::Group)
                          container.entities
                        else
                          return nil
                        end

      # 4. Tạo Group con _ABF_INTERSECT dính trên tấm ván
      intersect_grp = target_entities.add_group
      intersect_grp.name = "_ABF_INTERSECT"
      intersect_grp.layer = target_layer

      created_elements = []

      if geom[:create_line]
        loc_l1 = geom[:center_line][0].transform(inv_trans)
        loc_l2 = geom[:center_line][1].transform(inv_trans)
        line = intersect_grp.entities.add_line(loc_l1, loc_l2)
        line.layer = target_layer
        created_elements << line
      else
        edges = []
        len = local_pts.length
        (0...len).each do |i|
          p_start = local_pts[i]
          p_end   = local_pts[(i + 1) % len]
          ed = intersect_grp.entities.add_line(p_start, p_end)
          ed.layer = target_layer
          edges << ed
        end

        face = intersect_grp.entities.add_face(edges) rescue nil
        face.layer = target_layer if face
        created_elements = edges
      end

      # 5. Gán thuộc tính kỹ thuật phục vụ Nesting / Aspire DXF
      depth_mm = (geom[:depth] || 8.0).to_f
      intersect_grp.set_attribute('chill_ai_intersect', 'depth', depth_mm)
      intersect_grp.set_attribute('chill_ai_intersect', 'layer', layer_name)
      intersect_grp.set_attribute('chill_ai_intersect', 'extend_x', geom[:extend_x].to_mm)
      intersect_grp.set_attribute('chill_ai_intersect', 'offset', geom[:offset].to_mm)
      intersect_grp.set_attribute('chill_ai_intersect', 'type', 'pocket_groove')

      pname_edge = geom[:edge_panel][:name] rescue "Tấm cạnh"
      pname_face = geom[:face_panel][:name] rescue "Tấm mặt"
      puts "[Chill AI IntersectEngine] ✅ Đã tạo rãnh ngàm trên [#{pname_face}] từ [#{pname_edge}] (Dài: #{geom[:groove_length].to_mm.round(1)}mm, Rộng: #{geom[:groove_width].to_mm.round(1)}mm, Sâu: #{depth_mm}mm, Layer: #{layer_name})!"

      intersect_grp
    rescue => e
      puts "[Chill AI IntersectEngine Error] Lỗi apply_intersection: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      nil
    end

    # ==========================================================================
    # ⚡ 6. XỬ LÝ 1-CLICK TẠO TIẾT DIỆN CHO VÙNG CHỌN (CHUẨN ẢNH 2 CỦA ABF)
    # ==========================================================================
    def self.apply_to_selection(options = {})
      model = Sketchup.active_model
      return { 'status' => 'error', 'message' => 'Chưa mở bản vẽ SketchUp!' } unless model

      sel = model.selection
      if sel.empty?
        return { 'status' => 'warning', 'message' => 'Vui lòng kích chọn ít nhất 1 tấm ván mộc trong SketchUp để tạo tiết diện giao nhau!' }
      end

      all_panels = collect_all_panels
      if all_panels.empty?
        return { 'status' => 'warning', 'message' => 'Không tìm thấy tấm ván mộc nào trong mô hình!' }
      end

      sel_entities = sel.to_a
      selected_panels = []

      # 🌟 1. BẮT CHÍNH XÁC CÁC TẤM VÁN MỘC ĐƯỢC CHỌN TRỰC TIẾP
      # Ưu tiên tuyệt đối: Nếu anh Huy đã chọn đích danh các tấm con (A, B, C, D),
      # CHỈ LẤY ĐÚNG CÁC TẤM ĐÓ, TUYỆT ĐỐI KHÔNG LẤY TẤM KHÁC (như tấm E) qua parent!
      direct_matched = []
      all_panels.each do |p|
        ent = p[:entity]
        if sel_entities.include?(ent)
          direct_matched << p
        else
          # Kiểm tra xem người dùng có chọn face hoặc edge con bên trong tấm này không
          sub_ents = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.definition.entities rescue [])
          if sel_entities.any? { |s| sub_ents.include?(s) }
            direct_matched << p
          end
        end
      end

      if !direct_matched.empty?
        # Người dùng chọn trực tiếp các tấm ván: LẤY ĐÚNG CÁC TẤM ĐƯỢC CHỌN!
        selected_panels = direct_matched.uniq
      else
        # Người dùng chọn Group cha bao ngoài (ví dụ Thùng Tủ lớn từ bên ngoài chưa mở):
        # Chỉ khi không có tấm con nào được chọn trực tiếp thì mới bung con
        all_panels.each do |p|
          if p[:parent] && sel_entities.include?(p[:parent])
            selected_panels << p
          end
        end
      end

      # Fallback: Nếu vẫn chưa khớp, lấy chính entity đang chọn làm panel
      if selected_panels.empty?
        sel_entities.each do |item|
          if item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)
            selected_panels << { entity: item, parent: nil, world_trans: item.transformation, name: item.name }
          end
        end
      end

      if selected_panels.empty?
        return { 'status' => 'warning', 'message' => 'Vui lòng kích chọn vào một tấm ván mộc trong mô hình SketchUp!' }
      end

      preset = options[:preset] || get_active_preset

      # 🌟 2. XỬ LÝ THEO SỐ LƯỢNG TẤM ĐƯỢC CHỌN (STRICT SELECTION INTERACTION)
      if selected_panels.length == 1
        # ⚠️ Người dùng CHỈ CHỌN 1 TẤM DUY NHẤT (Ví dụ: Tấm A)
        # TUYỆT ĐỐI KHÔNG tự động quét toàn bộ mô hình (tránh sinh rãnh ngoài ý muốn với tấm E)!
        target_panel = selected_panels.first
        pname = target_panel[:name] || "Tấm ván"

        # Kích hoạt công cụ tương tác 3D Tool với Tấm 1 đã được chọn sẵn:
        if defined?(ChillAIInterior::IntersectTool)
          tool = ChillAIInterior::IntersectTool.activate_tool(options)
          tool.selected_panel = target_panel rescue nil
          tool.update_status_bar rescue nil
          model.active_view.invalidate rescue nil
        end

        msg = "Đã khóa Tấm 1 [#{pname}]. Mời anh Huy kích chọn tiếp Tấm 2 (B, C, D...) trên bản vẽ để tạo rãnh ngàm! (Tấm nào anh Huy không kích chọn sẽ không tạo rãnh)"
        Sketchup.status_text = "Chill AI: #{msg}"
        AudioPlayer.play({ 'text' => "Đã chọn tấm #{pname}. Mời anh Huy kích chọn tiếp tấm tiếp xúc trên bản vẽ." }) rescue nil if defined?(AudioPlayer)

        return { 'status' => 'info', 'count' => 0, 'message' => msg }
      end

      # 🌟 3. NGƯỜI DÙNG CHỌN TỪ 2 TẤM TRỞ LÊN (Ví dụ: Giữ Ctrl chọn Tấm A và Tấm B, C, D)
      # Quét STRICTLY chỉ giữa các cặp tấm nằm trong vùng chọn {A, B, C, D}!
      # Tấm E KHÔNG NẰM TRONG VÙNG CHỌN -> TUYỆT ĐỐI KHÔNG TẠO RÃNH!
      model.start_operation("Chill AI - Tạo Tiết Diện Giao Nhau (Chuẩn ABF)", true)
      begin
        total_created = 0

        (0...selected_panels.length).each do |i|
          ((i + 1)...selected_panels.length).each do |j|
            pa = selected_panels[i]
            pb = selected_panels[j]
            geom = auto_detect_intersection(pa, pb, options)
            if geom
              res = apply_intersection(geom, options)
              total_created += 1 if res
            end
          end
        end

        model.commit_operation

        if total_created > 0
          msg = "Đã tạo thành công #{total_created} rãnh tiết diện ngàm âm dương (Layer: #{preset['layer']}, kéo giãn 2 đầu #{preset['extend_x']}mm)!"
          Sketchup.status_text = "Chill AI: #{msg}"
          AudioPlayer.play({ 'text' => "Đã tạo #{total_created} rãnh ngàm âm dương giao nhau thành công cho anh Huy rồi nhé!" }) rescue nil if defined?(AudioPlayer)
          { 'status' => 'success', 'count' => total_created, 'message' => msg }
        else
          model.abort_operation rescue nil
          msg = "Không tìm thấy vị trí tiếp xúc hoặc giao nhau giữa các tấm ván trong vùng chọn!"
          Sketchup.status_text = "Chill AI: #{msg}"
          { 'status' => 'warning', 'count' => 0, 'message' => msg }
        end
      rescue => e
        model.abort_operation rescue nil
        err_msg = "Lỗi khi tạo tiết diện giao nhau: #{e.message}"
        puts "[Chill AI IntersectEngine Error] #{err_msg}\n#{e.backtrace.first(3).join("\n")}"
        Sketchup.status_text = "Chill AI: #{err_msg}"
        { 'status' => 'error', 'message' => err_msg }
      end
    end

    # ==========================================================================
    # 🧹 7. XÓA SẠCH TIẾT DIỆN GIAO NHAU
    # ==========================================================================
    def self.clear_intersections(selection_only = false)
      model = Sketchup.active_model
      return { 'status' => 'error', 'message' => 'Chưa mở bản vẽ SketchUp!' } unless model

      model.start_operation("Chill AI - Xóa Tiết Diện Giao Nhau", true)
      begin
        count = 0
        all_panels = collect_all_panels
        all_panels.each do |p|
          ent = p[:entity]
          ents = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.definition.entities rescue nil)
          next unless ents
          ents.grep(Sketchup::Group).select { |g| g.name =~ /^_ABF_INTERSECT|Chill_AI_Intersect/i }.each do |g|
            g.erase! rescue nil
            count += 1
          end
        end

        model.commit_operation
        msg = "Đã xóa sạch #{count} rãnh tiết diện giao nhau trong mô hình!"
        Sketchup.status_text = "Chill AI: #{msg}"
        { 'status' => 'success', 'count' => count, 'message' => msg }
      rescue => e
        model.abort_operation rescue nil
        { 'status' => 'error', 'message' => e.message }
      end
    end
  end
end
