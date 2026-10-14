# TỔNG QUAN CHỨC NĂNG HỆ THỐNG
## Plugin SketchUp AI & Hệ sinh thái Thiết kế - Sản xuất Nội thất Thông minh

---

### I. MỤC TIÊU SẢN PHẨM & ĐỐI TƯỢNG NGƯỜI DÙNG

#### 1. Mục tiêu tổng quát
Xây dựng giải pháp tự động hóa toàn diện quy trình thiết kế và sản xuất thi công nội thất thông qua Plugin tích hợp Trí tuệ nhân tạo (AI) chạy trên nền tảng Trimble SketchUp. Hệ thống kết nối liền mạch từ việc nhận diện ảnh mẫu thành mô hình 3D, tạo cấu kiện động thông minh, bóc tách xuất file G-Code cho máy cắt CNC, cho đến tương tác tư vấn với trợ lý ảo 2D và sàn giao dịch (Marketplace).

#### 2. Đối tượng người dùng mục tiêu (Target Users)
* **Kỹ thuật viên vẽ CNC & Vận hành xưởng:** Tự động hóa khâu bóc tách khối 3D, sắp xếp tấm ván (nesting) và xuất file G-Code cắt tự động, giảm thiểu tối đa sai sót kỹ thuật và hao hụt vật liệu.
* **Kỹ sư & Kiến trúc sư thiết kế nội thất:** Rút ngắn thời gian dựng hình 3D từ ảnh chụp/ý tưởng; tự động gán hàm tham số Dynamic Component mà không cần thiết lập thủ công phức tạp.
* **Chủ xưởng sản xuất nội thất:** Chuẩn hóa quy trình sản xuất từ bản vẽ đến máy gia công; nâng cao năng lực sản xuất và dễ dàng tiếp cận nguồn khách hàng mới qua sàn giao dịch.
* **Khách hàng cá nhân & Cộng đồng làm đồ DIY:** Trực quan hóa ý tưởng nội thất căn nhà của mình; tự tùy chỉnh kích thước, màu sắc theo ý muốn; nhận tư vấn chuyên sâu từ AI và gửi file trực tiếp cho xưởng gia công với chi phí tối ưu.

---

### II. HỆ THỐNG CÁC TÍNH NĂNG CHÍNH (CORE MODULES)

#### 1. Module AI Vision: Quét ảnh & Tái tạo mô hình 3D (Image-to-3D)
Người dùng có thể tải lên ảnh chụp thực tế từ điện thoại hoặc ảnh sưu tầm trên Internet về bất kỳ sản phẩm nội thất nào (bàn, ghế, tủ quần áo, kệ tivi...). AI tiến hành nhận diện loại vật thể, phân tích cấu tạo không gian và dựng mô hình 3D hoàn chỉnh trên SketchUp theo 2 chế độ linh hoạt:
* **a) Chế độ Mặc định (Standard Mode):** Tự động áp dụng các thông số kích thước chuẩn nhân trắc học đã nạp sẵn trong cơ sở dữ liệu hệ thống (Ví dụ: Bàn làm việc tiêu chuẩn Cao 750mm x Rộng 600mm x Dài 1200mm).
* **b) Chế độ Tùy chỉnh (Custom Mode):** Cung cấp bảng điền thông số trực quan cho phép người dùng tùy chỉnh chiều Cao, Rộng, Dài, độ dày ván, bán kính bo góc và lựa chọn linh hoạt các phụ kiện đi kèm (loại chân gỗ/chân sắt, bản lề, ray trượt giảm chấn, tay nắm...) so với hình ảnh gốc.

#### 2. Module CAM: Bóc tách 2D & Xuất mã gia công G-Code cho máy CNC
Đóng vai trò cầu nối khép kín từ bản vẽ thiết kế 3D đến dây chuyền sản xuất:
* Tự động bóc tách khối 3D và trải phẳng từng chi tiết dạng tấm ván 2D (Unfold/Nesting) tối ưu diện tích cắt.
* Tính toán đường chạy dao phay/khoan và xuất ra file mã lệnh gia công định dạng G-Code tiêu chuẩn.
* Người vận hành chỉ cần cắm trực tiếp USB chứa file G-Code vào máy cắt phay CNC tại xưởng để cắt phôi gỗ/ván công nghiệp tự động với độ chính xác tuyệt đối.

#### 3. Module AI Dynamic Component Builder (Cấu kiện động thông minh)
Tự động hóa hoàn toàn việc tạo lập Dynamic Components trong SketchUp bằng AI:
* AI tự động lập trình và gán các hàm thuộc tính toán học (`LenX`, `LenY`, `LenZ`, `Material`, `Copies`, `RotX/Y/Z`, `OnClick animation`...).
* Cho phép người dùng kéo giãn kích thước tổng thể mà các chi tiết kỹ thuật tiêu chuẩn (khoảng cách mộng ghép, lỗ khoan cam chốt, chỉ nẹp dán cạnh, khe hở cánh tủ) vẫn giữ nguyên tỷ lệ cấu tạo chính xác.

#### 4. Trợ lý ảo AI 2D kể chuyện & Tư vấn nội thất thông minh
Tích hợp Chatbot AI hiển thị dưới dạng nhân vật ảo 2D sinh động, đóng vai trò người dẫn dắt (như nhân vật kể chuyện trong game):
* **Trải nghiệm tương tác lôi cuốn:** Trình bày sinh động, dễ hiểu về toàn bộ quy trình thiết kế - sản xuất một công trình nội thất từ A-Z.
* **Tư vấn chuyên môn sâu:** Đóng vai trò chuyên gia nội thất cao cấp, có khả năng đọc hiểu tài liệu kỹ thuật (catalog phong cách, bảng màu, quy tắc bố trí không gian, vật liệu vật lý) và suy luận đa bước để gợi ý phương án tối ưu về thẩm mỹ, phong thủy và chi phí.
* **Liên thông trực tiếp với Plugin:** Sau khi trò chuyện và chốt phương án với người dùng, chatbot tự động liên thông với Plugin SketchUp để dựng mô hình sản phẩm đúng với giải pháp đã đồng thuận.

#### 5. Module Quản lý Dự án & Lưu trữ Lịch sử tư vấn (Project Cloud Management)
* Lưu trữ an toàn trên đám mây toàn bộ lịch sử tư vấn, hội thoại với AI, hình ảnh nguồn và thông số kỹ thuật của từng dự án.
* Hỗ trợ người dùng quản lý nhiều không gian/căn phòng cùng lúc, dễ dàng xem lại, xuất báo cáo hoặc tái sử dụng các phiên bản thiết kế trước đó.

#### 6. Module Xác thực & Quản trị Người dùng (User Management & Security)
* Hệ thống đăng ký, đăng nhập an toàn (hỗ trợ Email/Mật khẩu, Google Account, SSO).
* Bảo mật dữ liệu cá nhân theo tiêu chuẩn mã hóa.
* Phân quyền rõ ràng theo vai trò tài khoản: Khách hàng DIY, Kỹ sư thiết kế, Đối tác xưởng CNC.

#### 7. Module Marketplace & Cổng Thanh toán trực tuyến
* **Marketplace (Chợ số):** Sàn giao dịch chia sẻ và thương mại hóa các mẫu thiết kế 3D, thư viện Dynamic Components độc quyền và các gói file G-Code cắt sẵn.
* **Kết nối sản xuất gia công:** Cơ chế kết nối thông minh giữa khách hàng cá nhân (người cần gia công) với các xưởng CNC uy tín lân cận.
* **Thanh toán tích hợp:** Tích hợp các cổng thanh toán bảo mật (VNPay, MoMo, Thẻ tín dụng/Ghi nợ, chuyển khoản QR) giúp giao dịch diễn ra nhanh chóng, minh bạch.

---

### III. TỔNG KẾT QUY TRÌNH VẬN HÀNH (WORKFLOW)
1. **Giai đoạn 1 (Ý tưởng & Tư vấn):** Người dùng trò chuyện với Trợ lý ảo 2D để định hình phong cách, hoặc tải ảnh món đồ nội thất mong muốn lên hệ thống.
2. **Giai đoạn 2 (Dựng hình 3D & Tùy biến):** AI nhận diện ảnh, áp dụng kích thước mặc định hoặc tùy chỉnh theo nhu cầu, tự động sinh mô hình 3D và cấu kiện động (Dynamic Component) trực tiếp trên SketchUp.
3. **Giai đoạn 3 (Bóc tách & Xuất G-Code):** Plugin tự động bóc tách bản vẽ 2D dạng tấm và xuất mã gia công G-Code tối ưu đường dao cắt.
4. **Giai đoạn 4 (Thi công & Hoàn thiện):** Chuyển file G-Code qua USB trực tiếp vào máy CNC để sản xuất, hoặc đặt xưởng gia công thông qua Marketplace nội bộ.
