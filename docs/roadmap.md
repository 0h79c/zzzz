# Wildbond — làm từng bản chơi được

Wildbond là tên làm việc cho trò chơi săn PvE, đánh boss và kết bạn với sinh vật trên quần đảo. Một chuyến đi bắt đầu ở trại, người chơi chọn đường săn, đọc đòn của quái, mang chiến lợi phẩm về rồi dùng chúng mở thêm bạn đồng hành và lựa chọn chiến thuật. Người chơi quay lại vì muốn thử một đội pet khác và gặp một trận đánh hay hơn.

Ảnh tham khảo định hướng hình khối rõ, pet có nét vui, đảo nhiều tầng, nước và ánh sáng sạch. Lấy cảm giác ấy để làm sinh vật, địa hình và vật dụng riêng. Không lấy tên, hình dáng đặc trưng hoặc asset của game khác. Map bằng khối trong bản đầu là nền để kiểm tra chơi; chưa phải lời hứa về đồ họa hoàn thiện.

Mỗi đợt chỉ mở một lát chơi nhỏ, có điều kiện hoàn thành và ghi lại bước tiếp theo. Không đặt ngày ra mắt trước khi đã thử bằng Roblox Studio. Không có dữ liệu lưu lâu dài thì không gọi bản đó là sẵn sàng phát hành.

| Mốc | Phần xây tiếp | Điều kiện để chuyển mốc |
| --- | --- | --- |
| 1. Chuyến săn đầu | Trại, đường săn, hai loại quái, một miniboss; đánh, né; nhặt 3 chiến lợi phẩm và quay về nhận 60 tiền; 3 pet nhận trực tiếp theo tiến độ | Chơi được từ lúc spawn đến lúc nhận thưởng rồi chơi lại; chết/hồi sinh không kẹt nhiệm vụ; thử bàn phím và cảm ứng. Pet ở mốc này chỉ đồng hành, chưa có AI chiến đấu hoàn chỉnh. Cửa hàng Robux tắt. |
| 2. Pet thực sự tham chiến | Đã có BOND cho ba ngoại hình, cùng chỉ số và server xác thực; phần tiếp theo thử một vai trò riêng cho Moss Wolf rồi đến pet còn lại | Đòn không xuyên tường hoặc tới đời quái/nhân vật khác; cooldown và hai mẫu đòn boss đọc được. Vai trò riêng cần thay đổi cách chơi mà không biến giá mở pet thành nâng cấp sát thương. |
| 3. Tiến độ qua nhiều phiên | Hồ sơ server lưu pet, tiền, mốc nhiệm vụ và trang bị; xử lý lỗi, khóa phiên và phiên bản dữ liệu | Thoát/vào giữ đúng tiến độ; lỗi tải không ghi đè bằng hồ sơ trống; kiểm thử hai server, mất kết nối và phục hồi. Chưa bật bán hàng. |
| 4. Một boss đáng chơi lại | Boss nhiều đòn có dấu báo; hai cách đi qua khu săn; phần thưởng và nâng cấp có giới hạn rõ | Đánh bại được bằng đồ miễn phí; một chuyến săn đủ ngắn để hoàn thành trong buổi chơi; thử đội pet khác có khác biệt. Không kéo dài bằng máu quái quá cao. |
| 5. Đảo có bản sắc | Làm một góc đẹp hoàn chỉnh: trại, hồ nhỏ, thác, hang boss; model pet, animation, âm thanh và VFX có chủ ý | So sánh trong Studio với ảnh tham khảo; giữ silhouette đọc được khi đánh; đo hiệu năng trên thiết bị mobile đại diện và có mức giảm hiệu ứng. |
| 6. Săn cùng bạn | Đội nhỏ, hỗ trợ nhau, boss scale theo người thực sự tham chiến; thưởng theo đóng góp, tránh giành last hit | Thử nhiều client trong Studio; vào/ra giữa trận không phá boss; người yếu vẫn tham gia được. Chưa có giao dịch pet. |
| 7. Cửa hàng và thử kín | Mỹ phẩm mua trực tiếp, pass 249/349 đề xuất; receipt, giá vùng và quyền sở hữu; chơi thử với một nhóm nhỏ | Mọi món nhận đúng qua lỗi và retry; không bán lợi thế boss; cửa hàng không cản người chơi miễn phí. Paid random vẫn tắt trừ khi hoàn thành đánh giá riêng trong monetization.md. |

## Giữ chiều sâu mà không biến thành việc nhà

Sau mốc 7, mở thêm một biome cùng một boss mới trước khi làm nhiều hệ thống. Đổi mẫu đòn, địa hình, cơ chế phối hợp và bộ pet thích hợp. Cho người chơi các mục tiêu tự chọn: nhật ký sinh vật, hoàn thành boss không ngã, xây góc trại, ảnh chụp cùng bạn, bảng thời gian chỉ so giữa điều kiện tương đương. Sưu tập không bắt buộc đổi pet hiếm thành tiền hay chạy theo sức mạnh vô hạn.

Sự kiện có thể quay lại hoặc để phần thưởng cũ kiếm được bằng cách khác. Thưởng cho việc trở lại là đủ; không phạt vì nghỉ một ngày. Không cần auto-click để tăng thời lượng chơi.

## Ghi nhớ giữa các đợt

Cuối mỗi đợt cập nhật `docs/progress.md`: phần đã có, phần thực sự đã chạy, giới hạn, lỗi còn lại và một bước nhỏ tiếp theo. Lưu cấu hình cùng cách mở project trong README để có thể tiếp tục sau khi đổi phiên làm việc. Người dùng không cần giữ toàn bộ lịch sử chat; chỉ cần chỉ ra mốc muốn tiếp tục.

Dùng tiếng Anh cho chữ trong game và đặt chúng sau string keys để dịch về sau. Nhóm 12–16 cần chữ rõ trên điện thoại, điều khiển cảm ứng, tín hiệu nguy hiểm không chỉ dựa vào màu, công tắc giảm chớp sáng và chiến đấu không có máu me. Kiểm tra phân loại nội dung, chính sách Roblox và các thị trường phát hành trước khi mở công khai.
