# 🛡️ CẨM NANG: QUY TRÌNH KIỂM SOÁT VÀ BẢO VỆ TÍNH NĂNG CŨ (REGRESSION CONTROL)
**Dự án:** Chill AI Interior  
**Tác giả:** KTS. Nguyễn Văn Huy & Trợ lý Lan

---

## 🎯 VẤN ĐỀ THỰC TẾ
Khi phát triển phần mềm, hiện tượng **"Sửa được cái mới thì hỏng cái cũ" (Regression Bug)** là nỗi ám ảnh lớn nhất. Đặc biệt với hệ thống Hybrid như Chill AI Interior:
- HTML/CSS/JS (Giao diện)
- Ruby API (Lõi tương tác SketchUp)
- Python Server (Xử lý âm thanh STT/TTS)
- Gemini Cloud AI (Nhận diện hình ảnh)

Một thay đổi nhỏ về class CSS hoặc một tên biến trong `app.js` có thể làm tê liệt callback 2 chiều.

---

## 🔒 5 LÁ CHẮN BẢO VỆ TUYỆT ĐỐI

### Lá Chắn 1: Khóa cứng "Hợp Đồng Kết Nối" (Ruby-JS Bridge Contract)
Danh sách 25 Callback giữa JavaScript và Ruby là **bất khả xâm phạm**:
- `window.sketchup.create_3d_model`
- `window.sketchup.create_dynamic_component`
- `window.sketchup.export_dxf_direct`
- `window.sketchup.nest_to_sketchup`
- `window.sketchup.clamp_oversized_to_standard`
- `window.sketchup.zoom_to_entity`
- `window.sketchup.get_current_selection`
- `window.sketchup.set_window_layout_mode`

👉 **Quy tắc:** Khi thêm tính năng mới, **chỉ được phép THÊM callback mới**, TUYỆT ĐỐI KHÔNG xóa, không đổi tên các callback hiện có.

---

### Lá Chắn 2: Lưu Trữ Cấu Hình Trong LocalStorage Có Namespace
Dữ liệu lưu trữ trình duyệt phải có tiền tố `chill_ai_*` rõ ràng:
- `chill_ai_gemini_key`
- `chill_ai_gemini_model`
- `chill_layout_mode`
- `chill_ai_custom_rules`

👉 **Quy tắc:** Không dùng lệnh `localStorage.clear()`. Muốn xóa chỉ dùng `localStorage.removeItem('tên_chính_xác')`.

---

### Lá Chắn 3: Cơ Chế "Gối Đỡ Lỗi" (Defensive Programming)
Mọi đoạn code liên quan đến giao diện và DOM phải luôn kiểm tra sự tồn tại của phần tử trước khi gán sự kiện:
```javascript
// ✅ CHUẨN AN TOÀN (Dùng Optional Chaining hoặc kiểm tra if)
document.getElementById('btn-new-feature')?.addEventListener('click', () => { ... });

// ❌ NGUY HIỂM (Nếu phần tử không có trên giao diện sẽ gây crash toàn bộ script)
document.getElementById('btn-new-feature').addEventListener('click', () => { ... });
```

---

### Lá Chắn 4: Kiểm Thử F12 Bắt Buộc Sau Mỗi Lần Sửa
Trước khi thông báo xong cho anh Huy, Lan phải đối chiếu 4 kịch bản sống còn:
1. **Mở plugin**: Không có dòng chữ đỏ `Uncaught TypeError` trong F12 Console.
2. **Chọn 1 đối tượng bất kỳ trong SketchUp**: Thông số 3 tầng vẫn cập nhật.
3. **Bấm micro nói hoặc gõ text**: Chat bot vẫn nhận tin nhắn.
4. **Bấm nút Xây 3D hoặc Xuất DXF**: Không bị treo đơ giao diện.
