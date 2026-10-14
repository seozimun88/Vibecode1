$wordPath = Join-Path (Get-Location) "exam-app\docs\Tổng quan chức năng.docx"

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()

$selection = $word.Selection

function Add-Heading1($text) {
    $selection.Font.Name = "Arial"
    $selection.Font.Size = 16
    $selection.Font.Bold = 1
    $selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdDarkBlue
    $selection.ParagraphFormat.SpaceBefore = 12
    $selection.ParagraphFormat.SpaceAfter = 4
    $selection.TypeText($text + "`n")
}

function Add-Heading2($text) {
    $selection.Font.Name = "Arial"
    $selection.Font.Size = 13
    $selection.Font.Bold = 1
    $selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdBlack
    $selection.ParagraphFormat.SpaceBefore = 8
    $selection.ParagraphFormat.SpaceAfter = 3
    $selection.TypeText($text + "`n")
}

function Add-Paragraph($text) {
    $selection.Font.Name = "Arial"
    $selection.Font.Size = 11
    $selection.Font.Bold = 0
    $selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdBlack
    $selection.ParagraphFormat.SpaceBefore = 0
    $selection.ParagraphFormat.SpaceAfter = 4
    $selection.ParagraphFormat.LineSpacingRule = [Microsoft.Office.Interop.Word.WdLineSpacing]::wdLineSpaceMultiple
    $selection.ParagraphFormat.LineSpacing = 14
    $selection.TypeText($text + "`n")
}

function Add-Bullet($text) {
    $selection.Font.Name = "Arial"
    $selection.Font.Size = 11
    $selection.Font.Bold = 0
    $selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdBlack
    $selection.ParagraphFormat.SpaceBefore = 0
    $selection.ParagraphFormat.SpaceAfter = 2
    $selection.TypeText("  •  " + $text + "`n")
}

# Tiêu đề tài liệu
$selection.ParagraphFormat.Alignment = [Microsoft.Office.Interop.Word.WdParagraphAlignment]::wdAlignParagraphCenter
$selection.Font.Name = "Arial"
$selection.Font.Size = 20
$selection.Font.Bold = 1
$selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdDarkBlue
$selection.TypeText("TỔNG QUAN CHỨC NĂNG HỆ THỐNG`n")

$selection.Font.Size = 13
$selection.Font.Bold = 0
$selection.Font.Italic = 1
$selection.Font.ColorIndex = [Microsoft.Office.Interop.Word.WdColorIndex]::wdGray50
$selection.TypeText("Plugin SketchUp AI & Hệ sinh thái Thiết kế - Sản xuất Nội thất Thông minh`n`n")

$selection.ParagraphFormat.Alignment = [Microsoft.Office.Interop.Word.WdParagraphAlignment]::wdAlignParagraphLeft
$selection.Font.Italic = 0

Add-Heading1("I. MỤC TIÊU SẢN PHẨM & ĐỐI TƯỢNG NGƯỜI DÙNG")
Add-Heading2("1. Mục tiêu tổng thể")
Add-Paragraph("Xây dựng giải pháp tự động hóa toàn diện từ ý tưởng thiết kế, mô hình hóa 3D đến sản xuất thi công nội thất thực tế. Hệ thống tích hợp trực tiếp dưới dạng Plugin trên nền tảng Trimble SketchUp kết hợp trí tuệ nhân tạo (AI), cho phép nhận diện hình ảnh thành mô hình 3D, bóc tách xuất mã máy CNC (G-Code), tạo linh kiện động thông minh, và hỗ trợ khách hàng thông qua trợ lý ảo chuyên gia 2D.")

Add-Heading2("2. Đối tượng người dùng mục tiêu (Target Users)")
Add-Bullet("Kỹ thuật viên bóc tách & vận hành máy CNC: Tự động hóa quá trình xuất bản vẽ gia công 2D và mã G-Code cắt ván nhanh chóng, chính xác.")
Add-Bullet("Kỹ sư / Kiến trúc sư thiết kế nội thất: Tối ưu tốc độ dựng hình 3D từ ảnh mẫu, tự động hóa gán công thức Dynamic Component mà không cần code thủ công.")
Add-Bullet("Chủ xưởng sản xuất nội thất: Quản lý tối ưu phôi liệu, chuẩn hóa quy trình từ bản vẽ đến máy gia công, mở rộng kết nối đơn hàng.")
Add-Bullet("Khách hàng cá nhân & Người làm DIY: Tự thiết kế các món đồ nội thất theo sở thích cho ngôi nhà mình với kích thước tùy biến, nhận tư vấn trực quan từ AI và gửi file đặt xưởng sản xuất.")

Add-Heading1("II. HỆ THỐNG CÁC TÍNH NĂNG CHÍNH (CORE MODULES)")

Add-Heading2("1. Module AI Vision: Quét ảnh & Tái tạo mô hình 3D (Image-to-3D)")
Add-Paragraph("Cho phép người dùng tải lên ảnh chụp thực tế hoặc ảnh sưu tầm trên Internet về bất kỳ món đồ nội thất nào (bàn, ghế, tủ, giường...). AI tự động phân tích, nhận diện loại vật thể, kết cấu hình học và dựng thành mô hình 3D trong SketchUp với 2 tùy chọn thiết lập:")
Add-Bullet("Chế độ Mặc định (Standard): Áp dụng ngay các thông số kích thước tiêu chuẩn theo nhân trắc học đã nạp sẵn trong cơ sở dữ liệu hệ thống (Ví dụ: Bàn làm việc tiêu chuẩn H750mm x W600mm x L1200mm).")
Add-Bullet("Chế độ Tùy chỉnh (Custom): Cung cấp bảng điền số liệu trực quan cho phép người dùng tùy chỉnh chính xác các chiều Cao, Rộng, Dài, độ dày ván, và tùy biến thêm bớt phụ kiện (chân kim loại/gỗ, ray trượt, bản lề, tay nắm...) so với ảnh gốc.")

Add-Heading2("2. Module CAM: Bóc tách 2D & Xuất mã gia công G-Code cho máy CNC")
Add-Paragraph("Cầu nối trực tiếp từ bản vẽ thiết kế đến xưởng sản xuất:")
Add-Bullet("Tự động bóc tách và trải phẳng (Unfold/Nesting) mô hình 3D thành bản vẽ chi tiết 2D của từng tấm phôi liệu.")
Add-Bullet("Tự động tính toán đường dao cắt và xuất file định dạng G-Code tiêu chuẩn.")
Add-Bullet("Người dùng chỉ cần cắm trực tiếp USB chứa file G-Code vào máy phay CNC tại xưởng để tự động cắt phôi ván với độ chính xác tuyệt đối.")

Add-Heading2("3. Module AI Dynamic Component Generator (Cấu kiện động thông minh)")
Add-Paragraph("Ứng dụng AI để tự động tạo các hàm tham số và logic cấu kiện động (Dynamic Components) trên SketchUp:")
Add-Bullet("Tự động sinh các thuộc tính hình học và công thức toán học (LenX, LenY, LenZ, Material, OnClick...).")
Add-Bullet("Cho phép co giãn kích thước mô hình linh hoạt mà không làm biến dạng tỷ lệ chi tiết tiêu chuẩn (mộng ghép, hèm khóa, chỉ dán cạnh, lỗ khoan cam chốt).")

Add-Heading2("4. Trợ lý ảo AI 2D tương tác & Tư vấn chuyên sâu (Virtual Interior Consultant)")
Add-Paragraph("Tích hợp Chatbot AI hóa thân thành nhân vật ảo 2D với phong cách dẫn chuyện tương tác (như nhân vật kể chuyện trong game):")
Add-Bullet("Dẫn dắt quy trình: Giới thiệu, thuyết minh từng bước trong quy trình hình thành một công trình/sản phẩm nội thất hoàn chỉnh.")
Add-Bullet("Tư vấn chuyên môn sâu: Đóng vai trò chuyên gia nội thất, có khả năng đọc hiểu tài liệu kỹ thuật (catalog phong cách, bảng màu xu hướng, quy tắc bố trí không gian, vật liệu) và suy luận đa bước để gợi ý phương án tối ưu.")
Add-Bullet("Liên thông trực tiếp với Plugin: Sau khi tương tác và chốt phương án với người dùng, chatbot tự động gửi lệnh liên thông với Plugin trên SketchUp để sinh ra sản phẩm 3D đúng như mong muốn.")

Add-Heading2("5. Quản lý Dự án & Lưu trữ Lịch sử tư vấn (Project & Cloud History)")
Add-Bullet("Lưu trữ đám mây toàn bộ các phiên trò chuyện, lịch sử tư vấn và thông tin phương án thiết kế.")
Add-Bullet("Quản lý danh sách dự án nội thất của từng người dùng, hỗ trợ xem lại và phục hồi các phiên bản thiết kế an toàn.")

Add-Heading2("6. Xác thực & Quản lý Tài khoản người dùng (User Management)")
Add-Bullet("Đăng ký / Đăng nhập đa kênh an toàn (Email/Mật khẩu, Google Account, SSO).")
Add-Bullet("Quản lý thông tin hồ sơ cá nhân, phân quyền theo vai trò (Chủ xưởng, Kiến trúc sư, Khách hàng DIY).")

Add-Heading2("7. Sàn giao dịch & Cổng thanh toán (Marketplace & Payment)")
Add-Bullet("Marketplace: Nền tảng chia sẻ và kinh doanh các mẫu mô hình 3D, thư viện Dynamic Components độc quyền và các gói file G-Code cắt sẵn.")
Add-Bullet("Kết nối sản xuất: Kết nối người dùng DIY có nhu cầu gia công với các xưởng mộc/CNC phù hợp gần nhất.")
Add-Bullet("Thanh toán trực tuyến: Tích hợp các cổng thanh toán bảo mật, tiện lợi (Thẻ ngân hàng, Ví điện tử, chuyển khoản tự động).")

Add-Heading1("III. TÓM TẮT QUY TRÌNH VẬN HÀNH (WORKFLOW)")
Add-Paragraph("Quy trình khép kín của giải pháp gồm 4 bước chính:")
Add-Bullet("Bước 1: Tiếp nhận ý tưởng & Tư vấn: Khách hàng/Người dùng tương tác với Trợ lý ảo 2D để lên ý tưởng, hoặc quét ảnh sản phẩm nội thất mẫu.")
Add-Bullet("Bước 2: Tạo lập mô hình 3D: AI nhận diện, áp dụng kích thước tiêu chuẩn hoặc thông số tùy chỉnh, tự động tạo Dynamic Component trên SketchUp.")
Add-Bullet("Bước 3: Bóc tách & Xuất G-Code: Plugin tự động bóc tách bản vẽ 2D, tối ưu xếp ván và xuất file G-Code.")
Add-Bullet("Bước 4: Sản xuất & Kết nối: Nạp USB vào máy CNC cắt phôi thực tế, hoặc đặt gia công trực tiếp thông qua Marketplace.")

$doc.SaveAs([ref]$wordPath, [ref]16)
$doc.Close()
$word.Quit()

Write-Output "SUCCESS: Created $wordPath"
