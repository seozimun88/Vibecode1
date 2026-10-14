# HƯỚNG DẪN CÀI ĐẶT & SỬ DỤNG PLUGIN CHILL AI INTERIOR
## Dành Cho Phần Mềm Trimble SketchUp (2020 - 2025) & Máy Cắt Gỗ CNC

---

### I. CÁC CÁCH CÀI ĐẶT VÀ TRẢI NGHIỆM

Bạn có thể sử dụng Plugin theo 3 cách cực kỳ linh hoạt:

#### 👉 Cách 1: Cài đặt trực tiếp qua file `.rbz` vào SketchUp (Khuyên Dùng)
1. Mở phần mềm **Trimble SketchUp** (hỗ trợ mọi phiên bản từ 2020 đến 2025).
2. Trên thanh menu trên cùng, chọn: **Extensions** (hoặc **Window**) ➔ **Extension Manager**.
3. Nhấp vào nút màu đỏ: **Install Extension** ở góc dưới bên trái.
4. Điều hướng và chọn tệp:  
   `D:\1.Chill Chill Decor\DU AN 1\Vibecode1\exam-app\sketchup-plugin\chill_ai_interior.rbz`
5. Nhấn **Open**. Sau khi cài xong, thanh công cụ **Chill AI Interior** và menu **Extensions ➔ Chill AI Interior** sẽ xuất hiện ngay lập tức trên màn hình SketchUp.

---

#### 👉 Cách 2: Copy trực tiếp vào thư mục Plugins của SketchUp
Nếu muốn cài đặt thủ công nhanh chóng:
1. Nhấn tổ hợp phím **`Windows + R`**, dán đoạn sau vào và ấn **Enter**:
   ```text
   %AppData%\SketchUp
   ```
2. Mở thư mục phiên bản SketchUp của bạn (Ví dụ: `SketchUp 2024\SketchUp\Plugins`).
3. Copy 2 mục sau từ thư mục dự án:
   - File: `chill_ai_interior.rb`
   - Thư mục: `chill_ai_interior/`
   ➔ Dán trực tiếp vào thư mục `Plugins` nói trên.
4. Mở lại SketchUp là Plugin đã sẵn sàng hoạt động.

---

#### 👉 Cách 3: Chạy thử nghiệm ngay trên Trình duyệt Web (Không cần mở SketchUp)
Bạn có thể mở và tương tác với giao diện 3D, trợ lý ảo 2D và máy bóc tách CNC ngay lập tức:
* Nhấp đúp chuột để mở trực tiếp tệp:  
  `D:\1.Chill Chill Decor\DU AN 1\Vibecode1\exam-app\sketchup-plugin\chill_ai_interior\ui\index.html`
* Chế độ Web Preview này tích hợp sẵn bộ mô phỏng 3D thời gian thực (Three.js), bộ giải thuật xếp ván 2D Nesting và tạo file G-Code tải về máy tính.

---

### II. HƯỚNG DẪN SỬ DỤNG CHI TIẾT CÁC TÍNH NĂNG

#### 1. Quét ảnh chụp tạo mô hình 3D (Image-to-3D)
1. Chọn tab **1. Quét Ảnh & Tạo 3D**.
2. Kéo thả bức ảnh món đồ nội thất (hoặc bấm vào các nút mẫu nhanh như *Bàn làm việc*, *Tủ quần áo*...).
3. AI sẽ tự động phân tích và đưa ra **2 lựa chọn kích thước**:
   - **a) Mặc định thông thường:** Áp dụng kích thước chuẩn nhân trắc học nạp sẵn (vd: Bàn cao 750mm x rộng 600mm x dài 1200mm).
   - **b) Tùy chỉnh chi tiết:** Hiện bảng form để bạn nhập kích thước mong muốn, chọn độ dày ván (17mm/18mm), kiểu chân sắt hay chân gỗ, số lượng ngăn kéo và phụ kiện ray trượt.
4. Bấm **"Xuất Mô Hình 3D Vào SketchUp"** ➔ Mô hình 3D sẽ xuất hiện ngay tại gốc tọa độ trong SketchUp.

#### 2. Tạo hàm Dynamic Component bằng AI
1. Nhấp nút **"Tạo Hàm Dynamic Component AI"**.
2. Plugin sẽ tự động đóng gói mô hình thành một khối linh kiện thông minh với các công thức toán học (`LenX`, `LenY`, `LenZ`).
3. Khi bạn co giãn kích thước bàn/tủ trong SketchUp, các chi tiết kỹ thuật (mộng ghép, chân bàn, độ dày ván) sẽ tự co giãn linh hoạt mà **không bao giờ bị méo mó tỉ lệ cấu tạo**.
4. Bạn có thể dùng công cụ **Interact Tool (Bàn tay)** của SketchUp để click vào cánh tủ/ngăn kéo và xem chuyển động đóng mở tự động.

#### 3. Bóc tách tấm 2D (Nesting) & Xuất File G-Code cho máy CNC
1. Chuyển sang tab **3. Bóc Tách & G-Code CNC**.
2. Thuật toán CAM tự động bóc tách các tấm thành phần, xếp phẳng lên khổ ván công nghiệp tiêu chuẩn **1220 x 2440 mm**, tính toán đường dao chừa mạch cắt 6mm.
3. Bảng thống kê hiển thị: Số lượng tấm ván, Hiệu suất xếp ván (%), Tổng chiều dài cắt (m) và thời gian gia công ước tính.
4. Bấm **"Lưu File G-Code Vào USB (Cắm Máy CNC)"**:
   - File xuất ra có định dạng `.nc` / `.gcode` chuẩn ISO quốc tế.
   - Bạn chỉ việc cắm trực tiếp USB chứa file này vào máy phay CNC (chạy NC-Studio, Mach3, Syntec, Weihong...) tại xưởng để cắt ván tự động.

#### 4. Trò chuyện cùng Trợ lý ảo AI 2D (Lyly)
1. Chuyển sang tab **4. Trợ Lý Ảo 2D**.
2. Bạn có thể trò chuyện với Lyly theo phong cách kể chuyện trong game để được nghe về:
   - Toàn bộ quy trình từ khúc gỗ thô đến khi ra đời một căn phòng nội thất hoàn mỹ.
   - Tư vấn phong cách (Scandinavian, Minimalist, Indochine, Japandi...).
   - Tư vấn chọn cốt gỗ (MDF lõi xanh chống ẩm An Cường hay Gỗ tự nhiên).
3. Sau khi thảo luận, Lyly sẽ cung cấp nút bấm để **tự động liên thông với Plugin và dựng mô hình theo phương án đã chốt**.

#### 5. Marketplace & Kết nối Xưởng sản xuất
* Người dùng DIY có thể chọn mua các mẫu 3D / G-Code có sẵn hoặc gửi trực tiếp file G-Code vừa bóc tách đến các xưởng CNC liên kết gần nhất để đặt cắt và giao hàng tận nhà.
