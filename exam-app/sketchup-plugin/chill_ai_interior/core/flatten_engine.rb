# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Flatten Engine (Bộ Não Trải Phẳng & Sẻ Rãnh Uốn Cong CNC)
# Chuẩn hoá 100% theo giải pháp công nghệ UniTool / Quốc Thắng CNC & ABF:
#   1. Phân tích hình học tấm ván cong: Đoạn thẳng + Cung tròn bán kính R, góc uốn θ
#   2. Nhận diện Mặt Trước (Lồi / Convex) và Mặt Sau (Lõm / Concave)
#   3. Tính toán chiều dài trải phẳng chuẩn xác theo lớp phôi dẻo giữ nguyên (P)
#   4. Sinh rãnh phay uốn cong (Kerf Bending) chuẩn Layer ABF:
#      - ABF_SE_RANH (Line tâm dao)
#      - UNI_PHAY_RANH (Pocket / Rãnh âm)
#      - ABF_BAO_VE_RANH (Biên bảo vệ rãnh)
#   5. Tự động sinh Cữ Dưỡng Uốn (Bending Jig) chuẩn mộc (50x17.5mm)
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'
require 'json'
require 'set'

module ChillAIInterior
  module FlattenEngine
    CONFIG_FILE_NAME = 'flatten_config.json'.freeze

    DEFAULT_CONFIG = {
      'tool_dia'        => 3.0,          # [D] Đường kính dao (mm)
      'protect_offset'  => 0.0,          # [L] Offset rãnh bảo vệ (mm)
      'rem_thickness'   => 3.0,          # [P] Bề dày phôi còn lại (mm)
      'groove_pitch'    => 15.0,         # [S] Kéo giãn rãnh (mm)
      'jig_width'       => 50.0,         # Bề rộng dưỡng uốn (mm)
      'jig_thick'       => 17.5,         # Độ dày ván làm dưỡng (mm)
      'jig_count'       => 2,            # Số lượng cữ dưỡng tạo ra
      'layer_saw'       => 'ABF_SE_RANH',
      'layer_groove'    => 'UNI_PHAY_RANH',
      'layer_protect'   => 'ABF_BAO_VE_RANH',
      'cut_mode'        => 'Line',       # 'Line', 'Pocket', 'Zig Zag'
      'bend_side'       => 'inside'      # 'inside' (mặt trong / lõm), 'outside' (mặt ngoài / lồi)
    }.freeze

    @config = nil
    @last_flattened_panel = nil

    def self.plugin_root
      ChillAIInterior.const_defined?(:PLUGIN_ROOT) ? ChillAIInterior::PLUGIN_ROOT : File.expand_path(File.join(File.dirname(__FILE__), '..'))
    end

    def self.config_path
      File.join(plugin_root, CONFIG_FILE_NAME)
    end

    def self.get_config
      @config || load_config
    end

    def self.load_config
      path = config_path
      if File.exist?(path)
        begin
          content = File.read(path, encoding: 'UTF-8')
          saved = JSON.parse(content)
          @config = DEFAULT_CONFIG.merge(saved || {})
        rescue => e
          puts "[Chill AI FlattenEngine] Lỗi đọc config: #{e.message}. Dùng mặc định."
          @config = DEFAULT_CONFIG.dup
        end
      else
        @config = DEFAULT_CONFIG.dup
      end
      @config
    end

    def self.save_config(new_cfg)
      @config = get_config.merge(new_cfg || {})
      begin
        File.open(config_path, 'w:UTF-8') do |f|
          f.write(JSON.pretty_generate(@config))
        end
        puts "[Chill AI FlattenEngine] ✅ Đã lưu cấu hình trải phẳng bề mặt."
      rescue => e
        puts "[Chill AI FlattenEngine] Lỗi ghi config: #{e.message}"
      end
      @config
    end

    # ==========================================================================
    # 🔍 PHÂN TÍCH HÌNH HỌC BỀ MẶT CONG (SURFACE & CURVATURE ANALYSIS)
    # ==========================================================================
    def self.get_connected_surface_faces(start_face)
      return [] unless start_face && start_face.is_a?(Sketchup::Face) && start_face.valid?

      visited = Set.new([start_face])
      queue = [start_face]

      while !queue.empty?
        f = queue.shift
        f.edges.each do |edge|
          # Trong SketchUp, các mặt cong liền mạch nối với nhau qua cạnh smooth/soft
          # Hoặc nếu tiếp xúc tiếp tuyến (tangent)
          is_seamless = edge.smooth? || edge.soft?
          edge.faces.each do |neighbor|
            next if visited.include?(neighbor)
            if is_seamless
              # Cùng hướng (không phải mặt vuông góc gập 90 độ)
              if f.normal.dot(neighbor.normal) > 0.05
                visited.add(neighbor)
                queue << neighbor
              end
            else
              # Kiểm tra nếu 2 mặt tiếp tuyến gần như đồng phẳng
              dot = f.normal.dot(neighbor.normal)
              if (dot - 1.0).abs < 0.001
                visited.add(neighbor)
                queue << neighbor
              end
            end
          end
        end
      end

      visited.to_a
    end

    # Kiểm tra xem mặt cong là Mặt Ngoài (Lồi - Convex) hay Mặt Trong (Lõm - Concave)
    def self.detect_convex_or_concave(faces)
      return :planar if faces.length <= 1

      # Thu thập các cặp pháp tuyến giữa các mặt kề cận
      convex_votes = 0
      concave_votes = 0

      faces.each do |f1|
        f1.edges.each do |edge|
          f2 = edge.faces.find { |f| f != f1 && faces.include?(f) }
          next unless f2

          # Vector nối từ tâm f1 sang tâm f2
          c1 = f1.bounds.center
          c2 = f2.bounds.center
          v_dir = c2 - c1

          # Normal delta
          n_delta = f2.normal - f1.normal

          # Nếu pháp tuyến chĩa xa nhau (phân kỳ) -> Lồi
          # Nếu pháp tuyến chụm vào nhau (hội tụ) -> Lõm
          dot = n_delta.dot(v_dir)
          if dot < -1e-5
            convex_votes += 1
          elsif dot > 1e-5
            concave_votes += 1
          end
        end
      end

      if convex_votes > concave_votes
        :convex # Mặt Ngoài (Lồi)
      elsif concave_votes > convex_votes
        :concave # Mặt Trong (Lõm)
      else
        :neutral
      end
    end

    # Đo độ dày ván T bằng cách dò mặt đối diện (Opposite Face)
    def self.detect_panel_thickness(start_face, parent_entity)
      norm = start_face.normal
      ents = parent_entity.is_a?(Sketchup::Group) ? parent_entity.entities : parent_entity.definition.entities
      all_faces = ents.grep(Sketchup::Face)

      # Bắn tia ngược hướng normal của start_face
      pt_test = start_face.bounds.center
      ray_dir = norm.reverse

      min_dist = 1000.0
      all_faces.each do |f|
        next if f == start_face
        # Mặt đối diện phải có pháp tuyến ngược hướng (dot ~ -1)
        if f.normal.dot(norm) < -0.8
          dist = f.plane_distance(pt_test).abs rescue nil
          if dist && dist > 2.0.mm && dist < 50.0.mm && dist < min_dist
            min_dist = dist
          end
        end
      end

      min_dist < 900.0 ? min_dist : 17.5.mm
    end

    # Phân tích toàn diện bề mặt được chọn
    def self.analyze_curved_surface(picked_face, total_trans = Geom::Transformation.new, options = {})
      return { valid: false, error: 'Mặt chọn không hợp lệ' } unless picked_face && picked_face.valid?

      faces = get_connected_surface_faces(picked_face)
      if faces.empty?
        faces = [picked_face]
      end

      curv_type = detect_convex_or_concave(faces)
      is_convex = (curv_type == :convex)

      # Tìm trục kéo dài của ván (Extrusion Height Axis)
      # Bằng cách lấy các cạnh thẳng dài không bị uốn cong
      straight_edges = []
      faces.each do |f|
        f.edges.each do |e|
          straight_edges << e if !e.smooth? && !e.soft?
        end
      end

      # Trục chiều cao (thường là Z hoặc song song với các cạnh đứng)
      height_vec = Geom::Vector3d.new(0, 0, 1)
      if !straight_edges.empty?
        longest_edge = straight_edges.max_by { |e| e.length }
        height_vec = longest_edge.line[1].normalize rescue Geom::Vector3d.new(0, 0, 1)
      end

      # Chiều cao tấm ván H
      bb_local = Geom::BoundingBox.new
      faces.each { |f| bb_local.add(f.bounds) }
      panel_h = [bb_local.height, bb_local.width, bb_local.depth].max

      # Phân tích các dải mặt cắt 2D theo chiều ngang (Transverse profile)
      # Đo tổng chiều dài trải phẳng theo chuỗi các face
      # Mỗi face là một quadrilateral (hoặc strip)
      total_unrolled_width = 0.0
      curved_regions = []

      # Sắp xếp các face theo chuỗi liên tiếp từ đầu này sang đầu kia
      ordered_faces = sort_faces_in_chain(faces)

      curr_u = 0.0
      in_curve = false
      curve_start_u = 0.0
      curve_faces = []

      ordered_faces.each_with_index do |f, idx|
        # Đo bề rộng của face này theo phương vuông góc với height_vec
        # Lấy 2 cạnh chạy dọc theo chiều cao, khoảng cách giữa 2 cạnh là width
        f_width = calculate_face_transverse_width(f, height_vec)
        next if f_width <= 0.001.mm

        # Kiểm tra face này có thuộc đoạn cong không (các cạnh kề là smooth)
        f_is_curved = f.edges.any? { |e| e.smooth? || e.soft? }

        if f_is_curved && !in_curve
          in_curve = true
          curve_start_u = curr_u
          curve_faces = [f]
        elsif f_is_curved && in_curve
          curve_faces << f
        elsif !f_is_curved && in_curve
          # Kết thúc đoạn cong
          in_curve = false
          curve_end_u = curr_u
          curved_regions << build_curved_region(curve_start_u, curve_end_u, curve_faces, height_vec, total_trans)
          curve_faces = []
        end

        curr_u += f_width
      end

      if in_curve && !curve_faces.empty?
        curved_regions << build_curved_region(curve_start_u, curr_u, curve_faces, height_vec, total_trans)
      end

      total_unrolled_width = curr_u

      # Nếu toàn bộ các face chỉ là 1 đoạn cong duy nhất
      if curved_regions.empty? && faces.length > 1
        curved_regions << build_curved_region(0.0, total_unrolled_width, faces, height_vec, total_trans)
      end

      # Tạo các đường gióng tiếp tuyến đỏ nét đứt (Red dashed tangent lines) chuẩn như Ảnh 3!
      tangent_lines = []
      curved_regions.each do |cr|
        tangent_lines.concat(cr[:tangent_lines_world]) if cr[:tangent_lines_world]
      end

      {
        valid: true,
        faces: faces,
        curv_type: curv_type,
        is_convex: is_convex,
        height: panel_h,
        unrolled_width: total_unrolled_width,
        curved_regions: curved_regions,
        tangent_lines: tangent_lines,
        height_vec: height_vec
      }
    end

    def self.calculate_face_transverse_width(face, height_vec)
      # Chu vi chia 2 hoặc khoảng cách giữa 2 đỉnh ngang
      pts = face.vertices.map(&:position)
      return 0.0 if pts.length < 3

      # Chiếu các điểm lên mặt phẳng vuông góc với height_vec
      proj_pts = pts.map do |pt|
        pt - height_vec * (pt.to_a.zip(height_vec.to_a).map { |a, b| a * b }.sum)
      end

      # Tìm khoảng cách lớn nhất giữa 2 điểm liên tiếp trên biên
      max_w = 0.0
      face.outer_loop.edges.each do |e|
        next if (e.line[1].normalize.dot(height_vec)).abs > 0.85 # Bỏ qua cạnh đứng
        max_w = [max_w, e.length].max
      end

      max_w > 0 ? max_w : face.bounds.diagonal * 0.5
    end

    def self.sort_faces_in_chain(faces)
      return faces if faces.length <= 1

      # Bắt đầu từ một face ở rìa (face chỉ có 1 neighbor là face trong tập)
      start_f = faces.find do |f|
        neighbor_count = f.edges.count do |e|
          e.faces.any? { |nf| nf != f && faces.include?(nf) }
        end
        neighbor_count <= 1
      end || faces.first

      sorted = [start_f]
      visited = Set.new([start_f])

      while sorted.length < faces.length
        last_f = sorted.last
        next_f = nil
        last_f.edges.each do |e|
          cand = e.faces.find { |f| f != last_f && faces.include?(f) && !visited.include?(f) }
          if cand
            next_f = cand
            break
          end
        end

        break unless next_f
        visited.add(next_f)
        sorted << next_f
      end

      # Nếu còn face sót
      faces.each { |f| sorted << f unless visited.include?(f) }
      sorted
    end

    def self.build_curved_region(start_u, end_u, c_faces, height_vec, total_trans)
      arc_len = end_u - start_u

      # Tính góc uốn cong θ từ pháp tuyến của face đầu và face cuối
      first_norm = c_faces.first.normal
      last_norm  = c_faces.last.normal
      cos_angle  = [[first_norm.dot(last_norm), -1.0].max, 1.0].min
      angle_rad  = Math.acos(cos_angle)
      angle_rad  = 90.0.degrees if angle_rad < 0.01

      radius = (angle_rad > 0.001) ? (arc_len / angle_rad) : 50.0.mm

      # Xây dựng các đường tiếp tuyến hình chiếu màu đỏ ở 2 đầu (Red dashed lines như Ảnh 3)
      tangent_lines = []
      begin
        [c_faces.first, c_faces.last].each do |edge_face|
          pts = edge_face.vertices.map { |v| total_trans * v.position }
          if pts.length >= 2
            p1 = pts[0]
            p2 = pts[1]
            tangent_dir = (total_trans.transform(edge_face.normal * height_vec)).normalize rescue nil
            if tangent_dir
              ext_len = 120.0.mm
              tangent_lines << (p1 - tangent_dir * ext_len)
              tangent_lines << (p1 + tangent_dir * ext_len)
              tangent_lines << (p2 - tangent_dir * ext_len)
              tangent_lines << (p2 + tangent_dir * ext_len)
            end
          end
        end
      rescue
      end

      {
        start_u: start_u,
        end_u: end_u,
        arc_len: arc_len,
        radius: radius,
        angle_rad: angle_rad,
        tangent_lines_world: tangent_lines
      }
    end

    # ==========================================================================
    # 🚀 THI HÀNH TRẢI PHẲNG (FLATTEN EXECUTION & CNC KERF GENERATION)
    # ==========================================================================
    def self.flatten_curved_face(picked_face, parent_entity, total_trans, options = {})
      model = Sketchup.active_model
      return { 'status' => 'error', 'message' => 'Mô hình không tồn tại' } unless model

      cfg = get_config.merge(options || {})

      tool_dia       = (cfg['tool_dia'] || 3.0).to_f.mm
      protect_offset = (cfg['protect_offset'] || 0.0).to_f.mm
      rem_thick      = (cfg['rem_thickness'] || 3.0).to_f.mm
      groove_pitch   = (cfg['groove_pitch'] || 15.0).to_f.mm
      jig_w          = (cfg['jig_width'] || 50.0).to_f.mm
      jig_t          = (cfg['jig_thick'] || 17.5).to_f.mm
      jig_count      = (cfg['jig_count'] || 2).to_i

      layer_saw      = (cfg['layer_saw'] || 'ABF_SE_RANH').to_s
      layer_groove   = (cfg['layer_groove'] || 'UNI_PHAY_RANH').to_s
      layer_protect  = (cfg['layer_protect'] || 'ABF_BAO_VE_RANH').to_s
      cut_mode       = (cfg['cut_mode'] || 'Line').to_s
      bend_side      = (cfg['bend_side'] || 'inside').to_s # 'inside' hoặc 'outside'

      # 1. Phân tích hình học
      analysis = analyze_curved_surface(picked_face, total_trans, cfg)
      return { 'status' => 'error', 'message' => 'Không thể phân tích bề mặt cong!' } unless analysis[:valid]

      panel_thick = detect_panel_thickness(picked_face, parent_entity)
      panel_h     = analysis[:height]
      panel_w     = analysis[:unrolled_width]

      if panel_w <= 10.0.mm || panel_h <= 10.0.mm
        return { 'status' => 'error', 'message' => 'Kích thước tấm ván quá nhỏ, vui lòng kiểm tra lại!' }
      end

      # Độ sâu rãnh phay CNC: Chiều dày ván trừ bề dày phôi dẻo còn lại
      kerf_depth = [panel_thick - rem_thick, 1.0.mm].max

      model.start_operation("Chill AI - Trải Phẳng Bề Mặt Ván Bo Cong", true)

      begin
        # Đảm bảo các Layer/Tag CNC tồn tại trong Model
        tag_saw     = model.layers[layer_saw]     || model.layers.add(layer_saw)
        tag_groove  = model.layers[layer_groove]  || model.layers.add(layer_groove)
        tag_protect = model.layers[layer_protect] || model.layers.add(layer_protect)
        tag_cut     = model.layers['ABF_Cut']     || model.layers.add('ABF_Cut')

        # Vị trí đặt tấm ván phẳng (nằm phẳng trên mặt đất Oxy cạnh chi tiết gốc)
        p_name = parent_entity.name.to_s.strip
        p_name = "Ván_Cong" if p_name.empty?

        bb_world = parent_entity.bounds
        offset_x = bb_world.max.x + 150.0.mm
        offset_y = bb_world.min.y
        base_pt  = Geom::Point3d.new(offset_x, offset_y, 0)

        # 2. Tạo Group Tấm Ván Phẳng (Flattened Panel)
        flat_grp = model.active_entities.add_group
        flat_grp.name = "TP_#{p_name}_Phẳng_#{panel_w.to_mm.round}x#{panel_h.to_mm.round}x#{panel_thick.to_mm.round(1)}"
        flat_grp.layer = tag_cut

        ents = flat_grp.entities

        # Vẽ hình chữ nhật đáy phẳng: Kích thước Width x Height
        p0 = base_pt
        p1 = base_pt + Geom::Vector3d.new(panel_w, 0, 0)
        p2 = base_pt + Geom::Vector3d.new(panel_w, panel_h, 0)
        p3 = base_pt + Geom::Vector3d.new(0, panel_h, 0)

        base_face = ents.add_face(p0, p1, p2, p3)
        base_face.pushpull(-panel_thick) # Đùn xuống theo chiều dày phôi

        # Lấy mặt trên cùng (top face) để vẽ rãnh CNC
        top_face = ents.grep(Sketchup::Face).find { |f| f.normal.z > 0.9 }

        # 3. Vẽ các rãnh CNC (Kerf Bending Grooves) tại từng vùng cong
        total_grooves_drawn = 0

        analysis[:curved_regions].each do |cr|
          start_u = cr[:start_u]
          end_u   = cr[:end_u]
          region_w = end_u - start_u
          next if region_w <= 2.0.mm

          # Tính số lượng rãnh
          num_grooves = [(region_w / groove_pitch).round, 1].max
          actual_pitch = region_w / (num_grooves + 1)

          y_start = protect_offset
          y_end   = panel_h - protect_offset

          # Nếu có Offset Rãnh Bảo Vệ L > 0 -> Vẽ khung bảo vệ rãnh
          if protect_offset > 0.5.mm
            rect_p0 = base_pt + Geom::Vector3d.new(start_u, y_start, 0)
            rect_p1 = base_pt + Geom::Vector3d.new(end_u, y_start, 0)
            rect_p2 = base_pt + Geom::Vector3d.new(end_u, y_end, 0)
            rect_p3 = base_pt + Geom::Vector3d.new(start_u, y_end, 0)
            prot_edges = ents.add_edges(rect_p0, rect_p1, rect_p2, rect_p3, rect_p0)
            prot_edges.each { |pe| pe.layer = tag_protect }
          end

          # Vẽ từng rãnh phay
          (1..num_grooves).each do |idx|
            gx = start_u + idx * actual_pitch
            g_pt1 = base_pt + Geom::Vector3d.new(gx, y_start, 0)
            g_pt2 = base_pt + Geom::Vector3d.new(gx, y_end, 0)

            if cut_mode == 'Pocket' || cut_mode == 'Zig Zag'
              # Phay rãnh rộng D
              half_d = tool_dia * 0.5
              gp0 = g_pt1 + Geom::Vector3d.new(-half_d, 0, 0)
              gp1 = g_pt1 + Geom::Vector3d.new(half_d, 0, 0)
              gp2 = g_pt2 + Geom::Vector3d.new(half_d, 0, 0)
              gp3 = g_pt2 + Geom::Vector3d.new(-half_d, 0, 0)

              groove_face = ents.add_face(gp0, gp1, gp2, gp3) rescue nil
              if groove_face
                groove_face.layer = tag_groove
                groove_face.set_attribute("ABF", "Depth", kerf_depth.to_mm.round(1)) rescue nil
                groove_face.set_attribute("ChillAI", "Depth", kerf_depth.to_mm.round(1)) rescue nil
              else
                line = ents.add_line(g_pt1, g_pt2)
                line.layer = tag_groove
              end
            else
              # Chế độ Line: Chạy 1 nét tâm dao chuẩn ABF_SE_RANH
              line = ents.add_line(g_pt1, g_pt2)
              line.layer = tag_saw
              line.set_attribute("ABF", "Depth", kerf_depth.to_mm.round(1)) rescue nil
              line.set_attribute("ChillAI", "Depth", kerf_depth.to_mm.round(1)) rescue nil
            end

            total_grooves_drawn += 1
          end
        end

        # Gán thuộc tính chuẩn ABF & Chill AI để Nesting tự động
        flat_grp.set_attribute("ABF", "Thickness", panel_thick.to_mm.round(1)) rescue nil
        flat_grp.set_attribute("ABF", "Length", panel_w.to_mm.round(1)) rescue nil
        flat_grp.set_attribute("ABF", "Width", panel_h.to_mm.round(1)) rescue nil
        flat_grp.set_attribute("ChillAI", "IsFlattenedPanel", true)
        flat_grp.set_attribute("ChillAI", "OriginalPanel", p_name)
        flat_grp.set_attribute("ChillAI", "BendingSide", bend_side)
        flat_grp.set_attribute("ChillAI", "KerfDepth", kerf_depth.to_mm.round(1))

        # 4. Tự động sinh Cữ Dưỡng Uốn (Bending Jig)
        jigs_created = 0
        if jig_w > 5.0.mm && jig_t > 2.0.mm && jig_count > 0
          jigs_created = generate_bending_jigs(analysis, base_pt, panel_w, panel_h, jig_w, jig_t, jig_count, tag_cut, p_name)
        end

        model.commit_operation

        @last_flattened_panel = flat_grp

        # Chọn tấm ván phẳng vừa sinh ra
        model.selection.clear rescue nil
        model.selection.add(flat_grp) rescue nil

        AudioPlayer.play({ 'text' => "Đã trải phẳng tấm ván thành công. Tổng chiều dài duỗi là #{panel_w.to_mm.round} mi li mét." }) rescue nil if defined?(AudioPlayer)

        return {
          'status' => 'success',
          'message' => "Đã trải phẳng thành công: #{panel_w.to_mm.round} x #{panel_h.to_mm.round} x #{panel_thick.to_mm.round(1)} mm (#{total_grooves_drawn} rãnh phay).",
          'panel_name' => flat_grp.name,
          'width' => panel_w.to_mm.round(1),
          'height' => panel_h.to_mm.round(1),
          'thickness' => panel_thick.to_mm.round(1),
          'grooves_count' => total_grooves_drawn,
          'jigs_count' => jigs_created
        }
      rescue => err
        model.abort_operation
        puts "[Chill AI FlattenEngine Error]: #{err.message}\n#{err.backtrace.first(5).join("\n")}"
        return { 'status' => 'error', 'message' => "Lỗi trải phẳng: #{err.message}" }
      end
    end

    # Tự động sinh Cữ Dưỡng Uốn (Jig)
    def self.generate_bending_jigs(analysis, base_pt, panel_w, panel_h, jig_w, jig_t, jig_count, tag_cut, p_name)
      model = Sketchup.active_model
      return 0 unless model

      created = 0
      jig_start_y = base_pt.y + panel_h + 80.0.mm

      (1..jig_count).each do |j_idx|
        jig_grp = model.active_entities.add_group
        jig_grp.name = "Dưỡng_Uốn_#{p_name}_Jig#{j_idx}_#{jig_w.to_mm.round}x#{jig_t.to_mm.round(1)}"
        jig_grp.layer = tag_cut

        j_ents = jig_grp.entities

        # Tọa độ cơ sở của Jig
        j_base_x = base_pt.x + (j_idx - 1) * (panel_w * 0.6 + 50.0.mm)
        j_base_y = jig_start_y
        j_pt0 = Geom::Point3d.new(j_base_x, j_base_y, 0)

        # Vẽ biên dạng cong của dưỡng
        # Lấy cung đầu tiên từ analysis
        cr = analysis[:curved_regions].first
        rad = cr ? cr[:radius] : 60.0.mm
        ang = cr ? cr[:angle_rad] : 90.0.degrees

        # Vẽ cung tròn và offset tạo bản rộng dưỡng jig_w
        num_segs = 16
        pts_inner = []
        pts_outer = []

        (0..num_segs).each do |s|
          curr_a = (s.to_f / num_segs) * ang
          # Cung trong (áp vào ván)
          xi = rad * Math.cos(curr_a)
          yi = rad * Math.sin(curr_a)
          pts_inner << (j_pt0 + Geom::Vector3d.new(xi, yi, 0))

          # Cung ngoài (thịt dưỡng)
          xo = (rad + jig_w) * Math.cos(curr_a)
          yo = (rad + jig_w) * Math.sin(curr_a)
          pts_outer << (j_pt0 + Geom::Vector3d.new(xo, yo, 0))
        end

        loop_pts = pts_inner + pts_outer.reverse
        jig_face = j_ents.add_face(loop_pts) rescue nil
        if jig_face
          jig_face.pushpull(jig_t)
          jig_grp.set_attribute("ABF", "Thickness", jig_t.to_mm.round(1)) rescue nil
          jig_grp.set_attribute("ChillAI", "IsBendingJig", true)
          created += 1
        end
      end

      created
    end
  end
end
