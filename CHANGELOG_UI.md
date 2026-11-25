# Cập nhật giao diện theo mockup + hoàn thiện chức năng

## Cần làm sau khi giải nén
1. `flutter pub get` (đã thêm: path_provider, image_picker, share_plus, pdf, excel, connectivity_plus).
2. (Khuyến nghị) Tải font **Be Vietnam Pro** từ Google Fonts, chép 4 file .ttf vào `assets/fonts/`
   rồi bỏ comment khối `fonts:` trong `pubspec.yaml`. Chưa có font thì app dùng font mặc định.
3. `assets/fonts/DejaVuSans*.ttf` đã kèm sẵn – dùng để xuất PDF có dấu tiếng Việt.
4. Chạy `flutter run`. CSDL tự nâng lên v3, **giữ nguyên dữ liệu cũ**.

## Giao diện (theo PDF mockup)
Bảng màu/ bo góc/ vùng chạm 44px, splash, đăng nhập/đăng ký, trang chủ, thêm giao dịch, lịch sử,
ngân sách, nhóm & nợ, báo cáo, cài đặt… đều dựng lại theo từng trang mockup.
Widget dùng chung: `lib/views/widgets/ui_kit.dart`.

## Màn hình/chức năng mới
- Quên mật khẩu / Đặt lại mật khẩu (email Firebase; tài khoản offline đặt lại trong app, hiệu lực 30 phút)
- Thông báo (ngân sách, hóa đơn, nợ, mục tiêu) + chi tiết cảnh báo / vượt ngân sách (có "Bỏ qua cảnh báo")
- Cài đặt: Quản lý ví (thêm/sửa/xóa), Quản lý danh mục (thêm/sửa/xóa), Giao dịch định kỳ (tự tạo khi đến hạn),
  Nhắc nhở hóa đơn (đánh dấu đã trả -> ghi khoản chi), Sao lưu & đồng bộ, Tiền tệ & ngôn ngữ, Đổi mật khẩu
- Chi tiết / sửa / xóa giao dịch, ảnh hóa đơn (chụp hoặc chọn thư viện), chọn danh mục dạng lưới
- Tìm kiếm & lọc lịch sử (từ khóa, thời gian, ví, danh mục)
- Ngân sách: đặt/sửa/xóa theo tuần-tháng-năm, ngưỡng cảnh báo 50/70/80/90, theo dõi + gợi ý chi tối đa/ngày
- Mục tiêu: tạo (gợi ý tiết kiệm/tháng), nạp/rút có chọn ví và ngày
- Nhóm: mô tả nhóm, mời thành viên, chia đều / theo số tiền / theo %, công nợ & ghi nhận thanh toán
- Nợ: thêm, thanh toán/thu nợ có ngày + lịch sử
- Báo cáo: lọc (thời gian/ví/loại), phân tích, so sánh kỳ, xuất PDF/Excel và chia sẻ

## Hạn chế đã biết
- Đăng nhập Google vẫn là placeholder (cần cấu hình SHA-1 + google_sign_in).
- Ngôn ngữ English chưa có bản dịch; USD chỉ là hiển thị quy đổi (1 USD = 25.000đ).
- Danh mục tuỳ chỉnh, giao dịch định kỳ, nhắc hóa đơn, ảnh hóa đơn lưu trên máy, chưa đồng bộ Firebase.
- Nhắc hóa đơn hiển thị trong app (chưa có push/notification hệ thống).
- Mật khẩu tài khoản local lưu dạng thô trong SQLite (có sẵn từ trước) – nên băm trước khi phát hành.
- Chưa chạy được `flutter analyze` / build trong môi trường soạn thảo: hãy chạy và gửi lại lỗi nếu có.
