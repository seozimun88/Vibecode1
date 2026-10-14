# KIẾN TRÚC HỆ THỐNG & LUỒNG QUY TRÌNH (FLOWS)
## PLUGIN SKETCHUP AI & HỆ SINH THÁI NỘI THẤT CHILL DECOR

Tài liệu này mô tả chi tiết kiến trúc kỹ thuật và các luồng quy trình vận hành chính của hệ thống Plugin AI tích hợp trên Trimble SketchUp.

---

### 1. KIẾN TRÚC TỔNG THỂ (SYSTEM ARCHITECTURE)

```mermaid
flowchart TD
    subgraph Client["Giao Diện Người Dùng (UI/UX)"]
        UI["UI::HtmlDialog / CEF Webview"]
        Canvas3D["Three.js Realtime 3D Viewport"]
        Canvas2D["2D Canvas Nesting Visualizer"]
        Avatar2D["Nhân Vật Ảo 2D (Lyly Storytelling)"]
    end

    subgraph Bridge["Cầu Nối Hai Chiều (Bi-directional Bridge)"]
        JS_Bridge["window.sketchup Callbacks"]
        Ruby_Bridge["HtmlDialog.add_action_callback"]
    end

    subgraph CoreRuby["Lõi Xử Lý Plugin SketchUp (Ruby API)"]
        Loader["chill_ai_interior.rb & main.rb"]
        ModelGen["ModelGenerator (Dựng Hình 3D & Vật Liệu)"]
        DC_Builder["DynamicComponentBuilder (Gán Thuộc Tính & Hàm Động)"]
        CAM_Engine["CamGCodeExporter (Bóc Tách Tấm & Sinh G-Code ISO)"]
    end

    subgraph Output["Đầu Ra Sản Phẩm & Thi Công"]
        SU_Model["Mô Hình 3D SketchUp (.skp)"]
        DC_Instance["Dynamic Component Thông Minh (Interact Click)"]
        GCode_File["File Cắt CNC G-Code (.nc / .gcode) -> Cắm USB Máy CNC"]
        Market["Marketplace & Xưởng Gia Công CNC"]
    end

    UI --> JS_Bridge
    JS_Bridge --> Ruby_Bridge
    Ruby_Bridge --> Loader
    Loader --> ModelGen
    Loader --> DC_Builder
    Loader --> CAM_Engine
    ModelGen --> SU_Model
    DC_Builder --> DC_Instance
    CAM_Engine --> GCode_File
    GCode_File --> Market
```

---

### 2. LUỒNG 1: QUÉT ẢNH TẠO 3D & 2 NÚT LỰA CHỌN KÍCH THƯỚC

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng / KTS
    participant UI as Giao diện Plugin (UI)
    participant AI as Bộ nhận diện AI Vision
    participant Ruby as ModelGenerator (SketchUp)

    User->>UI: Tải ảnh chụp món đồ nội thất (hoặc chọn ảnh mẫu)
    UI->>AI: Phân tích hình ảnh, kết cấu hình học
    AI-->>UI: Nhận diện: Tên đồ vật, loại sản phẩm, vật liệu đề xuất
    UI->>User: Hiển thị 2 nút bấm lựa chọn:
    alt Trường hợp a) Mặc định thông thường
        User->>UI: Chọn "Mặc định"
        UI->>UI: Nạp kích thước tiêu chuẩn nhân trắc học (vd: Bàn 1200x600x750mm)
    else Trường hợp b) Tùy chỉnh chi tiết
        User->>UI: Chọn "Tùy chỉnh"
        User->>UI: Điền bảng thông số: Dài, Rộng, Cao, độ dày ván, chân sắt/gỗ, ngăn kéo
    end
    User->>UI: Bấm "Xuất Mô Hình 3D Vào SketchUp"
    UI->>Ruby: Gửi JSON thông số qua bridge
    Ruby->>Ruby: Dựng hình khối, gán vật liệu, gán group chi tiết
    Ruby-->>UI: Báo hoàn tất & Zoom fit mô hình trên SketchUp
```

---

### 3. LUỒNG 2: SINH HÀM DYNAMIC COMPONENT TỰ ĐỘNG

```mermaid
flowchart LR
    A["Thông số kích thước (L, W, H, Thickness)"] --> B["DynamicComponentBuilder"]
    B --> C["Tạo Component Definition cấp Cha"]
    C --> D["Gán thuộc tính: LenX, LenY, LenZ (Component Options)"]
    D --> E["Tạo các Component con: Mặt bàn, Chân, Cánh tủ, Ngăn kéo"]
    E --> F["AI Gán Công Thức Toán Học:
    - Mat_Ban!LenX = Parent!LenX
    - Chan!LenZ = Parent!LenZ - Parent!Thickness
    - Canh_Tu!OnClick = ANIMATE('RotZ', 0, 90)"]
    F --> G["Kích hoạt $dc_observers.redraw_with_undo"]
    G --> H["Dynamic Component hoàn chỉnh:
    Co giãn tự do, click chuột mở cánh"]
```

---

### 4. LUỒNG 3: BÓC TÁCH 2D NESTING & XUẤT FILE G-CODE CẮM USB MÁY CNC

```mermaid
flowchart TD
    M1["Mô hình 3D trong SketchUp"] --> M2["Bóc tách danh sách chi tiết tấm (Parts List: Dài x Rộng x Dày)"]
    M2 --> M3["Thuật toán Shelf Bin-Packing (Xếp ván 2D)"]
    
    subgraph Nesting["Khổ Ván Chuẩn Công Nghiệp (1220 x 2440 mm)"]
        N1["Chừa lề mép biên 10mm"]
        N2["Khoảng cách mạch cắt dao phay: 6mm (Bit Kerf)"]
        N3["Tối ưu diện tích ván & tính tỉ lệ hiệu suất (Utilization %)"]
    end
    M3 --> Nesting

    Nesting --> G1["Bộ biên dịch mã lệnh CNC (G-Code Compiler)"]
    G1 --> G2["Pass 1: Phay phá 1/2 chiều dày ván (Z-9.0mm, F2400)"]
    G2 --> G3["Pass 2: Cắt đứt hoàn toàn phôi (Z-18.5mm, F2400)"]
    G3 --> G4["Xuất tệp G-Code chuẩn ISO (.nc / .gcode)"]
    G4 --> USB["Lưu file vào USB"]
    USB --> CNC["Cắm USB vào máy phay CNC tại xưởng gỗ -> Bấm cắt tự động"]
```

---

### 5. LUỒNG 4: TRỢ LÝ ẢO 2D KỂ CHUYỆN & TƯ VẤN NỘI THẤT

```mermaid
sequenceDiagram
    autonumber
    actor User as Khách hàng / Người làm DIY
    participant Avatar as Nhân vật ảo 2D (Lyly)
    participant KB as Cơ sở dữ liệu chuyên môn
    participant Plugin as Plugin SketchUp

    User->>Avatar: "Kể cho tôi quy trình làm 1 căn phòng nội thất từ A-Z"
    Avatar->>KB: Đọc quy trình chuyên môn (4 giai đoạn)
    Avatar-->>User: Kể chuyện tương tác 4 hồi (Cảm hứng -> Mô hình số -> Bóc tách CNC -> Thi công)
    
    User->>Avatar: "Tôi muốn làm bàn làm việc tối giản công thái học"
    Avatar->>KB: Tra cứu chuẩn nhân trắc học & phong cách Minimalist
    Avatar-->>User: Tư vấn kích thước 1400x700x750mm, MDF chống ẩm An Cường, chân sắt chữ U
    
    User->>Avatar: Bấm nút "Áp dụng thiết kế vào SketchUp"
    Avatar->>Plugin: Chuyển toàn bộ thông số đã chốt sang Plugin
    Plugin->>Plugin: Tự động dựng mô hình 3D trên màn hình SketchUp
```
