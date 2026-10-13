# Nhịp chuyến săn Wildbond

Bản đảo đầu chỉ có hai hộ vệ và một mini-boss. Mục tiêu cho lần đầu là **90–180 giây**, còn khi thuộc đường là **60–120 giây**. Đây là mục tiêu thiết kế để thử trong Studio, chưa phải thời gian đo từ người chơi. Một nhiệm vụ hai đến bốn phút sẽ cần thêm lựa chọn và trận đánh có ích; không tăng máu hoặc bắt chờ chỉ để đạt con số đó.

## Vì sao phải chỉnh bản đầu

Trước đợt này, đòn đánh gây 15 sát thương mỗi 0,45 giây. Nếu đánh đúng nhịp từ giây 0, hai hộ vệ 45/60 máu chết trong 0,9/1,35 giây và boss 120 máu chết trong 3,15 giây. Quái có thể chỉ kịp báo một đòn trước khi trận kết thúc; gần như không có thời gian học cách né. Thêm pet vào những chỉ số đó sẽ làm trận còn ngắn hơn.

Đường vòng chính trong `WorldBuilder` dài khoảng 364 studs. Project dùng tốc độ 20 studs/giây, đi hết mất khoảng 18,2 giây khi không bị cản. Đó chỉ là chiều dài đường dựng sẵn, không phải quãng đường thực tế: người chơi có thể đi tắt hoặc cần tìm đường, né đòn, tới trụ tinh thể và rương nhận thưởng. Không thể suy thời lượng buổi chơi từ kích thước map hoặc máu boss.

## Quy tắc cho đợt này

- Người chơi có đòn thường ở cự ly ngắn và một lệnh cho pet đánh theo cooldown. Pet khởi đầu đủ sức hoàn thành chuyến săn; ba kiểu pet đang dùng cùng chỉ số đánh để việc chọn ngoại hình không gây bất lợi. Vai trò hỗ trợ riêng sẽ được thử ở một đợt sau.
- Quái đầu dạy rời vòng báo đòn. Quái thứ hai đòi hỏi tiếp cận, đánh và rút ra theo nhịp. Boss đổi giữa hai dấu báo; người chơi phải chọn vị trí an toàn thay vì đứng yên bấm liên tục.
- Máu tăng theo người thực sự gây sát thương, tối đa bốn người được tính cho độ khó. Khách đứng xem không tăng máu. Tham gia giữa trận tăng phần máu dành cho thành viên mới; rời trận không làm lượng máu đã phân bổ giảm tức thì. Khi mọi người bỏ trận đủ lâu, quái trở về trạng thái ban đầu.
- Đóng góp bằng đòn pet cũng có giá trị như đòn thường. Không cần giành đòn kết liễu. Phải còn sống, có hunt tương ứng và ở gần trận khi quái bị hạ để nhận mục tiêu.
- Chết giữ các tinh thể và mục tiêu đã hoàn thành trong phiên. Quái chưa hạ vẫn là một trận phải chơi lại. Chưa có dữ liệu qua nhiều phiên; chưa bật giao dịch Robux.

Chỉ số đang thử:

| Thành phần | Chỉ số |
| --- | --- |
| Người chơi | 100 máu; đòn thường 10 sát thương, hồi 0,6 giây, phạm vi 8 studs |
| Pet | 18 sát thương, hồi 3,2 giây, phạm vi 18 studs; đòn tới sau 0,3 giây |
| Bramble Sprout | 140 máu, sát thương 12, báo 0,9 giây, vòng mục tiêu 5 studs |
| Reed Guardian | 200 máu, sát thương 16, báo 1 giây, vòng mục tiêu 5 studs |
| Hollow Crown | 600 máu, sát thương 22, báo 1,2 giây; đổi giữa vòng mục tiêu 7 và vòng quanh boss 10 studs |
| Nhịp đòn quái | Bắt đầu báo sau 0,8 giây khi vào trận; nghỉ 2,4 giây sau khi đòn giải quyết |
| Đồng đội | Máu nền × [1 + 0,65 × (số người góp sát thương − 1)], tính tối đa bốn người |

Không hồi máu tự động để tránh đứng ngoài vòng đòn rồi đánh mãi không có rủi ro. Nhận hunt và nhận thưởng hồi đầy máu; giữa ba trận phải quản lý lượng máu còn lại. Khi không còn người đủ điều kiện ở gần và có đường nhìn trong 10 giây, trận bỏ dở reset. Thời gian hồi quái sau khi bị hạ là 6 giây; không cộng thời gian đó vào mục tiêu thời lượng vì người chơi bình thường không cần chờ để đi tiếp.

## Thưởng và sưu tầm

Giữ 60 shells mỗi chuyến, cáo 120 và gấu con 240. Người chơi lấy cáo sau hai chuyến; nếu đã mua cáo rồi, tổng cộng sáu chuyến để có cả cáo lẫn gấu. Các giá này là mục tiêu nhỏ cho alpha, chưa phải nền kinh tế phát hành. Chưa có lý do tăng giá để buộc lặp lại nhiều hơn khi map chỉ có ba trận.

Sau khi có thêm nội dung, cách kéo dài buổi chơi là thêm đường săn khác, cơ chế boss, thành tích tự chọn và thú có cách chơi riêng. Phần thưởng mỹ phẩm có thể đi cùng các mục tiêu đó. Không dùng pet mua Robux để bù một trận cố tình quá khó cho thú miễn phí.

## Kiểm tra bằng số và bằng chơi

Chạy `.tools/lune run scripts/balance_report.luau` trong thư mục project để xem mô hình chiến đấu từ `CombatRules` và giá từ `Expedition`. Báo cáo đọc cả mẫu đòn, cách tăng máu, chiều dài đường, thời gian giữ prompt và tốc độ từ cấu hình Rojo; không có một bộ chỉ số quái thứ hai trong script. Kịch bản có nhịp đánh, đòn pet và các lần phải dừng đánh để di chuyển; kịch bản chậm còn có đánh trượt và né hụt. Chúng là giả định để tìm sai lệch lớn, không mô phỏng vật lý, raycast, độ trễ, camera hoặc tâm lý người chơi.

Kết quả mô hình ở chỉ số trên, cùng một thanh máu đi qua cả ba trận, không hồi giữa trận:

| Kịch bản giả định | Tổng ba trận | Cộng đường vòng và giữ prompt | Máu còn lại |
| --- | --- | --- | --- |
| Chỉ tính sát thương liên tục, bỏ qua đòn quái | 40,3 giây | 60,3 giây | Không đánh giá |
| Né mọi đòn; dừng đánh thường khi di chuyển | 52,3 giây | 72,2 giây | 100 |
| Trượt mỗi đòn thường thứ tư, gọi pet chậm, hụt mỗi lần né thứ tư | 60,2 giây | 80,1 giây | 56 |
| Như trên nhưng hụt mỗi lần né thứ ba | 59,7 giây | 79,6 giây | 6 |
| Đứng trong mọi dấu báo | Chết ở đòn thứ hai của boss | Không hoàn thành | 0 |

Cột cộng đường vẫn chưa tính đọc hướng dẫn, tìm trụ, đường đi tắt, cooldown còn lại từ trận trước, độ trễ hoặc hồi sinh. Mô hình cho mỗi trận bắt đầu với đòn sẵn sàng và pet vẫn đủ phạm vi/đường nhìn khi người chơi né. Hai kịch bản chậm dùng phản ứng 0,45 giây, thêm 0,35 giây để quay lại đánh và gọi pet chậm hơn cooldown 1,3 giây. Đây là đầu vào thử độ nhạy, không phải mô tả chắc chắn về nhóm tuổi 12–16.

Trong mô hình né đủ, boss mất khoảng 35,5 giây và báo 10 đòn. Sát thương liên tục khi bỏ qua đòn quái cho boss 25,9 giây với pet và 35,4 giây chỉ đánh thường. Điều này tạo lý do gọi pet, nhưng không chứng minh cảm giác chơi đã hay. Kịch bản hụt mỗi lần né thứ ba còn 6 máu: chỉ thêm một lỗi là có thể chết, nên cần thử thực tế trước khi tăng độ khó.

Khi hai, ba hoặc bốn người cùng góp sát thương từ đầu, boss lần lượt có 990/1.380/1.770 máu. Nếu bỏ qua đòn quái và mọi người đánh đúng cooldown, thời gian tối thiểu theo mô hình là 21,6/19,8/19,5 giây, so với 25,9 giây khi solo. Đây chỉ kiểm tra việc đồng đội có lợi mà không chia thời gian boss thẳng cho bốn; phối hợp, nhận sát thương và tham gia giữa trận cần kiểm tra bằng nhiều client.

Trong Studio, ghi riêng bốn thời gian: nhận hunt tới trận đầu, hai hộ vệ, boss, và nhặt đủ tinh thể tới nhận thưởng. Thử một mình trước, sau đó hai và bốn client; mỗi client phải thực sự đánh trước khi được tính tăng độ khó. Ghi cả lần thất bại, số đòn bị trúng, số lần chết và đoạn đứng chờ. Không chỉ lấy lần nhanh nhất. Đồng hồ hunt trong HUD giúp lấy thời gian cả chuyến và số lần ngã; không có thưởng thêm theo thời gian, tránh biến bài thử này thành sức ép phải chơi nhanh.

Nếu người mới chết hai lần liền ở boss sau khi đã hiểu dấu báo, trước tiên xem độ rõ của dấu báo và khoảng thoát, rồi mới giảm sát thương. Nếu người thuộc đường luôn bỏ qua toàn bộ đòn boss, xem cơ chế và nhịp pet trước khi tăng máu. Nếu chuyến săn vượt ba phút vì đi lạc hoặc chờ quái hồi, sửa chỉ dẫn hoặc vòng chơi; không coi đó là nội dung.

Chưa có dữ liệu giữ chân hoặc chi tiêu để suy ra khả năng kiếm Robux. Cần thử vòng chơi và lưu tiến độ đáng tin cậy trước khi đánh giá cửa hàng.
