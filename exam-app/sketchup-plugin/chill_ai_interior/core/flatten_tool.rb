# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Flatten Tool (Công Cụ Tương Tác 3D: Trải Phẳng Bề Mặt)
# Chuẩn hoá 100% theo giao diện & trải nghiệm tương tác Ảnh 3 của anh Huy:
#   1. Rê chuột vào tấm ván bo cong: Tự động bắt dính và nhận diện mặt cong
#   2. Bề mặt cong nổi bật dải màu xanh Cyan (Lưới chấm Stipple Highlight)
#   3. Xuất hiện huy hiệu nổi (Tooltip) tại đầu con trỏ chuột: [HỢP LỆ]
#   4. Hiện 2 đường gióng tiếp tuyến đỏ nét đứt chỉ hướng duỗi phẳng của tấm ván
#   5. Nhận diện MẶT TRƯỚC (Lồi) & MẶT SAU (Lõm):
#      - Phím TAB hoặc Phím F: Đảo qua lại giữa Mặt Trước & Mặt Sau
#   6. Kích chuột trái: Trải phẳng ngay lập tức thành tấm ván CNC kèm cữ dưỡng!
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class FlattenTool
    attr_accessor :target_side, :hover_face, :hover_entity, :hover_analysis

    def self.current_tool
      @current_tool
    end

    def self.activate_tool(options = {})
      tool = new(options)
      @current_tool = tool
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(options = {})
      @options = options || {}
      @target_side = (@options[:bend_side] || @options['bend_side'] || 'inside').to_sym # :inside hoặc :outside

      @hover_face = nil
      @hover_entity = nil
      @hover_trans = nil
      @hover_analysis = nil

      @mouse_x = 0
      @mouse_y = 0

      FlattenEngine.get_config if defined?(FlattenEngine)
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      @ip = Sketchup::InputPoint.new rescue nil

      @hover_face = nil
      @hover_entity = nil
      @hover_trans = nil
      @hover_analysis = nil

      update_status_bar
      puts "[Chill AI FlattenTool] 🎯 Đã kích hoạt công cụ Trải Phẳng Bề Mặt (Chuẩn UniTool)."
      AudioPlayer.play({ 'text' => "Đã bật công cụ trải phẳng. Mời anh Huy rê chuột chọn mặt ván bo cong nhé." }) rescue nil if defined?(AudioPlayer)

      # Kiểm tra nếu đang chọn sẵn tấm ván trong selection
      check_existing_selection

      @view.invalidate
    end

    def deactivate(view)
      @hover_face = nil
      @hover_entity = nil
      @hover_trans = nil
      @hover_analysis = nil
      view.invalidate rescue nil
    end

    def resume(view)
      update_status_bar
      view.invalidate rescue nil
    end

    def check_existing_selection
      return unless @model && @model.selection && !@model.selection.empty?
      target = @model.selection.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if target
        ents = target.is_a?(Sketchup::Group) ? target.entities : target.definition.entities
        curved_f = ents.grep(Sketchup::Face).find { |f| f.edges.any? { |e| e.smooth? || e.soft? } }
        if curved_f
          @hover_entity = target
          @hover_trans = target.transformation
          @hover_face = curved_f
          @hover_analysis = FlattenEngine.analyze_curved_surface(curved_f, @hover_trans) if defined?(FlattenEngine)
        end
      end
    end

    def update_status_bar
      side_text = (@target_side == :inside) ? "MẶT TRONG (Lõm - Giấu rãnh bên trong)" : "MẶT NGOÀI (Lồi - Phay rãnh mặt ngoài)"
      if @hover_face && @hover_analysis && @hover_analysis[:valid]
        pname = @hover_entity ? @hover_entity.name : "Tấm ván bo cong"
        pname = "Tấm ván" if pname.to_s.empty?
        w_mm = @hover_analysis[:unrolled_width].to_mm.round
        h_mm = @hover_analysis[:height].to_mm.round
        Sketchup.status_text = "Chill AI [Trải Phẳng] 🎯 Đang chọn [#{pname}] (#{w_mm}x#{h_mm}mm) | Đang uốn: [#{side_text}] 👉 KÍCH CHUỘT ĐỂ TRẢI PHẲNG | Phím TAB/F: Đổi Mặt | Phím Space: Thoát"
      else
        Sketchup.status_text = "Chill AI [Trải Phẳng] 👉 RÊ CHUỘT LÊN MẶT VÁN BO CONG | Đang chọn uốn: [#{side_text}] | Phím TAB: Đổi Mặt Trước/Sau | Phím Space: Thoát"
      end
    end

    # ==========================================================================
    # SỰ KIỆN CHUỘT
    # ==========================================================================
    def onMouseMove(flags, x, y, view)
      @mouse_x = x
      @mouse_y = y

      picked_info = find_curved_face_at(x, y, view)

      if picked_info
        if picked_info[:face] != @hover_face
          @hover_face = picked_info[:face]
          @hover_entity = picked_info[:entity]
          @hover_trans = picked_info[:total_trans]
          @hover_analysis = FlattenEngine.analyze_curved_surface(@hover_face, @hover_trans) if defined?(FlattenEngine)
          update_status_bar
          view.invalidate
        end
      else
        if @hover_face
          @hover_face = nil
          @hover_entity = nil
          @hover_trans = nil
          @hover_analysis = nil
          update_status_bar
          view.invalidate
        end
      end
    end

    def onLButtonDown(flags, x, y, view)
      if @hover_face && @hover_entity && @hover_analysis && @hover_analysis[:valid]
        cfg = FlattenEngine.get_config rescue {}
        options = cfg.merge({
          'bend_side' => @target_side.to_s
        })

        res = FlattenEngine.flatten_curved_face(@hover_face, @hover_entity, @hover_trans, options)

        if res && res['status'] == 'success'
          Sketchup.status_text = "Chill AI: ✅ #{res['message']}"
          # Thông báo lên giao diện chính nếu đang mở
          dialog = WindowManager.dialog rescue nil
          if dialog && dialog.visible?
            dialog.execute_script("if (window.ChillAI && window.ChillAI.onFlattenCompleted) { window.ChillAI.onFlattenCompleted(#{res.to_json}); }") rescue nil
          end
        else
          err_msg = res ? res['message'] : 'Không thể trải phẳng tấm ván'
          UI.messagebox("Lỗi trải phẳng: #{err_msg}")
        end

        view.invalidate
      end
    end

    # Phím TAB hoặc Phím F để đảo qua lại giữa Mặt Trước & Mặt Sau
    def onKeyDown(key, _repeat, _flags, view)
      case key
      when 9, 70, 102 # Phím TAB (9) hoặc Phím F (70, 102)
        toggle_side
        view.invalidate
        return true

      when 27, 32 # Phím ESC (27) hoặc Phím Space (32)
        Sketchup.send_action("selectSelectionTool:")
        return true
      end

      false
    end

    def toggle_side
      @target_side = (@target_side == :inside) ? :outside : :inside
      side_name = (@target_side == :inside) ? "Mặt Trong (Lõm)" : "Mặt Ngoài (Lồi)"
      puts "[Chill AI FlattenTool] 🔄 Đã đổi chế độ uốn sang: [#{side_name}]"
      AudioPlayer.play({ 'text' => "Đã chuyển sang #{side_name}." }) rescue nil if defined?(AudioPlayer)
      update_status_bar
    end

    # ==========================================================================
    # TÌM KIẾM MẶT CONG DƯỚI CON TRỎ CHUỘT
    # ==========================================================================
    def find_curved_face_at(x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)

      (0...ph.count).each do |idx|
        leaf = ph.leaf_at(idx)
        path = ph.path_at(idx)
        next unless leaf && leaf.is_a?(Sketchup::Face) && path

        # Tìm group hoặc component cha
        ent = path.reverse.find { |n| n.is_a?(Sketchup::Group) || n.is_a?(Sketchup::ComponentInstance) }
        next unless ent

        # Tính toán ma trận toạ độ tổng hợp
        accum_trans = Geom::Transformation.new
        path.each do |node|
          accum_trans = accum_trans * node.transformation if node.respond_to?(:transformation)
          break if node == ent
        end

        # Kiểm tra xem face này có phải là mặt cong hoặc nằm kề mặt cong không
        is_curved = leaf.edges.any? { |e| e.smooth? || e.soft? }
        return { face: leaf, entity: ent, total_trans: accum_trans, path: path } if is_curved

        # Hoặc nếu là mặt phẳng tiếp giáp với mặt cong
        has_curve_neighbor = leaf.edges.any? do |e|
          e.faces.any? { |nf| nf != leaf && nf.edges.any? { |ne| ne.smooth? || ne.soft? } }
        end
        return { face: leaf, entity: ent, total_trans: accum_trans, path: path } if has_curve_neighbor
      end

      nil
    end

    # ==========================================================================
    # 🎨 VẼ TƯƠNG TÁC 3D TRÊN VIEWPORT (CHUẨN 100% ẢNH 3 CỦA ANH HUY)
    # ==========================================================================
    def draw(view)
      return unless @hover_face && @hover_analysis && @hover_analysis[:valid] && @hover_trans

      # 1. TÔ SÁNG MẶT CONG BẰNG MÀU XANH CYAN (LƯỚI CHẤM NHƯ ẢNH 3)
      draw_curved_surface_highlight(view)

      # 2. VẼ 2 ĐƯỜNG TIẾP TUYẾN ĐỎ NÉT ĐỨT (RED DASHED LINES NHƯ ẢNH 3)
      draw_red_tangent_lines(view)

      # 3. VẼ HUY HIỆU NỔI [HỢP LỆ] CẠNH CON TRỎ CHUỘT
      draw_valid_tooltip_badge(view)
    end

    def draw_curved_surface_highlight(view)
      faces = @hover_analysis[:faces] || [@hover_face]
      trans = @hover_trans

      # Màu Cyan trong suốt có độ sáng cao (#00e5ff)
      cyan_fill = Sketchup::Color.new(0, 220, 255, 140)
      cyan_edge = Sketchup::Color.new(0, 240, 255, 230)

      faces.each do |f|
        next unless f.valid?
        # Offset nhẹ 0.4mm theo hướng pháp tuyến để tránh hiện tượng z-fighting
        norm = (trans.transform(f.normal)).normalize rescue f.normal
        offset_v = norm * 0.4.mm

        # Lấy các điểm đỉnh của face
        pts = f.outer_loop.vertices.map { |v| (trans * v.position) + offset_v }
        next if pts.length < 3

        # Vẽ vùng mặt highlight
        view.drawing_color = cyan_fill
        view.draw(GL_POLYGON, pts)

        # Vẽ viền ngoài sắc nét
        view.drawing_color = cyan_edge
        view.line_width = 1.5
        view.line_stipple = ""
        loop_lines = []
        pts.each_with_index do |p, i|
          loop_lines << p
          loop_lines << pts[(i + 1) % pts.length]
        end
        view.draw(GL_LINES, loop_lines)
      end
    end

    def draw_red_tangent_lines(view)
      tangent_pts = @hover_analysis[:tangent_lines]
      return unless tangent_pts && !tangent_pts.empty?

      # Màu đỏ tươi nét đứt chuẩn như Ảnh 3 của anh Huy
      view.drawing_color = Sketchup::Color.new(239, 68, 68) # Red #ef4444
      view.line_width = 2
      view.line_stipple = "-" # Nét đứt (Dashed line)
      view.draw(GL_LINES, tangent_pts)
    end

    def draw_valid_tooltip_badge(view)
      return if @mouse_x == 0 && @mouse_y == 0

      # Tọa độ hiển thị huy hiệu (ngay cạnh mũi tên con trỏ chuột)
      pt = Geom::Point3d.new(@mouse_x + 18, @mouse_y + 14, 0)

      is_cvx = @hover_analysis[:is_convex]
      side_txt = (@target_side == :inside) ? "Mặt Trong (Lõm)" : "Mặt Ngoài (Lồi)"

      # Chuẩn huy hiệu "Hợp Lệ" (Ảnh 3)
      badge_text = "Hợp Lệ  [#{side_txt}]"
      hint_text  = "👉 Click: Trải phẳng ván  |  Phím TAB: Đổi mặt"

      # Vẽ chữ "Hợp Lệ" nổi bật
      view.draw_text(pt, badge_text, {
        color: Sketchup::Color.new(14, 165, 233), # Sky Blue
        size: 12,
        bold: true
      })

      pt_hint = Geom::Point3d.new(@mouse_x + 18, @mouse_y + 32, 0)
      view.draw_text(pt_hint, hint_text, {
        color: Sketchup::Color.new(226, 232, 240), # Slate 200
        size: 10
      })
    end
  end
end
