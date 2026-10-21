---
name: 01-phan-bien-y-tuong-startup-yc
description: >-
  Phản biện ý tưởng theo chuẩn Y Combinator và viết bản thiết kế (Design Doc) trước khi code. Dùng khi: có ý tưởng mới, muốn thẩm định nhu cầu thị trường, phân vân có nên làm tính năng này không, hoặc cần lập kế hoạch sản phẩm từ đầu. Trigger: /01-phan-bien-y-tuong-startup-yc, /phan-bien-y-tuong, phan bien y tuong, phan-bien-y-tuong-startup-yc, Vibe Code, YC office hours, gstack, tham dinh y tuong, design doc.
---

# Phản Biện Ý Tưởng Startup & Lập Design Doc (Chuẩn Y Combinator)

> **Mục tiêu:** Ngăn chặn bẫy lãng phí lớn nhất của lập trình viên: *lao vào viết code hàng tuần cho một tính năng mà không ai thực sự cần hoặc không ai sẵn sàng trả tiền.*

---

## 1. Triết Lý Vận Hành
- **Hiểu rõ bài toán trước khi tìm giải pháp:** Tuyệt đối không bắt đầu gõ code khi chưa có bản thiết kế (Design Doc) được đồng thuận.
- **Tính cụ thể là giá trị duy nhất:** "Doanh nghiệp trong ngành bất động sản" không phải là khách hàng. Khách hàng phải là một người cụ thể với nỗi đau cụ thể.
- **Sự quan tâm không phải là nhu cầu:** Danh sách chờ (Waitlist) không chứng minh được gì. Tiền thanh toán hoặc hành vi đổi thói quen mới là bằng chứng thực tế.
- **Thói quen hiện tại là đối thủ lớn nhất:** Đối thủ thật sự không phải công cụ của đối thủ khác, mà là file Excel, sổ tay ghi chép hoặc cách làm thủ công người ta đang dùng.
- **Đầu ra bắt buộc:** Luôn tạo ra một bản **Design Doc** (bản mô tả thiết kế sản phẩm) lưu vào tài liệu dự án. **Không xuất code trong bước này.**

---

## 2. Hai Chế Độ Phản Biện

### Chế độ A: Khởi Nghiệp & Sản Phẩm Thương Mại (Startup Mode)
Đặt 6 câu hỏi ép sự thật (Forcing Questions):
1. **Bằng chứng nhu cầu (Demand Reality):** Bằng chứng mạnh nhất chứng minh có người thực sự muốn thứ này là gì?
2. **Hiện trạng (Status Quo):** Người dùng đang giải quyết vấn đề này bằng cách nào ngay lúc này?
3. **Chân dung người cần nhất (Desperate Specificity):** Ai là người cụ thể (vai trò, bối cảnh) sẽ tuyệt vọng nhất nếu không có giải pháp này?
4. **Miếng đánh hẹp nhất (Narrowest Wedge):** Phiên bản nhỏ nhất mà ai đó sẵn sàng trả tiền hoặc dùng ngay trong tuần này là gì?
5. **Quan sát thực tế (Observation):** Bạn đã từng tận mắt thấy ai đó loay hoay xử lý việc này chưa? Điều gì khiến bạn bất ngờ?
6. **Tầm nhìn tương lai (Future-Fit):** Trong 3 năm tới, sản phẩm này trở nên quan trọng hơn hay thừa thãi hơn?

### Chế độ B: Builder / Vibe Coding (Dự án cá nhân, Hackathon, Tiện ích nội bộ)
Dành cho công cụ nội bộ hoặc tool tự động hóa:
- Đâu là phiên bản thú vị nhất của ý tưởng này?
- Con đường ngắn nhất để tạo ra thứ chạy được ngay hôm nay và dùng thử là gì?
- Làm sao để biến tính năng phức tạp thành một luồng duy nhất giải quyết trọn vẹn việc cần làm?

---

## 3. Cấu Trúc Bản Design Doc Cần Xuất

Khi hoàn tất phản biện, AI phải xuất một bản Design Doc theo cấu trúc chuẩn:

```markdown
# [Tên Dự Án] - Bản Thiết Kế Sản Phẩm (Design Doc)

## 1. Vấn đề & Khách hàng mục tiêu
- Vấn đề cốt lõi cần giải quyết:
- Đối tượng sử dụng cụ thể:
- Cách họ đang xử lý hiện tại (Status Quo):

## 2. Giải pháp cốt lõi (MVP Wedge)
- Tính năng sống còn (Phải có ngay):
- Những thứ KHÔNG LÀM ở giai đoạn này (Out of scope):

## 3. Luồng trải nghiệm người dùng (User Flow)
- Bước 1 -> Bước 2 -> Bước 3 -> Chuyển đổi/Kết quả đạt được.

## 4. Kiến trúc kỹ thuật tối giản
- Công nghệ đề xuất (Frontend / Backend / Database):
- Các rủi ro kỹ thuật cần lưu ý:

## 5. Tiêu chí hoàn thành (Definition of Done)
- Khi nào tính năng này được coi là hoàn tất và sẵn sàng đưa cho người dùng test?
```

---

## 4. Quy Tắc Hoàn Thiện (Boil the Lake Principle)
Khi viết code hỗ trợ AI, chi phí biên để hoàn thiện trọn vẹn một tính năng là rất nhỏ. 
- Nếu Lựa chọn A là triển khai hoàn chỉnh (đầy đủ thông báo lỗi, trạng thái tải, xử lý ngoại lệ).
- Lựa chọn B là làm tạm bợ để tiết kiệm chút ít công sức.
- **Luôn chọn Lựa chọn A.** Không để lại tính năng dang dở hoặc code giữ chỗ (placeholder).
