---
name: 05-quet-bao-mat-owasp-truoc-deploy
description: >-
  Kiểm toán và quét lỗ hổng bảo mật theo chuẩn OWASP Top 10 trước khi đưa lên hosting thật. Dùng khi: chuẩn bị deploy production, thêm tính năng đăng nhập/xác thực, tạo API endpoint mới, xử lý form/file upload, hoặc kết nối thanh toán/dữ liệu nhạy cảm. Trigger: /05-quet-bao-mat-owasp-truoc-deploy, /quet-bao-mat, quet bao mat, security review, OWASP, bao mat truoc deploy, Vibe Code, audit security, kiem tra bao mat.
---

# Quét Bảo Mật Chuẩn OWASP Trước Khi Deploy (Security Review)

> **Mục tiêu:** Đóng vai trò như một Chuyên gia An ninh mạng (Security Engineer): rà soát toàn diện mã nguồn theo chuẩn OWASP Top 10, triệt tiêu nguy cơ lộ lọt dữ liệu, mất cắp API key hoặc bị hacker khai thác khi ứng dụng chạy trên internet.

---

## 1. Thời Điểm Bắt Buộc Kích Hoạt
- Triển khai tính năng Đăng nhập / Đăng ký / Phân quyền (Auth).
- Xử lý dữ liệu người dùng nhập vào (Form đăng ký, thanh toán, upload file).
- Tạo mới các cổng API (Endpoints).
- Chuẩn bị đẩy ứng dụng lên môi trường thật (Deploy to Production).

---

## 2. Danh Sách Kiểm Tra 7 Lớp Bảo Mật

### Lớp 1: Quản Lý Khóa Bí Mật & API Key (Secrets Management)
- **CẤM:** Hardcode API keys, token bí mật, chuỗi kết nối database trực tiếp trong mã nguồn.
- **BẮT BUỘC:** Lưu toàn bộ thông tin nhạy cảm trong biến môi trường (`process.env`).
- **Xác minh file `.gitignore`:** Phải có `.env`, `.env.local`, `.env.production` để tránh vô tình đẩy lên GitHub.

```typescript
// ❌ CỰC KỲ NGUY HIỂM (Bị quét bot đánh cắp trong vài giây)
const apiKey = "sk-proj-xyz123456789";

// ✅ AN TOÀN CHUẨN MỰC
const apiKey = process.env.AI_API_KEY;
if (!apiKey) throw new Error("Chưa cấu hình AI_API_KEY trong file môi trường");
```

### Lớp 2: Xác Thực Dữ Liệu Đầu Vào (Input Validation)
- Mọi dữ liệu do người dùng gửi lên từ form/API đều **không được tin tưởng**.
- Bắt buộc kiểm tra cấu trúc dữ liệu bằng Schema (ví dụ: dùng thư viện Zod, Joi):

```typescript
import { z } from 'zod';

const FormLeadSchema = z.object({
  fullName: z.string().min(2, "Tên quá ngắn").max(100),
  phone: z.string().regex(/^(0|\+84)[3|5|7|8|9][0-9]{8}$/, "Số điện thoại không hợp lệ"),
  email: z.string().email("Email không đúng định dạng").optional(),
});
```

### Lớp 3: Chống Tấn Công SQL Injection
- **CẤM:** Nối chuỗi trực tiếp vào câu lệnh SQL (`SELECT * FROM users WHERE email = '` + email + `'`).
- **BẮT BUỘC:** Sử dụng câu truy vấn có tham số (Parameterized Query) hoặc dùng ORM an toàn (Prisma, Drizzle, Mongoose).

### Lớp 4: Cơ Chế Xác Thực & Phân Quyền (Auth & Authorization)
- **Lưu trữ Token:** Lưu trữ JWT/Session token trong **Cookie HttpOnly, Secure, SameSite=Lax/Strict**. Tuyệt đối **không** lưu token nhạy cảm trong `localStorage` (dễ bị mã độc đọc trộm qua XSS).
- **Kiểm tra quyền hạn:** Luôn xác thực quyền hạn ở phía Server (Server-side check), không chỉ ẩn/hiện nút bấm ở phía Giao diện (Client-side).
- **Cơ sở dữ liệu đám mây (Supabase/Firebase):** Bắt buộc kích hoạt Row Level Security (RLS).

### Lớp 5: Chống Tấn Công XSS & CSRF
- Làm sạch (sanitize) mọi đoạn HTML do người dùng nhập vào (dùng thư viện như DOMPurify) trước khi hiển thị ra giao diện.
- Thiết lập tiêu đề bảo mật (Security Headers): `Content-Security-Policy`, `X-Frame-Options: DENY` (chống nhúng web lừa đảo iframe).

### Lớp 6: Giới Hạn Tần Suất & Chống Spam (Rate Limiting)
- Thiết lập Rate Limiting cho các endpoint công khai (đặc biệt là form nộp thông tin lead, quên mật khẩu, gửi mã OTP).
- Sử dụng Cloudflare Turnstile hoặc giải pháp chặn bot spam đối với các landing page chạy quảng cáo.

### Lớp 7: Xử Lý Lỗi & Nhật Ký (Error Handling & Logging)
- **Không phơi bày stack trace** (chi tiết lỗi máy chủ, cấu trúc thư mục) cho người dùng cuối nhìn thấy khi có sự cố.
- **Không ghi nhật ký (log) thông tin nhạy cảm:** Không ghi mật khẩu, số thẻ ngân hàng, token vào console/file log.

---

## 3. Bảng Kiểm Tra Chốt Chặn Trước Deploy (Pre-Deploy Gate)

Chỉ bấm nút deploy khi **100% mục sau đây đạt trạng thái ĐẠT**:

| Hạng mục kiểm tra | Trạng thái | Ghi chú xử lý |
| :--- | :---: | :--- |
| Không còn bất kỳ secret/token nào trong git commit | [ ] ĐẠT | Kiểm tra kỹ file `.env.local` đã gitignore |
| Toàn bộ API endpoint đều có Schema validation (Zod) | [ ] ĐẠT | Bắt buộc có thông báo lỗi thân thiện |
| Cookie chứa Auth Token đã bật flag HttpOnly & Secure | [ ] ĐẠT | Chống đánh cắp phiên đăng nhập |
| Đã bật Rate Limiting chống spam form | [ ] ĐẠT | Ngăn chặn bot đẩy hàng ngàn lead ảo |
| Đã tắt chế độ Debug / Không lộ Stack Trace ra màn hình | [ ] ĐẠT | Chỉ trả về thông báo lỗi chung chung |
