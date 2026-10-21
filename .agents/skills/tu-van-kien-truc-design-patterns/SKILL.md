---
name: tu-van-kien-truc-design-patterns
description: >-
  Thẩm định và tư vấn kiến trúc phần mềm, lựa chọn Design Pattern (dựa trên cẩm nang
  design-patterns-for-humans) cho người Vibecoding không chuyên. Đánh giá tính năng mới:
  Cần hay Không cần Pattern (ngăn chặn over-engineering, giữ đơn giản KISS), đề xuất Pattern
  phù hợp bằng ví dụ đời thường, phác thảo bản vẽ thư mục (Folder Blueprint) trước khi code.
  Kích hoạt khi: tính năng mới, task mới, tư vấn kiến trúc, design pattern, design-patterns-for-humans,
  có cần pattern không, cấu trúc thư mục, kiến trúc vibecode, refactor module, /tu-van-kien-truc-design-patterns.
---

# Tư Vấn Kiến Trúc & Design Patterns Cho Vibe Coder (Bản Dễ Hiểu)

> **Cẩm nang nền tảng:** Dựa trên triết lý tối giản của [design-patterns-for-humans](https://github.com/nilbuild/design-patterns-for-humans).
> **Đối tượng phục vụ:** Vibe Coder (người ra lệnh cho AI viết code, không cần giỏi cú pháp hay thuật toán phức tạp, nhưng cần tư duy kiến trúc để không bị nát dự án).

---

## 1. Triết Lý Vàng: "KISS Trước – Pattern Sau"

1. **KISS (Keep It Simple, Stupid):** Đơn giản là thượng sách. Nếu một tính năng chỉ cần một hàm 20–30 dòng nằm trong 1 file là giải quyết xong và không có nguy cơ mở rộng, **TUYỆT ĐỐI KHÔNG DÙNG PATTERN**.
2. **Chống "Dao mổ trâu giết gà" (Over-engineering):** Đừng tạo 5 file class/interface chỉ để cộng hai số hoặc gọi 1 API đơn lẻ.
3. **Chỉ dùng Pattern khi có "bằng chứng phạm tội":**
   - Bắt đầu xuất hiện chuỗi `if...else if...else` dài ngoằng để chọn cách xử lý.
   - Có từ 2 nhà cung cấp dịch vụ hoặc 2 phương thức trở lên (ví dụ: Momo, ZaloPay, VietQR).
   - Nhấn 1 nút nhưng hệ thống phải kích hoạt 4–5 tác vụ ngầm liên hoàn (gửi mail, trừ kho, báo bot, tích điểm).
   - Tích hợp dịch vụ bên ngoài có cấu trúc dữ liệu lạ hoắc không khớp với hệ thống của mình.

---

## 2. Ma Trận Quyết Định Nhanh (Decision Flowchart)

Khi người dùng đưa ra một tính năng/task mới, hãy tự hỏi các câu sau:

```text
Yêu cầu mới đến
  │
  ├── 1. Task có tuyến tính 1 chiều, dữ liệu cố định, chạy 1 lần?
  │     └──> ĐÁP ÁN: [KHÔNG CẦN PATTERN] ➜ Viết hàm đơn giản, sạch sẽ (KISS).
  │
  ├── 2. Có nhiều phương thức/thuật toán tương đương nhau cần tráo đổi linh hoạt? (Thanh toán, Tính ship, Đăng nhập...)
  │     └──> ĐÁP ÁN: [STRATEGY PATTERN] ➜ Tách mỗi phương thức thành 1 file riêng.
  │
  ├── 3. Có nhiều loại đối tượng cần sinh ra dựa theo tham số đầu vào? (Xuất PDF/Excel/CSV, Gửi Email/SMS/Zalo...)
  │     └──> ĐÁP ÁN: [FACTORY PATTERN] ➜ Tạo xưởng chế tạo chung, gọi tên là trả về đối tượng.
  │
  ├── 4. Muốn kết nối với API bên thứ 3 nhưng dữ liệu họ trả về không khớp chuẩn của mình? (KiotViet, Shopee, TikTok...)
  │     └──> ĐÁP ÁN: [ADAPTER PATTERN] ➜ Tạo củ sạc chuyển đổi chân cắm.
  │
  ├── 5. Quy trình phức tạp gồm 5-7 bước ngầm bên dưới, muốn giao diện chỉ cần gọi 1 hàm duy nhất?
  │     └──> ĐÁP ÁN: [FACADE PATTERN] ➜ Tạo quầy lễ tân một cửa che giấu sự phức tạp.
  │
  └── 6. Khi 1 sự kiện xảy ra, muốn nhiều bộ phận tự động nhận tin để hành động độc lập? (Có đơn mới -> Báo bot, Ghi sheet, Gửi mail)
        └──> ĐÁP ÁN: [OBSERVER PATTERN] ➜ Kênh bấm chuông theo dõi sự kiện.
```

---

## 3. Cẩm Nang 23 Design Patterns Dịch Sang Ngôn Ngữ Đời Thường

### Nhóm A: Creational (Tạo dựng đối tượng — Đẻ ra các khối)
* **Simple Factory (Xưởng thợ mộc):** Bạn bảo cần cái cửa gỗ, xưởng tự đóng và giao. Code không cần biết chi tiết thợ mộc cưa xẻ ra sao.
* **Factory Method (Nhượng quyền thương mại):** Giao quyền cho từng chi nhánh quyết định cách tuyển nhân viên hoặc làm món ăn đặc thù.
* **Abstract Factory (Cửa hàng nội thất đồng bộ):** Khi chọn "Nội thất gỗ hiện đại", nó tự động cho bạn bàn gỗ, ghế gỗ, tủ gỗ đồng bộ.
* **Builder (Làm bánh Burger / Build PC):** Khi tạo một thứ có quá nhiều tùy chọn (có phô mai không, mấy miếng thịt, thêm sốt gì). Thay vì truyền 10 tham số vào 1 hàm, bạn build từng bước: `.themThit().themPhoMai().hoanThanh()`.
* **Prototype (Nhân bản vô tính):** Khi tạo mới một vật thể rất tốn tài nguyên, ta copy từ một con cừu gốc Dolly đã cấu hình sẵn rồi sửa chút ít.
* **Singleton (Văn phòng Chủ tịch / Tổng đài 115):** Cả đất nước/ứng dụng chỉ có DUY NHẤT 1 cơ quan này tồn tại (ví dụ: kết nối Database, cấu hình App).

### Nhóm B: Structural (Cấu trúc — Ráp nối các khối)
* **Adapter (Củ sạc chuyển chân cắm du lịch):** Cắm phích dẹt vào ổ tròn. Dùng để bọc API bên ngoài về đúng chuẩn dự án của bạn.
* **Bridge (Công tắc đèn tách rời bóng đèn):** Đổi màu bóng đèn hay đổi loại công tắc đều không làm ảnh hưởng lẫn nhau.
* **Composite (Cây thư mục / Bó hoa):** Đối xử với 1 bông hoa hay cả bó hoa (nhiều bông) bằng cùng một cách (đều có hàm `tinhTien()`).
* **Decorator (Trà sữa thêm Topping):** Cốc trà sữa cơ bản, thích thêm trân châu thì bọc thêm 1 lớp, thêm pudding bọc thêm lớp nữa mà không cần tạo class "Trà sữa trân châu pudding".
* **Facade (Quầy lễ tân một cửa):** Bạn chỉ cần tới gặp lễ tân bảo "Tôi muốn làm thủ tục", lễ tân tự chạy đi xin chữ ký 5 phòng ban khác nhau cho bạn.
* **Proxy (Thẻ từ thang máy / Vệ sĩ):** Đứng chặn trước khi cho gặp người thật để kiểm tra quyền hạn hoặc lưu bộ nhớ đệm (caching).

### Nhóm C: Behavioral (Hành vi — Cách các khối nói chuyện với nhau)
* **Strategy (Túi cẩm nang chiến lược):** Đi làm bằng xe máy khi trời nắng, xe buýt khi trời mưa. Dùng cho thanh toán đa cổng, tính cước vận chuyển.
* **Observer (Đăng ký chuông YouTube):** YouTuber ra video mới, chuông reo báo cho tất cả người theo dõi. Dùng cho hệ thống sự kiện, webhook.
* **Command (Điều khiển TV từ xa):** Mỗi nút bấm là một lệnh độc lập, có thể lưu lịch sử để bấm nút "Undo" (Quay lại bước trước).
* **State (Màn hình điện thoại):** Khi khóa màn hình, bấm vào nút âm lượng chỉ sáng màn hình; khi đang mở khóa nghe nhạc, bấm nút đó lại tăng âm lượng.
* **Template Method (Quy trình pha trà và cà phê):** Đều đun nước -> đổ nước sôi -> rót ra cốc. Chỉ khác bước cho túi trà hay đổ bột cà phê.
* **Chain of Responsibility (Cấp bậc duyệt chi tiêu):** Dưới 1 triệu tổ trưởng duyệt, dưới 10 triệu giám đốc duyệt, trên 10 triệu chủ tịch duyệt.

---

## 4. Mẫu Trả Lời Khi Tư Vấn (BẮT BUỘC TUÂN THỦ FORMAT)

Mỗi khi người dùng đưa ra một task hoặc yêu cầu tính năng mới, AI **KHÔNG ĐƯỢC CODE NGAY**, mà phải trả lời theo đúng 4 phần sau:

```markdown
### 1. Đánh giá tính năng: [CÓ CẦN DÙNG PATTERN KHÔNG?]
- **Kết luận:** [CẦN] hoặc [KHÔNG CẦN - GIỮ ĐƠN GIẢN (KISS)]
- **Độ phức tạp:** [Đơn giản 1 chiều / Phức tạp đa nhánh]

### 2. Giải thích bình dân (Ví dụ đời thường):
- [Nếu KHÔNG CẦN]: "Task này giống như việc pha một cốc mì gói, chỉ cần đổ nước sôi là ăn được, không cần thuê đầu bếp hay xây nhà hàng. Viết 1 hàm đơn giản là tối ưu nhất."
- [Nếu CẦN]: "Task này giống như [kể 1 ví dụ đời thường từ cẩm nang]. Vì vậy chúng ta sẽ áp dụng [Tên Pattern]."
- **Lợi ích khi mở rộng:** Khi sau này bạn muốn thêm [tính năng X], bạn chỉ cần [tạo 1 file mới] mà không làm hỏng code cũ.

### 3. Bản vẽ thư mục (Folder Blueprint):
- `[NEW] src/patterns/.../ten-file.ts`: Nhiệm vụ file này làm gì.
- `[KEEP] src/...`: Các file cũ không cần đụng tới.

### 4. Chờ bạn phê duyệt:
"Tôi đã phác thảo xong phương án kiến trúc. Nếu bạn thấy hợp lý, hãy trả lời **'OK'** hoặc **'Tiến hành'**, tôi sẽ bắt đầu tạo file và viết code hoàn chỉnh cho bạn!"
```

---

## 5. Quy Tắc Giao Tiếp Cho Vibe Coder
- Giọng văn: Gần gũi, thực chiến, ví von dễ hiểu như đang trò chuyện với bạn bè.
- Tuyệt đối không dùng những câu từ học thuật khó hiểu (không nói: "Đa hình", "Tính đóng gói", "Khớp nối lỏng lẻo" mà hãy nói: "Dễ tháo lắp như khối Lego", "Tách riêng để không bị đụng chạm").
- Luôn cung cấp link file clickable và đường dẫn Windows đầy đủ khi tạo file xong ở Pha 2.
