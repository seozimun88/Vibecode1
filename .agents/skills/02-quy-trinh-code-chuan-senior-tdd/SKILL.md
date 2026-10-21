---
name: 02-quy-trinh-code-chuan-senior-tdd
description: >-
  Quy trình lập trình chuẩn Senior kỷ luật cao theo phương pháp TDD (viết test trước, code sau). Dùng khi: phát triển tính năng phức tạp, xử lý logic quan trọng, cần chống bug lan truyền và tránh việc AI đoán mò yêu cầu rồi code ẩu. Trigger: /02-quy-trinh-code-chuan-senior-tdd, /quy-trinh-code-tdd, quy trinh code tdd, senior tdd, superpowers, Vibe Code, code ky luat, test truoc code sau.
---

# Quy Trình Lập Trình Kỷ Luật Chuẩn Senior (TDD & Spec-First)

> **Mục tiêu:** Ép AI tuân thủ kỷ luật làm việc của một Kỹ sư Cấp cao (Senior Software Engineer): suy nghĩ kỹ trước khi code, viết bài kiểm tra (test) trước, triển khai từng bước nhỏ và tự kiểm tra lại trước khi thông báo hoàn tất.

---

## 1. Thứ Tự Ưu Tiên Chỉ Thị (Instruction Priority)
1. **Chỉ thị trực tiếp của người dùng:** Luôn có quyền ưu tiên cao nhất.
2. **Quy trình kỷ luật của Skill:** Ghi đè lên hành vi mặc định của AI (ngăn chặn AI tự ý code ẩu).
3. **Prompt mặc định của hệ thống:** Độ ưu tiên thấp nhất.

---

## 2. Nhận Diện Ngụy Biện (Red Flags - Dấu Hiệu Phải Dừng Lại Ngay)

Nếu AI xuất hiện các suy nghĩ sau, **bắt buộc phải dừng lại và kích hoạt quy trình kiểm soát**:

| Suy nghĩ ngụy biện của AI | Thực tế bắt buộc phải làm |
| :--- | :--- |
| *"Đây chỉ là một yêu cầu đơn giản, code luôn cho nhanh"* | Yêu cầu nào cũng có edge case. Phải làm rõ yêu cầu trước. |
| *"Để tôi tự đoán ý người dùng rồi viết code luôn"* | Tuyệt đối không đoán mò. Phải hỏi lại điểm chưa rõ. |
| *"Code xong rồi chạy test bằng tay sau cũng được"* | Viết bài test tự động trước (TDD) mới đảm bảo không sinh bug mới. |
| *"Cứ sửa một loạt file rồi test một thể"* | Chia nhỏ và test từng bước một (micro-steps). |

---

## 3. Quy Trình 5 Bước Triển Khai Nghiêm Ngặt

### Bước 1: Hiểu Rõ Yêu Cầu (Understand First)
- Đọc kỹ yêu cầu. Xác định chính xác mục tiêu kinh doanh và phạm vi công việc.
- Nếu có bất kỳ điểm nào chưa rõ ràng hoặc có nhiều cách triển khai: **Hỏi lại người dùng ngay**, không tự ý đưa ra giả định.

### Bước 2: Viết Bản Đặc Tả Kỹ Thuật (Mini-Spec)
Trước khi đụng vào code, soạn một bản đặc tả ngắn (5-10 dòng):
- **Phạm vi sẽ làm:** Tính năng gồm những gì?
- **Phạm vi KHÔNG làm:** Những gì nằm ngoài phạm vi lần này?
- **Trường hợp biên (Edge cases):** Xử lý ra sao khi dữ liệu rỗng, số âm, kết nối mạng lỗi, hoặc người dùng nhập sai?
- **Giao diện/Đầu ra mong muốn:** Kết quả trông như thế nào khi hoàn thành?

### Bước 3: Viết Bài Kiểm Tra Trước (TDD - Test-Driven Development)
- Viết bài kiểm tra (Unit Test hoặc Integration Test) mô phỏng chính xác trường hợp sử dụng.
- Chạy bài kiểm tra và xác nhận bài kiểm tra **THẤT BẠI (Red)** vì tính năng chưa được code.
- Điều này chứng minh bài kiểm tra thực sự hoạt động và không báo pass giả.

### Bước 4: Triển Khai Từng Bước Nhỏ (Micro-Steps Implementation)
- Viết lượng code tối thiểu cần thiết để bài kiểm tra chuyển sang **THÀNH CÔNG (Green)**.
- Chạy lại test ngay sau mỗi thay đổi nhỏ.
- Không sửa ồ ạt nhiều file cùng lúc khiến việc truy vết lỗi trở nên bất khả thi.

### Bước 5: Tự Kiểm Toán Lại Code (Self-Review)
Trước khi thông báo "Đã xong", AI phải tự đọc lại toàn bộ code vừa viết dưới góc nhìn của một người khó tính:
- Có biến nào đặt tên khó hiểu không?
- Có đoạn code nào bị lặp không?
- Có nguy cơ rò rỉ bộ nhớ hoặc lỗi logic tiềm ẩn không?
- Chỉ xác nhận hoàn thành khi toàn bộ bài test vượt qua và code đạt chuẩn sạch.

---

## 4. Hướng Dẫn Vận Dụng Trong Thực Tế
- **Dự án có Framework Test (Jest, Vitest, Pytest):** Viết file test `.test.ts` hoặc `test_*.py` theo đúng quy chuẩn.
- **Dự án Script đơn giản hoặc Vibe Coding không cài sẵn bộ test:** Tạo một file test runner độc lập (ví dụ `verify-feature.js`) chạy các hàm kiểm thử với dữ liệu giả lập (mock data) để kiểm chứng đầu ra trước khi kết nối vào luồng chính.
