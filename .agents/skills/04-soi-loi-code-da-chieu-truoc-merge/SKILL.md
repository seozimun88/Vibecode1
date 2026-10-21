---
name: 04-soi-loi-code-da-chieu-truoc-merge
description: >-
  Soi lỗi code toàn diện qua 5 lăng kính chuyên sâu (logic, hiệu năng, bảo mật, chuẩn sạch, framework). Dùng khi: vừa viết xong tính năng mới, chuẩn bị merge code vào nhánh chính, review Pull Request hoặc cần tổng kiểm tra chất lượng trước khi bàn giao. Trigger: /04-soi-loi-code-da-chieu-truoc-merge, /soi-loi-code, soi loi code, code review, review code truoc merge, PR review, Vibe Code, kiem tra code.
---

# Soi Lỗi Code Toàn Diện Đa Chiều Trước Merge (Code Review Excellence)

> **Mục tiêu:** Đóng vai trò như một Tech Lead và hội đồng kỹ sư soi xét khách quan: phát hiện lỗi tiềm ẩn, race condition, truy vấn chậm, rò rỉ bộ nhớ và vi phạm chuẩn code trước khi đẩy code vào nhánh chính.

---

## 1. Hệ Thống Nhãn Đánh Giá Mức Độ (Severity Labels)

Mọi nhận xét review phải được gắn nhãn phân loại rõ ràng:
- `[blocking]` — **Bắt buộc sửa:** Lỗi nghiêm trọng, crash app, rò rỉ dữ liệu, vỡ giao diện; không được merge nếu chưa xử lý.
- `[important]` — **Nên sửa:** Ảnh hưởng đến hiệu năng hoặc khả năng bảo trì lâu dài; cần khắc phục hoặc thảo luận nếu có lý do đặc thù.
- `[suggestion]` — **Đề xuất tối ưu:** Cách tiếp cận thay thế gọn hơn hoặc hiện đại hơn.
- `[nit]` — **Góp ý nhỏ:** Lỗi chính tả, căn lề, đặt tên biến chưa mượt; không chặn tiến độ merge.
- `[praise]` — **Khen ngợi:** Đoạn code xử lý khéo léo, kiến trúc đẹp.

---

## 2. Quy Trình Review 4 Giai Đoạn

### Giai đoạn 1: Nắm Bắt Ngữ Cảnh
- Đọc hiểu mục đích của thay đổi: Đoạn code này giải quyết bài toán kinh doanh gì?
- Kiểm tra dung lượng thay đổi: Nếu thay đổi quá lớn (> 400 dòng code), kiến nghị chia nhỏ task để review hiệu quả hơn.

### Giai đoạn 2: Đánh Giá Kiến Trúc Cấp Cao (High-Level Design)
- Giải pháp này có giải quyết đúng gốc rễ vấn đề hay chỉ đang vá tạm?
- File mới tạo có đặt đúng vị trí thư mục trong kiến trúc dự án không?
- Có bị phá vỡ kiến trúc chung hoặc sinh ra liên kết phụ thuộc lộn xộn (circular dependencies) không?

### Giai đoạn 3: Soi Chi Tiết Từng Dòng Qua 5 Lăng Kính Chuyên Sâu

#### Lăng kính 1: Tính Đúng Đắn & Logic (Logic & Correctness)
- Có bắt kịp các trường hợp biên (edge cases) không?
- Kiểm tra kỹ các giá trị có nguy cơ bị `null`, `undefined`, chuỗi rỗng hoặc mảng rỗng.
- Có nguy cơ xung đột bất đồng bộ (Race condition) hoặc vòng lặp vô tận không?

#### Lăng kính 2: Hiệu Năng & Tài Nguyên (Performance)
- **Cơ sở dữ liệu:** Có bị lỗi truy vấn N+1 (N+1 query problem) không?
- **Frontend/React:** Có bị re-render thừa thãi, thiếu `key` trong danh sách, hoặc quên `cleanup` trong effect không?
- **Bộ nhớ:** Có nguy cơ rò rỉ bộ nhớ (memory leak) do event listener chưa gỡ không?

#### Lăng kính 3: Bảo Mật Cơ Bản (Security Hygiene)
- Dữ liệu người dùng gửi lên có được kiểm tra chặt chẽ không?
- Có đoạn mã nhạy cảm nào bị phơi bày ra client không?

#### Lăng kính 4: Tính Dễ Đọc & Bảo Trì (Maintainability)
- Tên biến, tên hàm có diễn đạt đúng ý nghĩa hành động không?
- Một hàm có làm quá nhiều việc không (vi phạm Single Responsibility)?
- Code có bị trùng lặp (DRY) ở nhiều nơi không?

#### Lăng kính 5: Chuẩn Ngôn Ngữ & Framework Hiện Đại
- **React/Next.js:** Chuẩn React 19 Actions, Server Components, Suspense, Custom Hooks.
- **TypeScript:** Kiểu dữ liệu chặt chẽ, không lạm dụng kiểu `any`.
- **Node/Python/Go:** Xử lý lỗi (Error handling) chuẩn xác, không nuốt lỗi âm thầm (`swallow errors`).

---

## 3. Cấu Trúc Báo Cáo Review Chuẩn

Khi hoàn tất, xuất báo cáo tổng kết theo mẫu:

```markdown
### 📋 Báo Cáo Code Review

#### 1. Tổng kết & Quyết định
- **Trạng thái:** [Phê duyệt (Approve) / Yêu cầu sửa đổi (Request Changes)]
- **Đánh giá chung:** (Tóm tắt ngắn 2-3 câu về chất lượng thay đổi)

#### 2. Vấn đề cần khắc phục
- `[blocking]` **Tên lỗi / Vị trí file:dòng:**
  - *Hiện tượng:* Mô tả rủi ro logic/hiệu năng.
  - *Cách khắc phục (Code mẫu Before / After):*
- `[important]` **Tên cải thiện:**

#### 3. Điểm sáng của đợt code này
- `[praise]` (Điểm viết tốt cần duy trì)
```
