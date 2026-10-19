# 🗺️ TỔNG HỢP TOÀN BỘ FLOW VÀ TÍNH NĂNG ỨNG DỤNG CHILL AI INTERIOR
### Hệ Thống Trợ Lý Ảo Thiết Kế 3D & Sản Xuất Nội Thất CNC Bằng Trí Tuệ Nhân Tạo
**Dành tặng:** Anh Huy (The Architect - Tổng Công Trình Sư)  
**Người đúc kết & biên soạn:** Lan (Trợ lý AI đồng hành)  
**Phiên bản hệ thống:** v2.6.0 Pro (Kiến trúc 3 Tầng & Đa Chế Độ)

---

## 📌 MỤC LỤC HỆ THỐNG TÀI LIỆU
Bộ tài liệu này được bóc tách và đối chiếu trực tiếp 100% từ toàn bộ mã nguồn của dự án (bao gồm lõi Ruby Plugin, giao diện Web CEF/HTML5, máy chủ Python Audio/TTS/STT và cơ sở tri thức mộc JSON).

| Tệp Tài Liệu | Nội Dung Chính | Phạm Vi Kỹ Thuật |
| :--- | :--- | :--- |
| [**00_TONG_QUAN_KIEN_TRUC_HE_THONG.md**](./00_TONG_QUAN_KIEN_TRUC_HE_THONG.md) | Tổng quan kiến trúc hệ thống đa nền tảng, Cầu nối hai chiều 25 Callbacks giữa JavaScript và Ruby, Cơ chế Dual-Layout (Studio RTS 1180x750 & Khay Đứng Dock 320x875). | `main.rb`, `app.js`, `game_hud.css` |
| [**01_FLOW_QUET_ANH_AI_VISION_VA_DUNG_HINH_3D.md**](./01_FLOW_QUET_ANH_AI_VISION_VA_DUNG_HINH_3D.md) | Luồng Image-to-3D, Phân tích thị giác máy tính với Google Gemma / Gemini Vision, 2 nút chọn Mặc định vs Tùy chỉnh, Tự động dựng hình 3D và phủ vật liệu. | `app.js`, `model_generator.rb`, `index.html` |
| [**02_FLOW_DYNAMIC_COMPONENT_VA_CO_MAY_KET_CAU_CHUAN_MOC.md**](./02_FLOW_DYNAMIC_COMPONENT_VA_CO_MAY_KET_CAU_CHUAN_MOC.md) | Cỗ máy kết cấu Structural Engine, Bộ Gen tri thức mộc (An Cường 17.5mm, Ba Thanh 17mm, Minh Long 18mm, Ván Thái 15mm, Custom User), Khóa độ dày chuẩn xưởng, Biến đối tượng bất kỳ thành Dynamic Component 1-chạm. | `structural_engine.rb`, `dynamic_component.rb`, `furniture_rules.json` |
| [**03_FLOW_GIAM_SAT_3_TANG_VA_CANH_BAO_KHO_VAN_REALTIME.md**](./03_FLOW_GIAM_SAT_3_TANG_VA_CANH_BAO_KHO_VAN_REALTIME.md) | Giám sát đối tượng 3 Tầng (Khối tổng -> Cụm chức năng -> Tấm ván/Ngũ kim), Quét cảnh báo vượt khổ ván 1220x2440mm theo thời gian thực (Real-time), Nút 1-chạm thu về khổ chuẩn 2440mm, Tính chu vi dán chỉ nẹp & m2. | `selection_observer.rb`, `main.rb`, `app.js` |
| [**04_FLOW_BOC_TACH_NESTING_2D_VA_XUAT_CNC_ASPIRE_GCODE.md**](./04_FLOW_BOC_TACH_NESTING_2D_VA_XUAT_CNC_ASPIRE_GCODE.md) | Bóc tách chi tiết tấm, Thuật toán Shelf Bin-Packing tối ưu ván 2D, Xuất DXF R12 cho Vectric Aspire, Xuất G-Code ISO cắm USB máy CNC, Trải phẳng trực tiếp lên mặt bàn SketchUp (One Click style) kèm nhãn khắc 3D. | `cam_gcode.rb`, `main.rb`, `app.js` |
| [**05_FLOW_TRO_LY_AO_TIN_TIN_VOICE_TTS_STT_VA_CHAT_AI.md**](./05_FLOW_TRO_LY_AO_TIN_TIN_VOICE_TTS_STT_VA_CHAT_AI.md) | Trợ lý ảo Tin Tin (Anh Thợ Mộc 2D cử động miệng mắt), Cầu nối âm thanh bản địa Windows WMP COM, Python Server port 57821 (Edge TTS Hoài My/Nam Minh & STT Nhận diện giọng nói tiếng Việt Live Streaming ngắt tự động 4s). | `avatar.js`, `audio_player.rb`, `tts_server.py` |
| [**06_FLOW_TAI_KHOAN_PHAN_QUYEN_MARKETPLACE_VA_VAT_TU.md**](./06_FLOW_TAI_KHOAN_PHAN_QUYEN_MARKETPLACE_VA_VAT_TU.md) | Quản lý định danh phần cứng (Hardware ID), Phân quyền VIP PRO vĩnh viễn cho anh Huy, Chợ số Marketplace chia sẻ thư viện mẫu 3D, Bảng tra cứu và liên kết đặt mua vật tư phụ kiện ngũ kim (Hafele, Blum, DTC). | `account.js`, `app.js`, `index.html` |

---

## 💡 ĐẶC ĐIỂM NỔI BẬT CỦA HỆ SINH THÁI CHILL AI
1. **Thiết kế chuyên biệt cho ngành gỗ nội thất Việt Nam:** Tích hợp sẵn cơ số kích thước nhân trắc học người Việt, các thương hiệu ván quen thuộc (An Cường, Ba Thanh, Minh Long) và phụ kiện kim khí phổ biến (Hafele, Blum, Ivan, DTC).
2. **Khắc phục triệt để điểm yếu của SketchUp:**
   - Khi kéo dãn bằng lệnh Scale hoặc Dynamic Component, các tấm ván **không bao giờ bị biến dạng độ dày** (luôn giữ cố định 17.5mm / 18mm / 9mm).
   - Bỏ qua rào cản hạn chế codec âm thanh MP3 của Chromium nhúng bằng Native Windows Audio Player OLE.
3. **Cầu nối sản xuất khép kín:** Khách hàng hoặc KTS chỉ cần đưa ra ý tưởng hoặc ảnh chụp, AI dựng hình 3D, tạo cấu kiện động và xuất ra file sản xuất ngay mà không cần qua nhiều phần mềm trung gian.
