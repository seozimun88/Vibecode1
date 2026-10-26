# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Edge Banding Tool (Công Cụ Tương Tác 3D: Chỉ Dán Cạnh ABF)
# Chuẩn hoá 100% theo phong cách tương tác ABF:
#   Bước 1: Kích chọn tấm ván mộc -> Toàn bộ tấm ván nổi VIỀN XANH DƯƠNG ĐẬM
#   Bước 2: Rê chuột và kích chọn CẠNH muốn dán chỉ -> Hiển thị dải màu chỉ trực quan
#   ĐẶC BIỆT (CHUẨN BẢN CHẤT MỘC):
#     - Chỉ cần bấm phím SPACE (phím cách): Thoát tool -> MÀU CHỈ LẬP TỨC ẨN 100%
#       Mô hình 3D trở về vân gỗ sạch sẽ, không bị vấy bẩn Material lên tấm ván!
#     - Khi mở lại tool: Các cạnh đã dán sẽ hiện lại dải màu tương ứng để kiểm tra!
#   Phím tắt:
#     - Phím Space (Phím cách): Thoát công cụ -> Ẩn sạch màu dán chỉ
#     - Phím ~ (Tilde): Bật/tắt chế độ Nhìn Xuyên (X-Ray) để dán cạnh bị khuất
#     - Phím 1, 2, 3: Đổi chế độ (1 cạnh / 4 cạnh / Xóa)
#     - Phím ESC: Hủy chọn tấm ván
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class EdgeBandingTool
    attr_accessor :mode, :selected_panel, :hover_panel, :hover_edge_key

    def self.current_tool
      @current_tool
    end

    def self.activate_tool(options = {})
      tool = new(options)
      @current_tool = tool
      Sketchup.active_model.select_tool(tool)
      WindowManager.show_edge_banding_palette rescue nil if defined?(WindowManager)
      tool
    end

    def initialize(options = {})
      @mode = (options[:mode] || options['mode'] || :single).to_sym # :single, :all, :erase
      @selected_panel = nil
      @panel_geom = nil
      @hover_panel = nil
      @hover_edge_key = nil
      @hover_face = nil

      @mouse_x = 0
      @mouse_y = 0

      EdgeBandingEngine.get_config if defined?(EdgeBandingEngine)
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      @selected_panel = nil
      @panel_geom = nil

      check_existing_selection

      update_status_bar
      puts "[Chill AI EdgeBandingTool] 🎯 Đã kích hoạt công cụ Chỉ Dán Cạnh (Chuẩn ABF)."
      AudioPlayer.play({ 'text' => "Đã bật công cụ dán cạnh. Mời anh Huy kích chọn tấm ván và chọn cạnh muốn dán chỉ nhé." }) rescue nil if defined?(AudioPlayer)

      @view.invalidate
    end

    def deactivate(view)
      @selected_panel = nil
      @panel_geom = nil
      @hover_panel = nil
      @hover_edge_key = nil
      # Khi thoát công cụ (ví dụ bấm phím Space): Vẽ lại view -> Toàn bộ màu chỉ dán cạnh tự động biến mất!
      view.invalidate rescue nil
    end

    def resume(view)
      update_status_bar
      view.invalidate rescue nil
    end

    def set_mode(new_mode)
      @mode = new_mode.to_sym
      update_status_bar
      @view.invalidate if @view
    end

    def toggle_xray
      opts = @model.rendering_options
      opts['ModelTransparency'] = !opts['ModelTransparency']
      state_str = opts['ModelTransparency'] ? "BẬT" : "TẮT"
      Sketchup.status_text = "Chill AI: Đã #{state_str} chế độ Nhìn Xuyên (X-Ray)"
      @view.invalidate if @view
    end

    def check_existing_selection
      return unless @model && @model.selection && !@model.selection.empty?
      sel_ents = @model.selection.to_a
      target = sel_ents.find { |e| is_panel?(e) }
      if target
        select_panel({ entity: target, total_trans: target.transformation })
      end
    end

    def is_panel?(ent)
      return false unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
      name = ent.name.to_s
      return false if name =~ /^(Chill_AI_Label|_ABF_LABEL|ABF_LABEL|Chill_AI_Fitting)/i
      ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
      faces = ents.grep(Sketchup::Face)
      faces.length >= 6
    rescue
      false
    end

    def update_status_bar
      active_preset = EdgeBandingEngine.get_active_preset rescue { 'name' => 'Chỉ Cánh 1mm' }
      pname = active_preset['name']

      mode_str = case @mode
                 when :all   then "DÁN 4 CẠNH XUNG QUANH"
                 when :erase then "XÓA DÁN CHỈ"
                 else             "DÁN 1 CẠNH ĐƠN"
                 end

      if @selected_panel.nil?
        Sketchup.status_text = "Chill AI [Chỉ Dán Cạnh ABF] 👉 BƯỚC 1: Kích chuột trái CHỌN TẤM VÁN | Chế độ: [#{mode_str}] | Phím Space: Thoát & Ẩn màu chỉ | Phím ~: Nhìn xuyên"
      else
        panel_name = @selected_panel[:entity].name.to_s.strip
        panel_name = "Tấm ván" if panel_name.empty?
        if @mode == :erase
          Sketchup.status_text = "Chill AI [Xóa Dán Cạnh] 🧹 Đang chọn [#{panel_name}] 👉 Kích vào cạnh muốn XÓA dán chỉ | Phím Space: Thoát & Ẩn màu chỉ"
        elsif @mode == :all
          Sketchup.status_text = "Chill AI [Dán 4 Cạnh] 🌟 Đang chọn [#{panel_name}] 👉 Kích vào tấm ván để DÁN CẢ 4 CẠNH bằng [#{pname}] | Phím Space: Thoát & Ẩn màu chỉ"
        else
          edge_txt = @hover_edge_key ? " -> KÍCH ĐỂ DÁN #{@hover_edge_key}" : ""
          Sketchup.status_text = "Chill AI [Dán Cạnh ABF] 🎯 Đang chọn [#{panel_name}] (Viền xanh) 👉 BƯỚC 2: Kích chọn CẠNH muốn dán [#{pname}]#{edge_txt} | Phím Space: Thoát & Ẩn màu chỉ"
        end
      end
    end

    # ==========================================================================
    # SỰ KIỆN CHUỘT
    # ==========================================================================
    def onMouseMove(flags, x, y, view)
      @mouse_x = x
      @mouse_y = y

      picked = find_panel_at(x, y, view)

      if @selected_panel.nil?
        if picked != @hover_panel
          @hover_panel = picked
          view.invalidate
        end
      else
        if picked && picked[:entity] == @selected_panel[:entity]
          edge_key, edge_face = detect_edge_face_at(x, y, view, @selected_panel)
          if edge_key != @hover_edge_key
            @hover_edge_key = edge_key
            @hover_face = edge_face
            update_status_bar
            view.invalidate
          end
        else
          if @hover_edge_key
            @hover_edge_key = nil
            @hover_face = nil
            update_status_bar
            view.invalidate
          end
        end
      end
    end

    def onLButtonDown(flags, x, y, view)
      picked = find_panel_at(x, y, view)

      if @selected_panel.nil?
        if picked
          select_panel(picked)
          if @mode == :all
            apply_to_panel('ALL')
          end
        end
      else
        if picked && picked[:entity] == @selected_panel[:entity]
          edge_key, _edge_face = detect_edge_face_at(x, y, view, @selected_panel)
          if edge_key
            if @mode == :erase
              remove_from_panel(edge_key)
            else
              apply_to_panel(edge_key)
            end
          elsif @mode == :all
            apply_to_panel('ALL')
          end
        elsif picked && picked[:entity] != @selected_panel[:entity]
          select_panel(picked)
          if @mode == :all
            apply_to_panel('ALL')
          end
        else
          @selected_panel = nil
          @panel_geom = nil
          @hover_edge_key = nil
          @hover_face = nil
          update_status_bar
          view.invalidate
        end
      end
    end

    def select_panel(panel_info)
      @selected_panel = panel_info
      @panel_geom = EdgeBandingEngine.analyze_panel_edges(@selected_panel[:entity])
      pname = @selected_panel[:entity].name.to_s.strip
      pname = "Tấm ván" if pname.empty?

      # Tự động gán làm tấm được chọn ưu tiên cho Nesting
      if defined?(EdgeBandingEngine)
        EdgeBandingEngine.last_selected_panel = @selected_panel[:entity]
      end

      # Đồng bộ chọn tấm ván này vào selection của SketchUp
      if @model && @selected_panel[:entity] && @selected_panel[:entity].valid?
        @model.selection.clear rescue nil
        @model.selection.add(@selected_panel[:entity]) rescue nil
      end

      puts "[Chill AI EdgeBandingTool] ✅ Đã chọn tấm ván: [#{pname}] và gán vào Selection SketchUp"
      AudioPlayer.play({ 'text' => "Đã chọn #{pname}." }) rescue nil if defined?(AudioPlayer)
      update_status_bar
      @view.invalidate if @view
    end

    def apply_to_panel(edge_key)
      return unless @selected_panel && @selected_panel[:entity]

      preset = EdgeBandingEngine.get_active_preset
      res = EdgeBandingEngine.apply_edge_banding(@selected_panel[:entity], edge_key, preset)
      if res
        pname = preset['name']
        edge_lbl = edge_key == 'ALL' ? "4 cạnh xung quanh" : "Cạnh #{edge_key}"
        thick_str = "#{preset['thickness']}mm"
        Sketchup.status_text = "Chill AI: ✅ Đã dán [#{pname} (#{thick_str})] cho #{edge_lbl}. Khi Nesting tấm này sẽ bị hụt #{thick_str} theo cạnh dán!"
        AudioPlayer.play({ 'text' => "Đã dán chỉ #{pname}." }) rescue nil if defined?(AudioPlayer)
        @panel_geom = EdgeBandingEngine.analyze_panel_edges(@selected_panel[:entity])
        @view.invalidate if @view
      end
    end

    def remove_from_panel(edge_key)
      return unless @selected_panel && @selected_panel[:entity]

      res = EdgeBandingEngine.remove_edge_banding(@selected_panel[:entity], edge_key)
      if res
        edge_lbl = edge_key == 'ALL' ? "toàn bộ cạnh" : "Cạnh #{edge_key}"
        Sketchup.status_text = "Chill AI: 🧹 Đã xóa dán chỉ cho #{edge_lbl}."
        AudioPlayer.play({ 'text' => "Đã xóa dán cạnh." }) rescue nil if defined?(AudioPlayer)
        @panel_geom = EdgeBandingEngine.analyze_panel_edges(@selected_panel[:entity])
        @view.invalidate if @view
      end
    end

    def find_panel_at(x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)

      (0...ph.count).each do |idx|
        path = ph.path_at(idx)
        next unless path
        path.reverse_each do |ent|
          if is_panel?(ent)
            accum_trans = calculate_accum_trans(path, ent)
            return { entity: ent, total_trans: accum_trans, path: path }
          end
        end
      end
      nil
    end

    def calculate_accum_trans(path, target_ent)
      trans = Geom::Transformation.new
      path.each do |node|
        trans = trans * node.transformation if node.respond_to?(:transformation)
        break if node == target_ent
      end
      trans
    end

    def detect_edge_face_at(x, y, view, panel_info)
      return [nil, nil] unless panel_info && @panel_geom

      ph = view.pick_helper
      ph.do_pick(x, y)

      picked_face = nil
      (0...ph.count).each do |idx|
        f = ph.leaf_at(idx)
        if f.is_a?(Sketchup::Face)
          picked_face = f
          break
        end
      end

      if picked_face
        @panel_geom[:edge_faces].each do |k, f|
          return [k, f] if f == picked_face
        end
      end

      ray = view.pickray(x, y)
      total_trans = panel_info[:total_trans]
      inv_trans = total_trans.inverse
      local_ray = [ray[0].transform(inv_trans), ray[1].transform(inv_trans)]

      best_key = nil
      best_dist = 1.0e9
      best_face = nil

      @panel_geom[:edge_faces].each do |k, face|
        next unless face && face.valid?
        plane = face.plane
        pt_intersect = Geom.intersect_line_plane(local_ray, plane)
        if pt_intersect
          dist = pt_intersect.distance(face.bounds.center)
          if dist < best_dist
            best_dist = dist
            best_key = k
            best_face = face
          end
        end
      end

      [best_key, best_face]
    rescue
      [nil, nil]
    end

    # ==========================================================================
    # SỰ KIỆN BÀN PHÍM (PHÍM SPACE: THOÁT VÀ ẨN SẠCH MÀU CHỈ)
    # ==========================================================================
    def onKeyDown(key, repeat, flags, view)
      case key
      when 32 # Phím SPACE: Thoát tool về công cụ Select -> Ẩn sạch màu dán chỉ, GIỮ NGUYÊN VÙNG CHỌN TẤM VÁN!
        puts "[Chill AI EdgeBandingTool] 🔄 Bấm phím Space: Thoát công cụ và ẩn sạch màu chỉ dán."
        if @selected_panel && @selected_panel[:entity] && @selected_panel[:entity].valid?
          if defined?(EdgeBandingEngine)
            EdgeBandingEngine.last_selected_panel = @selected_panel[:entity]
          end
          model = Sketchup.active_model
          if model
            model.selection.clear rescue nil
            model.selection.add(@selected_panel[:entity]) rescue nil
          end
        end
        Sketchup.status_text = "Chill AI: Đã thoát công cụ Dán Chỉ. Tấm ván đang được chọn sẵn sàng để Nesting!"
        Sketchup.send_action("selectSelectionTool:")
        return true

      when 192 # Phím ~ (Tilde): Bật/Tắt Nhìn Xuyên X-Ray
        toggle_xray
        return true

      when 49, 97 # Phím 1: Chế độ 1 cạnh
        set_mode(:single)
        return true

      when 50, 98, 52, 100 # Phím 2 hoặc 4: Chế độ 4 cạnh
        set_mode(:all)
        return true

      when 51, 99, 46, 8 # Phím 3 hoặc Delete: Chế độ xóa
        set_mode(:erase)
        return true

      when 27 # Phím ESC: Hủy chọn tấm ván
        @selected_panel = nil
        @panel_geom = nil
        @hover_edge_key = nil
        @hover_face = nil
        update_status_bar
        view.invalidate
        return true
      end

      false
    end

    # ==========================================================================
    # VẼ TRỰC QUAN TRÊN KHÔNG GIAN 3D (CHỈ HIỂN THỊ KHI TOOL ĐANG HOẠT ĐỘNG!)
    # Khi bấm phím Space thoát tool -> Callback draw ngừng chạy -> MÀU CHỈ ẨN 100%!
    # ==========================================================================
    def draw(view)
      # 1. TẤM VÁN ĐANG CHỌN: NỔI VIỀN XANH DƯƠNG ĐẬM (CHUẨN ẢNH 3)
      if @selected_panel && @selected_panel[:entity] && @selected_panel[:entity].valid?
        draw_panel_blue_outline(view, @selected_panel)
        # 2. VẼ TẤT CẢ CÁC CẠNH ĐÃ DÁN CHỈ CỦA TẤM NÀY BẰNG DẢI MÀU TRỰC QUAN
        draw_panel_applied_edge_bandings(view, @selected_panel, @panel_geom)
      end

      # 3. CẠNH ĐANG HOVER: HIGHLIGHT NỔI BẬT THEO MÀU LOẠI CHỈ
      if @selected_panel && @hover_face && @hover_face.valid?
        draw_hover_edge_highlight(view, @selected_panel, @hover_face, @hover_edge_key)
      end

      # 4. TẤM VÁN ĐANG RÊ CHUỘT QUA (KHI CHƯA CHỌN)
      if @selected_panel.nil? && @hover_panel && @hover_panel[:entity] && @hover_panel[:entity].valid?
        draw_hover_panel_preview(view, @hover_panel)
      end
    end

    # Vẽ viền xanh dương đậm bao quanh tấm ván đang chọn
    def draw_panel_blue_outline(view, panel_info)
      ent = panel_info[:entity]
      trans = panel_info[:total_trans]
      ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
      edges = ents.grep(Sketchup::Edge)
      return if edges.empty?

      pts = []
      edges.each do |e|
        pts << (trans * e.start.position)
        pts << (trans * e.end.position)
      end

      view.drawing_color = Sketchup::Color.new(0, 110, 255)
      view.line_width = 3
      view.line_stipple = ""
      view.draw(GL_LINES, pts)
    end

    # Vẽ các dải màu của các cạnh đã dán chỉ trên tấm ván đang chọn
    def draw_panel_applied_edge_bandings(view, panel_info, geom)
      return unless panel_info && geom

      ent = panel_info[:entity]
      trans = panel_info[:total_trans]
      bands = EdgeBandingEngine.get_panel_edge_bandings(ent)

      bands.each do |edge_key, band_data|
        next unless band_data && band_data['color']
        face = geom[:edge_faces][edge_key]
        next unless face && face.valid?

        col_hex = band_data['color'] || '#a3e635'
        c = Sketchup::Color.new(col_hex) rescue Sketchup::Color.new(163, 230, 53)

        # Lấy các đỉnh của face và đẩy nhẹ theo pháp tuyến để tránh trùng mặt
        norm = (trans.transform(face.normal)).normalize rescue face.normal
        offset_dist = 0.25.mm
        pts = face.outer_loop.vertices.map do |v|
          (trans * v.position) + (norm * offset_dist)
        end

        # Vẽ mặt phẳng dải màu chỉ
        view.drawing_color = c
        view.draw(GL_POLYGON, pts) rescue nil

        # Vẽ viền dải màu chỉ
        view.line_width = 2
        view.draw(GL_LINE_LOOP, pts)

        # Vẽ nhãn text thông số nẹp cạnh
        center_pt = (trans * face.bounds.center) + (norm * 1.5.mm)
        lbl = " #{band_data['name']} (#{band_data['thickness']}mm) "
        view.draw_text(center_pt, lbl, { size: 10, bold: true, color: c })
      end
    end

    # Highlight cạnh đang hover
    def draw_hover_edge_highlight(view, panel_info, face, edge_key)
      trans = panel_info[:total_trans]
      active_preset = EdgeBandingEngine.get_active_preset rescue {}
      hex_col = active_preset['color'] || '#a3e635'

      pts = []
      face.edges.each do |e|
        pts << (trans * e.start.position)
        pts << (trans * e.end.position)
      end

      c = Sketchup::Color.new(hex_col) rescue Sketchup::Color.new(163, 230, 53)
      view.drawing_color = c
      view.line_width = 5
      view.draw(GL_LINES, pts)

      center_pt = trans * face.bounds.center
      pname = active_preset['name'] || "1mm"
      lbl_text = " #{edge_key}: Dán #{pname} "
      view.draw_text(center_pt, lbl_text, { size: 11, bold: true, color: c })
    end

    def draw_hover_panel_preview(view, panel_info)
      ent = panel_info[:entity]
      trans = panel_info[:total_trans]
      ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
      edges = ents.grep(Sketchup::Edge)
      return if edges.empty?

      pts = []
      edges.each do |e|
        pts << (trans * e.start.position)
        pts << (trans * e.end.position)
      end

      view.drawing_color = Sketchup::Color.new(56, 189, 248, 140)
      view.line_width = 2
      view.line_stipple = "-"
      view.draw(GL_LINES, pts)
    end
  end
end
