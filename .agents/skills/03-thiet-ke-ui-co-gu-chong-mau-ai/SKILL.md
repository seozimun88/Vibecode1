---
name: 03-thiet-ke-ui-co-gu-chong-mau-ai
description: >-
  Định hướng thiết kế UI/UX độc đáo, có gu thẩm mỹ cao, thoát khỏi mẫu AI generic (AI slop). Dùng khi: thiết kế Landing Page, Web App, Dashboard, component giao diện mới hoặc khi muốn giao diện chuyên nghiệp, tối ưu mobile và hỗ trợ font tiếng Việt. Trigger: /03-thiet-ke-ui-co-gu-chong-mau-ai, /thiet-ke-ui-co-gu, thiet ke ui co gu, chong mau ai, anti-ai-slop, frontend design, Vibe Code, thiet ke landing page, thiet ke giao dien.
---

# Thiết Kế Giao Diện Có Gu Thẩm Mỹ (Chống Mẫu AI Đại Trà)

> **Mục tiêu:** Thoát khỏi hoàn toàn "AI slop" — những giao diện nhàm chán, một màu do AI tạo ra (nền trắng nhạt, nút bấm xanh dương bo tròn, font mặc định, thẻ card đều tăm tắp). Tạo ra giao diện có cá tính thương hiệu rõ ràng, chỉn chu và đạt chuẩn sản phẩm thương mại.

---

## 1. Triết Lý Thiết Kế Cốt Lõi
- **Đóng vai trò Trưởng nhóm Thiết kế (Design Lead):** Mỗi sản phẩm phải có một bộ nhận diện trực quan không thể nhầm lẫn với bất kỳ ai khác. Hãy dám đưa ra một lựa chọn thẩm mỹ táo bạo có cơ sở.
- **Bắt rễ từ đối tượng và sản phẩm thực tế:** Trước khi vẽ giao diện, xác định rõ: Sản phẩm này là gì? Phục vụ ai? Cảm xúc chủ đạo muốn mang lại là gì (Tin cậy, Sang trọng, Hiện đại, Tối giản hay Đột phá)?
- **Tiết chế và điểm nhấn duy nhất:** Dồn sự táo bạo vào một điểm nhấn đáng nhớ nhất (Signature element). Giữ mọi chi tiết xung quanh gọn gàng, trật tự để tôn vinh điểm nhấn đó.

---

## 2. Tiêu Chuẩn Typography & Hiển Thị Tiếng Việt

- **Bắt buộc hỗ trợ Tiếng Việt (Vietnamese / Latin Extended):** Tuyệt đối không chọn các font nước ngoài bị lỗi dấu (bị nhảy font ở các ký tự `ơ`, `ư`, `đ` hoặc dấu hỏi/ngã).
- **Phối hợp cặp font có chủ đích:**
  - *Font tiêu đề (Display/Headline):* Thể hiện cá tính thương hiệu (ví dụ: Serif hiện đại cho Luxury/Editorial, Grotesk đậm nét cho Tech/SaaS).
  - *Font nội dung (Body):* Dễ đọc, thoáng mắt, tỷ lệ chuẩn (ví dụ: Inter, Plus Jakarta Sans, Be Vietnam Pro, Manrope).
- **Phân cấp thị giác rõ ràng:** Tiêu đề lớn, khoảng cách dòng hợp lý (`line-height: 1.5 - 1.6`), nhãn mô tả (eyebrow) tinh tế.

---

## 3. Màu Sắc & Bố Cục (Color & Layout)

- **Bảng màu có chủ đích (Color Tokens):** Chỉ dùng 4–6 mã màu cụ thể thay vì màu mặc định của trình duyệt:
  - Màu nền chính (Canvas) & Nền phụ (Surface).
  - Màu chữ chính (Ink) & Màu chữ phụ (Muted).
  - 01 Màu điểm nhấn thương hiệu (Brand Accent).
  - Đảm bảo độ tương phản đạt chuẩn WCAG (chữ dễ đọc trên nền).
- **Phá vỡ lưới cứng nhắc:** Thay vì chia 3 cột đều chằn chặn, hãy dùng bố cục bất đối xứng có chủ đích (ví dụ: cột nội dung chính 70% + cột phụ 30%, hoặc tận dụng khoảng trắng lớn để tạo độ sang).
- **Hero Section là một Luận Đề:** Phần đầu trang phải thể hiện ngay thứ đặc trưng nhất của sản phẩm (tiêu đề sắc bén, demo tương tác trực tiếp hoặc hình ảnh trung tâm ấn tượng).

---

## 4. Tối Ưu Mobile & Chống Nhảy Dòng (Anti-Line-Wrapping)

- **Ưu tiên Mobile-first (360px – 430px):**
  - Mọi thao tác chạm (Touch target) phải đạt tối thiểu **44px x 44px**.
  - Không để chữ bị tràn mép màn hình, không tạo thanh cuộn ngang ngoài ý muốn (`overflow-x: hidden`).
- **Nút bấm Kêu gọi Hành động (CTA):**
  - Nhãn nút dứt khoát, chỉ **2–4 từ** (ví dụ: *Đăng ký ngay*, *Nhận tư vấn*, *Xem demo*).
  - Tuyệt đối tránh nhãn dài làm nút bị vỡ thành nhiều dòng trên màn hình điện thoại.
  - Sử dụng thuộc tính chống rớt chữ: `text-wrap: balance` cho tiêu đề và `text-wrap: pretty` cho đoạn văn.

---

## 5. Quy Trình 2 Bước Triển Khai
1. **Bước 1 - Lập kế hoạch thiết kế ngắn gọn:**
   - Xác định hướng thẩm mỹ (Aesthetic direction).
   - Liệt kê cặp font + bảng màu Hex.
   - Phác thảo cấu trúc bố cục dạng văn bản hoặc sơ đồ ASCII.
2. **Bước 2 - Triển khai code chuẩn sản phẩm:**
   - HTML ngữ nghĩa (semantic: `header`, `main`, `section`, `article`, `footer`).
   - CSS hiện đại dùng biến tùy chỉnh (CSS Custom Properties / Variables).
   - Tôn trọng người dùng: hỗ trợ Dark/Light mode sạch sẽ và hiệu ứng chuyển động mượt mà (hỗ trợ `prefers-reduced-motion`).
