# encoding: UTF-8
# ==============================================================================
# Chill AI Interior - Intersect Tool (Công Cụ Tương Tác 3D: Tiết Diện Giao Nhau)
# Chuẩn hoá 100% theo phong cách tương tác ABF:
#   Bước 1: Kích chuột chọn TẤM CẠNH (Tấm ván ăn ngàm, viền xanh dương nổi bật)
#           (Tự động nhận diện nếu người dùng đã chọn sẵn tấm trong SketchUp!)
#   Bước 2: Rê chuột vào TẤM MẶT (Tấm nhận rãnh) -> Hiện PREVIEW RÃNH KÉO DÀI 2 ĐẦU 3.5mm
#   Bước 3: Kích chọn TẤM MẶT -> Đục ngay rãnh _ABF_INTERSECT dính trên mặt tấm ván!
# Thiết kế: Anh Huy (The Architect) & Trợ Lý AI Lan
# ==============================================================================

require 'sketchup.rb'

module ChillAIInterior
  class IntersectTool
    attr_accessor :selected_panel, :extend_x, :offset, :depth, :layer_name

    def self.activate_tool(options = {})
      tool = new(options)
      Sketchup.active_model.select_tool(tool)
      tool
    end

    def initialize(options = {})
      @ip = nil
      @all_panels = []

      @selected_panel = nil
      @hover_panel = nil
      @preview_geom = nil

      preset = IntersectEngine.get_active_preset rescue {}
      ext_val   = options['extend_x'] || options[:extend_x] || preset['extend_x'] || preset[:extend_x] || 3.5
      off_val   = options['offset']   || options[:offset]   || preset['offset']   || preset[:offset]   || 0.3
      dep_val   = options['depth']    || options[:depth]    || preset['depth']    || preset[:depth]    || 8.0
      @extend_x = ext_val.to_f.mm
      @offset   = off_val.to_f.mm
      @depth    = dep_val.to_f.mm
      @layer_name = (options['layer'] || options[:layer] || preset['layer'] || preset[:layer] || 'QH_NGAM_MONG_X3').to_s

      @mouse_x = 0
      @mouse_y = 0
      @mouse_pt_3d = nil
    end

    def activate
      @model = Sketchup.active_model
      @view = @model.active_view
      @ip = Sketchup::InputPoint.new rescue nil
      refresh_panel_cache

      # 🌟 TỰ ĐỘNG NHẬN DIỆN NẾU ANH HUY ĐÃ CHỌN SẴN TẤM VÁN TRONG SKETCHUP
      if @selected_panel.nil? && @model && @model.selection && !@model.selection.empty?
        sel_ents = @model.selection.to_a
        direct = @all_panels.find { |p| sel_ents.include?(p[:entity]) }
        found_sel = direct || @all_panels.find { |p| p[:parent] && sel_ents.include?(p[:parent]) }
        if found_sel
          @selected_panel = found_sel
          pname = get_panel_display_name(@selected_panel)
          puts "[Chill AI IntersectTool] ✅ Tự động nhận diện Tấm ván đang chọn: [#{pname}]"
          AudioPlayer.play({ 'text' => "Đã chọn tấm #{pname}. Mời anh Huy rê chuột và kích chọn tấm nhận rãnh." }) rescue nil if defined?(AudioPlayer)
        end
      end

      update_status_bar
      @view.invalidate
    end

    def deactivate(view)
      view.invalidate rescue nil
    end

    def resume(view)
      @ip = Sketchup::InputPoint.new rescue nil
      refresh_panel_cache
      update_status_bar
      view.invalidate rescue nil
    end

    def get_panel_display_name(panel_info)
      return "Tấm ván" unless panel_info && panel_info[:entity]
      ent = panel_info[:entity]
      name = ent.name.to_s.strip
      if name.empty? && ent.respond_to?(:definition)
        name = ent.definition.name.to_s.strip
      end
      name.empty? ? "Tấm ván" : name
    end

    def update_status_bar
      if @selected_panel.nil?
        msg = "Chill AI [Tiết Diện Giao Nhau ABF] 👉 BƯỚC 1: Kích chuột trái chọn TẤM VÁN 1 (Cạnh ăn ngàm) | Kéo giãn 2 đầu: #{@extend_x.to_mm}mm | Hở: #{@offset.to_mm}mm"
      elsif @hover_panel && @hover_panel[:entity] != @selected_panel[:entity] && @preview_geom
        p1_name = get_panel_display_name(@selected_panel)
        p2_name = get_panel_display_name(@hover_panel)
        msg = "Chill AI [Tiết Diện Giao Nhau ABF] 👉 BƯỚC 2: Đã khớp giao ngàm [#{p1_name}] ⟷ [#{p2_name}] -> KÍCH CHUỘT ĐỂ TẠO RÃNH _ABF_INTERSECT | ESC: Hủy chọn"
      else
        p1_name = get_panel_display_name(@selected_panel)
        msg = "Chill AI [Tiết Diện Giao Nhau ABF] ✅ ĐÃ CHỌN [#{p1_name}] (Viền xanh) 👉 BƯỚC 2: Rê chuột và kích chọn TẤM NHẬN RÃNH kề cận | ESC: Hủy chọn"
      end
      Sketchup.status_text = msg
    end

    # Nạp toàn bộ danh sách tấm ván mộc trong mô hình
    def refresh_panel_cache
      return unless @model
      @all_panels = IntersectEngine.collect_all_panels rescue []
    end

    # Bắt tấm ván chuẩn xác 100% bằng PickHelper
    def get_picked_panel(x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)

      # 1. Quét từ path phân cấp sâu nhất lên gốc
      (0...ph.count).each do |idx|
        path = ph.path_at(idx)
        next unless path
        path.reverse_each do |item|
          found = @all_panels.find { |p| p[:entity] == item }
          return found if found
        end
      end

      # 2. Quét all_picked
      if ph.all_picked
        ph.all_picked.each do |item|
          found = @all_panels.find { |p| p[:entity] == item }
          return found if found
        end
      end

      # 3. Fallback best_picked
      best = ph.best_picked
      if best
        found = @all_panels.find { |p| p[:entity] == best }
        return found if found
        matched = @all_panels.find do |p|
          ent = p[:entity]
          if ent.is_a?(Sketchup::Group)
            ent.entities.include?(best)
          elsif ent.is_a?(Sketchup::ComponentInstance)
            ent.definition.entities.include?(best)
          else
            false
          end
        end
        return matched if matched
      end

      # 4. Fallback bằng tọa độ 3D InputPoint
      if @mouse_pt_3d
        @all_panels.find do |p|
          bb = IntersectEngine.get_world_bounds(p[:entity], p[:parent])
          bb.contains?(@mouse_pt_3d)
        end
      end
    end

    # ==========================================================================
    # CÁC SỰ KIỆN CHUỘT & BÀN PHÍM
    # ==========================================================================

    def onMouseMove(_flags, x, y, view)
      @mouse_x = x
      @mouse_y = y

      if @ip
        @ip.pick(view, x, y)
        @mouse_pt_3d = @ip.position
      end

      picked = get_picked_panel(x, y, view)

      if @selected_panel.nil?
        if picked != @hover_panel
          @hover_panel = picked
          update_status_bar
          view.invalidate
        end
      else
        if picked && picked[:entity] != @selected_panel[:entity]
          if picked != @hover_panel
            @hover_panel = picked
            opts = { 'extend_x' => @extend_x.to_mm, 'offset' => @offset.to_mm, 'depth' => @depth.to_mm, 'layer' => @layer_name, extend_x: @extend_x, offset: @offset, depth: @depth, layer: @layer_name }
            @preview_geom = IntersectEngine.auto_detect_intersection(@selected_panel, @hover_panel, opts)
            update_status_bar
            view.invalidate
          end
        elsif @hover_panel
          @hover_panel = nil
          @preview_geom = nil
          update_status_bar
          view.invalidate
        end
      end
    rescue => e
      puts "[Chill AI IntersectTool onMouseMove Error]: #{e.message}"
    end

    def onLButtonDown(_flags, x, y, view)
      if @ip
        @ip.pick(view, x, y)
        @mouse_pt_3d = @ip.position
      end

      picked = get_picked_panel(x, y, view)

      if @selected_panel.nil?
        # BƯỚC 1: Chọn Tấm Ván 1
        if picked
          @selected_panel = picked
          pname = get_panel_display_name(@selected_panel)
          update_status_bar
          view.invalidate
          AudioPlayer.play({ 'text' => "Đã chọn tấm #{pname}. Mời anh Huy rê chuột và kích chọn tấm tiếp xúc nhận rãnh." }) rescue nil if defined?(AudioPlayer)
        else
          Sketchup.status_text = "Chill AI: Chưa bắt được tấm ván. Mời anh Huy kích chuột vào tấm ván mộc."
        end
      else
        # BƯỚC 2: Kích chọn Tấm Ván 2 -> Thi công tạo rãnh
        if picked && picked[:entity] != @selected_panel[:entity]
          opts = { 'extend_x' => @extend_x.to_mm, 'offset' => @offset.to_mm, 'depth' => @depth.to_mm, 'layer' => @layer_name, extend_x: @extend_x, offset: @offset, depth: @depth, layer: @layer_name }
          geom = IntersectEngine.auto_detect_intersection(@selected_panel, picked, opts)
          if geom
            model = Sketchup.active_model
            model.start_operation("Chill AI - Tạo Tiết Diện Giao Nhau (3D Tool)", true)
            res = IntersectEngine.apply_intersection(geom, opts)
            if res
              model.commit_operation
              view.invalidate
              AudioPlayer.play({ 'text' => "Đã tạo rãnh tiết diện ngàm âm dương kéo dài hai đầu thành công cho anh Huy rồi nhé!" }) rescue nil if defined?(AudioPlayer)
            else
              model.abort_operation rescue nil
              Sketchup.status_text = "Chill AI: Không thể tạo rãnh giao nhau trên tấm ván này."
            end
          else
            Sketchup.status_text = "Chill AI: Chưa phát hiện vị trí tiếp giáp giữa 2 tấm ván này."
          end
          @hover_panel = nil
          @preview_geom = nil
          update_status_bar
        elsif picked && picked[:entity] == @selected_panel[:entity]
          # Kích lại vào chính nó -> Hủy chọn
          @selected_panel = nil
          @preview_geom = nil
          update_status_bar
          view.invalidate
        else
          # Kích ra khoảng trống -> Hủy chọn
          @selected_panel = nil
          @preview_geom = nil
          update_status_bar
          view.invalidate
        end
      end
    rescue => e
      puts "[Chill AI IntersectTool onLButtonDown Error]: #{e.message}"
    end

    def onKeyDown(key, _repeat, _flags, view)
      case key
      when 27, 32 # Phím ESC hoặc Phím Space
        if @selected_panel
          @selected_panel = nil
          @hover_panel = nil
          @preview_geom = nil
          update_status_bar
          view.invalidate
        else
          Sketchup.send_action("selectSelectionTool:")
        end
      end
    end

    # ==========================================================================
    # VẼ TOÀN BỘ PREVIEW & TƯƠNG TÁC 3D TRÊN VIEWPORT
    # ==========================================================================
    def draw(view)
      draw_cursor_tooltip(view) rescue nil

      # 1. NỔI BẬT TẤM ĐÃ CHỌN (Khung viền màu xanh dương sáng `#0077ff` chuẩn ABF)
      if @selected_panel && @selected_panel[:entity].valid?
        bb = IntersectEngine.get_world_bounds(@selected_panel[:entity], @selected_panel[:parent])
        wire_lines = get_bb_wireframe_lines(bb)
        view.drawing_color = Sketchup::Color.new(0, 119, 255) # Blue neon ABF
        view.line_width = 3
        view.line_stipple = ""
        view.draw(GL_LINES, wire_lines)
      end

      # NỔI BẬT TẤM ĐANG RÊ CHUỘT (Khung viền nét đứt màu cam)
      if @hover_panel && @hover_panel[:entity].valid? && (@selected_panel.nil? || @hover_panel[:entity] != @selected_panel[:entity])
        bb = IntersectEngine.get_world_bounds(@hover_panel[:entity], @hover_panel[:parent])
        wire_lines = get_bb_wireframe_lines(bb)
        view.drawing_color = Sketchup::Color.new(245, 158, 11) # Orange preview
        view.line_width = 2
        view.line_stipple = "-"
        view.draw(GL_LINES, wire_lines)
      end

      # 2. VẼ PREVIEW RÃNH TIẾT DIỆN GIAO NHAU (Có kéo giãn 2 đầu 3.5mm màu cam vàng)
      if @preview_geom && @preview_geom[:world_points]
        pts = @preview_geom[:world_points]
        color_groove = Sketchup::Color.new(245, 158, 11) # Cam vàng

        lines = [
          pts[0], pts[1],
          pts[1], pts[2],
          pts[2], pts[3],
          pts[3], pts[0]
        ]

        view.drawing_color = color_groove
        view.line_width = 3
        view.line_stipple = "-"
        view.draw(GL_LINES, lines)

        # 4 điểm góc thể hiện rõ đoạn thò ra ngoài
        view.draw_points(pts, 10, 2, color_groove)

        # Nếu có đường tim ở giữa
        if @preview_geom[:center_line]
          view.drawing_color = Sketchup::Color.new(239, 68, 68) # Đỏ tim rãnh
          view.line_width = 2
          view.line_stipple = "."
          view.draw(GL_LINES, @preview_geom[:center_line])
        end
      end
    rescue => e
      puts "[Chill AI IntersectTool Draw Error]: #{e.message}"
    end

    def get_bb_wireframe_lines(bb)
      corners = (0..7).map { |i| bb.corner(i) }
      lines = []
      pairs = [
        [0, 1], [1, 3], [3, 2], [2, 0],
        [4, 5], [5, 7], [7, 6], [6, 4],
        [0, 4], [1, 5], [2, 6], [3, 7]
      ]
      pairs.each do |i, j|
        lines << corners[i]
        lines << corners[j]
      end
      lines
    end

    def draw_cursor_tooltip(view)
      return if @mouse_x == 0 && @mouse_y == 0
      pt = Geom::Point3d.new(@mouse_x + 18, @mouse_y + 18, 0)

      if @selected_panel.nil?
        if @hover_panel
          pname = get_panel_display_name(@hover_panel)
          view.draw_text(pt, "👉 Kích chuột để chọn [#{pname}] (Cạnh ngàm)", { color: Sketchup::Color.new(0, 150, 255), size: 12, bold: true })
        else
          view.draw_text(pt, "👉 BƯỚC 1: Kích chuột chọn TẤM CẠNH ĂN NGÀM", { color: Sketchup::Color.new(200, 210, 225), size: 11 })
        end
      else
        p1_name = get_panel_display_name(@selected_panel)
        if @hover_panel && @hover_panel[:entity] != @selected_panel[:entity] && @preview_geom
          p2_name = get_panel_display_name(@hover_panel)
          len_mm = @preview_geom[:groove_length].to_mm.round(1)
          w_mm = @preview_geom[:groove_width].to_mm.round(1)
          view.draw_text(pt, "👉 BƯỚC 2: Kích chọn [#{p2_name}] để tạo rãnh [#{len_mm}x#{w_mm}mm, nới 2 đầu #{@extend_x.to_mm}mm]!", { color: Sketchup::Color.new(245, 158, 11), size: 12, bold: true })
        else
          view.draw_text(pt, "👉 BƯỚC 2: Rê chuột chọn TẤM NHẬN RÃNH kề cận", { color: Sketchup::Color.new(200, 210, 225), size: 11 })
        end
      end
    end
  end
end
