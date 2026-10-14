# Các Phương Án Tích Hợp Giọng Nói Trí Tuệ Nhân Tạo (TTS) Tại Việt Nam

Để có giọng đọc tiếng Việt "Nam/Bắc, Già/Trẻ, Nam/Nữ" biểu cảm, chúng ta không thể dùng bộ đọc mặc định của trình duyệt (`window.speechSynthesis`) vì nó phụ thuộc vào hệ điều hành (Windows thường chỉ có giọng Tây lơ lớ). 

Thay vào đó, chúng ta sẽ gọi API từ các máy chủ AI chuyên về âm thanh. Dưới đây là 3 phương án phổ biến, miễn phí hoặc có gói miễn phí để bạn chọn:

## 1. FPT.AI (Khuyên dùng nhất cho Tiếng Việt)
FPT AI hiện là nền tảng Text-to-Speech (TTS) số 1 tại Việt Nam với kho giọng phong phú và tự nhiên nhất.
- **Các giọng hỗ trợ:**
  - Giọng Bắc: Ban Mai (Nữ trẻ), Thu Minh (Nữ trung), Lê Minh (Nam trẻ)
  - Giọng Nam: Lan Nhi (Nữ), Minh Quang (Nam)
  - Giọng Trung: Mỹ An (Nữ)
- **Chi phí:** Miễn phí **100.000 ký tự / tháng** (Khoảng 2-3 tiếng âm thanh, dư sức cho trợ lý).
- **Cách nhúng:** Tạo tài khoản FPT Console, lấy API Key. Chúng ta sẽ tạo thêm 1 ô nhập API Key của FPT và 1 menu thả xuống (Dropdown) để bạn tự do đổi giọng Nam/Bắc cho Lyly.

## 2. Zalo AI / Viettel AI
- **Giọng hỗ trợ:** Tương tự FPT, chia theo vùng miền Nam/Bắc/Nữ/Nam (vd: Zalo có Nữ Miền Nam, Nữ Miền Bắc...).
- **Chi phí:** Zalo AI cho khoảng 500.000 ký tự/tháng miễn phí. Viettel cũng có gói trial.
- **Cách nhúng:** Tương tự FPT, cần đăng ký API Key và truyền văn bản qua REST API để nhận file âm thanh `.mp3` về phát.

## 3. "Chị Google" (Google Translate Unofficial API)
Đây chính là giọng đọc kinh điển của Google Dịch mà bạn hay nghe trên Tiktok/Youtube.
- **Giọng hỗ trợ:** Chỉ duy nhất 1 giọng (Nữ - "Chị Google").
- **Chi phí:** Miễn phí 100%, **không cần API Key**, không giới hạn.
- **Cách nhúng:** Dùng mẹo gọi thẳng link `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=vi&q=[Nội_Dung_Cần_Nói]`.

## 4. ElevenLabs (Đỉnh cao thế giới)
- **Chất lượng:** Giống người thật 99%, có tiếng thở, ngập ngừng, biểu cảm xuất sắc (hỗ trợ Tiếng Việt cực mượt).
- **Chi phí:** Gói miễn phí **10.000 ký tự / tháng** (khá ít, sẽ mau hết nếu xài nhiều).

---

### 🔥 Đề xuất Kế Hoạch Triển Khai:

**Bước 1 (Giải pháp tình thế):** Tôi sẽ chuyển ngay giọng hiện tại sang **"Chị Google"** (Phương án 3) để Lyly nói chuẩn tiếng Việt 100% thay vì giọng Tây, vì cách này tôi có thể code được ngay mà không cần bạn đăng ký gì.

**Bước 2 (Giải pháp hoàn chỉnh):** Nếu bạn muốn Lyly có giọng Nữ miền Nam ngọt ngào hoặc Nữ miền Bắc chuẩn mực, bạn hãy đăng ký 1 tài khoản **FPT.AI**. Tôi sẽ thiết kế thêm giao diện trong mục "Cấu hình API" để bạn nhập Key của FPT và chọn giọng theo ý thích!
