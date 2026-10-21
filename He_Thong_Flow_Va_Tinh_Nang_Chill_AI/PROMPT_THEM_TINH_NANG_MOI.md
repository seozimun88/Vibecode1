# 🛡️ BỘ KHUNG PROMPT CHUẨN: THÊM TÍNH NĂNG MỚI AN TOÀN (ZERO BREAKAGE)
**Dự án:** Chill AI Interior & Vibe Coding  
**Dành cho:** Anh Huy (The Architect) & Trợ lý Lan  
**Mục tiêu:** Thêm tính năng mới 100% thành công mà **TUYỆT ĐỐI KHÔNG LÀM HỎNG** các tính năng cũ đang chạy mượt.

---

## 📌 HƯỚNG DẪN DÙNG NHANH
Mỗi khi anh Huy nảy ra ý tưởng tính năng mới, chỉ cần **copy khung bên dưới**, điền nhanh vài dòng theo đời thường rồi gửi cho Lan. Lan sẽ tự động kích hoạt chế độ **"Bảo Vệ Tính Năng Cũ (Regression Protection)"**.

---

## 📋 MẪU PROMPT GỬI CHO LAN (COPY TOÀN BỘ KHUNG NÀY)

```markdown
Lan ơi, anh muốn nâng cấp/thêm tính năng mới sau:

### 1. Ý TƯỞNG THEO CÔNG THỨC 3 BƯỚC ĐỜI THƯỜNG
- Bước 1 (Khi tôi làm gì): [Ví dụ: Khi anh click vào nút Xuất DXF ở màn hình chính]
- Bước 2 (Nó bị/nó xử lý thế nào): [Ví dụ: Hệ thống tự gom nhóm theo chiều dày ván 17.5mm và 9mm]
- Bước 3 (Kết quả mong muốn): [Ví dụ: Xuất ra 2 file DXF riêng biệt và Avatar Tin Tin thông báo thành công]

### 2. DANH SÁCH TÍNH NĂNG CŨ ĐANG HOẠT ĐỘNG (TUYỆT ĐỐI KHÔNG ĐƯỢC CHẠM VÀO)
- [x] Giọng đọc TTS Nam Minh & STT tiếng Việt (Port 57821)
- [x] Observer chọn đối tượng trong SketchUp tự động nhận diện 3 Tầng
- [x] Dựng tủ áo Dynamic Component và xoay cánh 90-110 độ
- [x] Bóc tách tấm quá khổ và cảnh báo khổ ván 1220x2440
- [x] [Anh Huy điền thêm nếu có...]

### 3. KỶ LUẬT YÊU CẦU CHO LAN
1. Phân tích trước: Chỉ ra file nào bị ảnh hưởng và có nguy cơ xung đột không.
2. Không sửa dồn dập: Sửa đúng phạm vi cần thiết, không xóa code cũ nếu không giải thích.
3. Test F12 Console & Chrome trước khi bàn giao.
```

---

## 💡 NGUYÊN TẮC VÀNG ĐẢM BẢO TÍNH NĂNG CŨ KHÔNG BỊ HỎNG

| STT | Nguyên Tắc | Hành Động Cụ Thể Của Lan |
|---|---|---|
| **1** | **Nguyên tắc "Đảo Cách Ly" (Isolation)** | Viết tính năng mới thành hàm độc lập (`function/module riêng`), chỉ gọi qua event listener mới, không chèn ngang vào giữa thân hàm cũ. |
| **2** | **Nguyên tắc "Bảo tồn ID & Class"** | Tuyệt đối không đổi tên ID các thẻ HTML đã gắn sự kiện (`#dock-btn-build-3d`, `#chat-input`, `#select-thickness`...). Nếu đổi giao diện, giữ nguyên ID cũ làm alias. |
| **3** | **Nguyên tắc "Fallback An Toàn"** | Bọc code mới trong khối `try { ... } catch (err) { console.error(err); }` để nếu tính năng mới có lỗi cú pháp thì plugin vẫn chạy bình thường các tính năng khác. |
| **4** | **Checklist Hồi Quy (Regression Test)** | Sau khi code xong, Lan luôn chạy test lại 4 hành động sống còn: (1) Mở cửa sổ, (2) Click đối tượng SU, (3) Bấm Chat thử, (4) Thử 1 nút xuất CNC. |
