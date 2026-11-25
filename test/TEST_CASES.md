# Kịch bản kiểm thử SmartSpend

## Phạm vi và tiêu chí đạt

Chạy `flutter test` để kiểm tra điều hướng, biểu mẫu và nghiệp vụ với SQLite tạm. Các bài test này dùng dữ liệu thử và phiên đăng nhập cục bộ. Với các chức năng phụ thuộc Android, camera, ứng dụng nhận file hoặc Firebase, chạy các kịch bản bên dưới.

Kết quả ngày 25/11/2026 trên Windows với `flutter test --no-pub --reporter expanded` là **19/19 ca tự động đạt**. Bảng bên dưới ghi trạng thái của lần chạy thủ công trên Android.

Dùng một máy ảo Android màn hình hẹp và một thiết bị Android thật có kích thước màn hình khác. Dùng hai tài khoản Firebase thử nghiệm và hai phiên độc lập cho các ca đồng bộ. Thực hiện ca khôi phục trên tài khoản thử nghiệm có bản sao lưu đã xác minh. Ghi lại mã bản build, thiết bị, phiên bản Android, kích thước màn hình, tình trạng mạng và kết quả thực tế.

Một ca đạt khi kết quả thực tế khớp kết quả mong đợi. Ca chưa chạy hoặc chưa có điều kiện thực hiện được ghi riêng. Sau khi sửa lỗi, chạy lại ca tái hiện, các ca liên quan và toàn bộ `flutter test`.

## Bảng kiểm thử thủ công

| Mã | Chức năng | Dữ liệu và bước thực hiện | Kết quả mong đợi | Trạng thái |
|---|---|---|---|---|
| AUTH-01 | Đăng ký, đăng nhập, đăng xuất | Đăng ký bằng email mới và mật khẩu 8 ký tự. Đăng xuất, thử sai mật khẩu, rồi đăng nhập bằng mật khẩu đúng. Thoát và mở lại app, bấm **Bắt đầu**. | Email mới vào được màn hình chính. Sai mật khẩu báo lỗi. Đăng nhập đúng và phiên đã lưu đều vào màn hình chính. | Chưa chạy |
| AUTH-02 | Biểu mẫu đăng ký | Lưu form trống. Sau đó thử họ tên 1 và 2 ký tự, email sai định dạng, mật khẩu 7 và 8 ký tự, xác nhận sai và đúng. Thử lại email đã đăng ký. | Trường thiếu hoặc sai hiển thị lỗi. Tên 2 ký tự, mật khẩu 8 ký tự và xác nhận đúng qua kiểm tra biểu mẫu. Email trùng bị từ chối. | Chưa chạy |
| AUTH-03 | Đặt lại và đổi mật khẩu | Yêu cầu đặt lại với email sai định dạng, rồi với email của tài khoản thử nghiệm. Dùng email nhận được để đổi mật khẩu. Thử đăng nhập bằng mật khẩu cũ và mới. Trong Cài đặt, thử đổi với mật khẩu hiện tại sai. | Email sai định dạng báo lỗi. Tài khoản hợp lệ nhận được thư đặt lại. Mật khẩu mới đăng nhập được. Mật khẩu cũ bị từ chối và thao tác đổi với mật khẩu hiện tại sai bị chặn. | Chưa chạy |
| TX-01 | Số tiền giao dịch | Với một ví đã có số dư, lần lượt nhập trống, chữ, `0` và `1` đồng. Thử dán chuỗi 14 chữ số. | Chữ bị lọc. Trống và `0` báo lỗi và giữ số dư. `1` được lưu và làm thay đổi số dư đúng 1 đồng. Ô nhập giữ giá trị cũ khi vượt giới hạn 13 chữ số. | Chưa chạy |
| TX-02 | Thêm, sửa, xóa giao dịch | Tạo ví có 100.000 đồng. Thêm khoản thu 20.000 và khoản chi 10.000. Đổi khoản chi thành 15.000, đóng rồi mở lại app, sau đó xóa khoản chi. | Số dư lần lượt là 110.000, 105.000 và 120.000 đồng. Lịch sử phản ánh đúng thay đổi và giữ dữ liệu sau khi mở lại. | Chưa chạy |
| TX-03 | Tìm kiếm và lọc lịch sử | Chuẩn bị giao dịch ở hai ví, gồm thu và chi, có giao dịch trước ngày bắt đầu, ở hai đầu khoảng và sau ngày kết thúc. Lọc theo ngày, ví, loại và từ khóa. Thử từ khóa không khớp, sau đó bỏ bộ lọc. | Hai ngày biên được tính. Chỉ giao dịch khớp tất cả điều kiện xuất hiện. Từ khóa không khớp cho danh sách trống. Bỏ bộ lọc hiển thị lại danh sách. | Chưa chạy |
| TX-04 | Ảnh hóa đơn | Chụp ảnh và chọn một ảnh khác từ thư viện. Hủy một lần ở màn hình chọn ảnh. Lưu ảnh hợp lệ vào giao dịch, mở lại chi tiết rồi gỡ ảnh. Thử từ chối quyền camera nếu Android hỏi. | Ảnh đã lưu mở lại được và biến mất sau khi gỡ. Hủy giữ nguyên ảnh hiện tại. Khi camera không khả dụng, app vẫn cho quay lại giao dịch. | Chưa chạy |
| WAL-01 | Ví và danh mục | Thử lưu ví với tên trống. Tạo ví rồi thử tạo ví trùng tên với cách viết hoa khác. Tạo danh mục, dùng cho một giao dịch, đổi tên danh mục rồi xem lại giao dịch và bộ lọc. | Ví trống và ví trùng bị từ chối. Ví hợp lệ hiển thị đúng số dư. Tên mới xuất hiện nhất quán ở giao dịch và bộ lọc. | Chưa chạy |
| BUD-01 | Ngưỡng ngân sách | Tạo hạn mức danh mục 100 đồng, cảnh báo 80%. Ghi khoản chi để tổng lần lượt là 79, 80, 81, 100 và 101 đồng. | 79 chưa cảnh báo. Từ 80 xuất hiện cảnh báo. 100 vừa đủ hạn mức và 101 được đánh dấu vượt. | Chưa chạy |
| BUD-02 | Biểu mẫu ngân sách | Thử lưu hạn mức trống, `0` và `1` đồng. Mở tháng chưa có hạn mức và thử sao chép từ tháng trước đã có hạn mức. | Trống và `0` bị chặn. `1` được lưu. Sao chép đưa đúng các hạn mức sang tháng mới. | Chưa chạy |
| GRP-01 | Chia đều và chia theo số tiền | Tạo nhóm 3 người, chia đều 100 đồng. Thử bỏ chọn cả 3 người. Với chia theo số tiền, thử tổng phần chia 99, 100 và 101 đồng. | Chia đều cho ra 34, 33, 33 đồng. Không có người tham gia và tổng khác 100 đều bị từ chối. Tổng đúng được lưu. | Chưa chạy |
| GRP-02 | Chia theo tỷ lệ | Nhập khoản chi 101 đồng, lần lượt chia 50% + 49%, 50% + 51% và 50% + 50%. | Tổng 99% và 101% bị chặn và giữ nguyên số dư nhóm. Tổng 100% lưu hai phần 51 và 50 đồng. | Chưa chạy |
| GRP-03 | Chia sẻ và thanh toán nhóm | Tài khoản A tạo nhóm, thử thêm email không tồn tại rồi thêm tài khoản B. A ghi chi phí, B làm mới và ghi nhận thanh toán. | Email không tồn tại có thông báo lỗi. Hai phiên thấy cùng khoản chi và khoản thanh toán sau khi làm mới. Số dư cập nhật đúng. | Chưa chạy |
| DEBT-01 | Trả nợ | Tạo khoản vay 100 đồng có ghi vào ví. Mở biểu mẫu trả nợ, thử trống, 0, 101, 1 và 99 đồng theo thứ tự. | Ba lần đầu không tạo giao dịch. Hai lần sau ghi đúng số tiền, dư nợ về 0, khoản nợ được đánh dấu đã thanh toán và số dư ví trở về ban đầu. | Chưa chạy |
| REP-01 | Bộ lọc báo cáo và xuất file | Tạo thu 100.000 đồng và chi 30.000 đồng trong ví A, thêm giao dịch ở ví B và ngoài kỳ. Lọc ví A và kỳ tùy chọn rồi xuất PDF và Excel. Mở cả hai file. Thử thêm một kỳ trống. | Tổng thu 100.000, tổng chi 30.000, chênh lệch 70.000 đồng. Tệp có đúng kỳ và giao dịch, PDF hiển thị dấu tiếng Việt, Excel giữ số tiền dạng số. Kỳ trống hiển thị số liệu 0. | Chưa chạy |
| GOAL-01 | Mục tiêu tiết kiệm | Thử tên trống và mục tiêu trống hoặc 0. Tạo mục tiêu 100 đồng, góp 100, thử rút 101 rồi rút 1 đồng. | Trường bắt buộc trống và mục tiêu 0 bị chặn. Góp đủ đánh dấu hoàn thành. Rút quá số đã góp bị chặn. Rút 1 đồng còn 99 đồng. | Chưa chạy |
| BILL-01 | Nhắc nhở hóa đơn | Lưu tên trống. Tạo hóa đơn không nhập số tiền. Tạo hóa đơn lặp có số tiền, thử ngày đến hạn đúng ngưỡng nhắc, quá hạn và ngày 31. Thanh toán hóa đơn lặp. | Tên trống bị chặn. Hóa đơn không nhập số tiền vẫn tạo được nhắc nhở. Mốc đến hạn và quá hạn hiển thị đúng. Thanh toán ghi một khoản chi và dời lịch sang ngày hợp lệ trong tháng sau. | Chưa chạy |
| REC-01 | Giao dịch định kỳ | Chuẩn bị một lịch hằng ngày đã tới hạn 2 kỳ và một lịch đã tắt. Mở màn hình chính, mở lại app rồi kiểm tra lịch sử. Bật, tắt hoặc xóa lịch và mở lại màn hình cài đặt. | Lịch bật sinh đúng hai giao dịch, lịch tắt chưa phát sinh và mở lại app không tạo bản trùng. Trạng thái bật, tắt hoặc xóa được giữ khi mở lại. | Chưa chạy |
| SYNC-01 | Mất mạng và có mạng lại | Đăng nhập Firebase lúc có mạng. Tắt Wi-Fi và dữ liệu di động, thêm khoản chi, mở lại app và kiểm tra lịch sử. Bật mạng, bấm **Sao lưu ngay** rồi kiểm tra ở phiên thứ hai. | Giao dịch vẫn được lưu cục bộ khi mất mạng. Sau sao lưu, phiên thứ hai thấy đúng một bản ghi và số dư trùng khớp. | Chưa chạy |
| SYNC-02 | Chỉ đồng bộ qua Wi-Fi và khôi phục | Bật đồng bộ tự động và chế độ chỉ Wi-Fi. Dùng dữ liệu di động tạo giao dịch rồi chuyển sang Wi-Fi. Xác minh bản sao lưu trước khi thử khôi phục trên một phiên kiểm thử. | Đồng bộ tự động chờ Wi-Fi. Sau khi khôi phục, dữ liệu và số dư khớp bản đã sao lưu. | Chưa chạy |
| DEVICE-01 | Màn hình và thiết bị | Trên máy ảo màn hình hẹp và máy thật, mở các tab chính, điền biểu mẫu khi bàn phím hiện, mở bảng chọn ngày và thử cỡ chữ lớn. | Cuộn được tới trường và nút cuối. Nội dung quan trọng đọc được, thao tác lưu và quay lại hoạt động, màn hình không tràn. | Chưa chạy |

## Bảng lỗi và kiểm thử lại

Lệnh tái hiện các lỗi biên dịch đã ghi nhận là `flutter test --no-pub --reporter expanded`. Giữ cột phụ trách mở để nhóm phân công.

| Mã | Mô tả và vị trí | Mức độ | Phụ trách | Tình trạng |
|---|---|---|---|---|
| BUG-01 | `pickDate` trùng tên giữa `common_widgets.dart` và `ui_kit.dart` tại các màn hình import cả hai. | Chặn biên dịch | Chưa phân công | Import đã được cập nhật trong workspace. Biên dịch và chạy lại bộ test đạt. |
| BUG-02 | `SettingsScreen` gọi `RecurringScreen` khi file màn hình định kỳ còn trống. | Chặn biên dịch | Chưa phân công | Workspace đã có khai báo màn hình. Biên dịch và chạy lại bộ test đạt. |

Khi phát hiện thêm lỗi, ghi mã ca, bước tái hiện, kết quả thực tế và ảnh hoặc log. Cập nhật tình trạng sau khi sửa và ghi kết quả chạy lại.
