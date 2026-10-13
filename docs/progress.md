# Tiến độ Wildbond

Cập nhật ngày 13/10/2026. Tên dự án tạm thời: Wildbond. Mục tiêu đã chọn cùng người dùng: **PvE, boss và sưu tầm thú** cho thị trường EU, nhóm 12–16 tuổi. Ảnh tham khảo hướng đến thú hình khối và đảo low poly với vách đá, thác nước, làng gỗ và vật dụng nhỏ có chủ ý.

## Bản hiện tại — đòn của thú và cân bằng đầu tiên

- Có lệnh BOND: 18 sát thương, cooldown 3,2 giây, phạm vi 18 studs và windup 0,3 giây. Cả sói/cáo/gấu dùng cùng sức mạnh. Client chỉ thể hiện pounce; server quyết định sát thương, quyền sở hữu, đường nhìn, phạm vi và đúng đời quái/nhân vật. Đổi thú rồi đổi lại không làm đòn cũ sống lại.
- Đòn thường 10 sát thương/0,6 giây trong 8 studs. Hai hộ vệ 140/200 máu, boss 600; sát thương 12/16/22. Boss đổi giữa vòng tại mục tiêu 7 studs và đòn lan quanh boss 10 studs, có chữ báo và windup 1,2 giây.
- Máu tăng theo người thật sự góp sát thương, tối đa bốn người tính scale, thêm 65% máu nền cho mỗi người mới; giữ damage đã gây. Khách đứng xem không tăng máu. Trận bỏ dở reset sau 10 giây không còn người đủ điều kiện gần quái có đường nhìn.
- Không hồi máu thụ động. Nhận hunt, hoàn thành hoặc hồi sinh hồi đầy máu. Nhiệm vụ giữ các mục tiêu đã hoàn thành nếu chết; chưa có dữ liệu qua phiên.
- HUD ghi thời gian server từ nhận hunt đến nhận thưởng, gồm thời gian chết/đi lại; lưu last/best và số lần ngã trong phiên. Không thưởng thêm vì chạy nhanh.
- Mục tiêu thử: 90–180 giây lượt đầu, 60–120 giây khi quen. Mô hình số cho khoảng 60–80 giây chưa tính hướng dẫn, tìm đường và hồi sinh; không coi đây là thời gian đã đo từ người chơi. Chi tiết và lệnh chạy lại ở `docs/balance.md`.
- Thưởng giữ 60 shells, cáo 120, gấu 240. Sau hai hunts mở cáo; sau tổng sáu hunts đủ mở cả cáo/gấu. Chưa thêm grind khi đảo mới có ba trận.

## Nền từ mốc đầu

- Đảo Greywater được tạo từ geometry gốc: làng, quán trọ, bàn thuốc, đường vòng, thác, phế tích, ánh sáng chiều.
- Nhận hunt → đánh Bramble Sprout, Reed Guardian, Hollow Crown → lấy ba tinh thể → nhận 60 shells ở làng → nhận lại hunt để chơi tiếp.
- Quái báo đòn bằng vòng và chữ MOVE; đánh, cooldown, phạm vi, đường nhìn, sát thương và credit do server kiểm tra. Chỉ người thực sự đánh và ở gần khi quái chết được tính; quái hồi sau 6 giây.
- Một sói mặc định, cáo mở với 120 shells, gấu con mở với 240 shells. Có bộ sưu tập, đổi thú và follower có chuyển động. Thú chỉ là bạn đồng hành ở mốc này.
- UI tiếng Anh, thanh máu, mục tiêu nhiệm vụ, chỉ dẫn đường, hỗ trợ input bàn phím/chuột/cảm ứng/tay cầm ở mức mã nguồn.
- Có installer pin/checksum tools, script kiểm tra và project Rojo để dựng `.rbxlx`.

## Kiểm chứng và giới hạn hiện tại

Lệnh `bash scripts/check.sh` chạy thành công: 258 kiểm tra Expedition, 8 revision đổi thú, 76 CombatRules, 217 CombatService, 223 CompanionView, 19 HUD, 24 HuntMetrics, 33 ghép server và 3.222 kiểm tra hình học WorldBuilder. Cú pháp mọi tệp Luau, phân tích kiểu ba module luật, mô hình cân bằng và build Rojo đều đạt. Bản `.rbxlx` có mã khởi chạy server/client, các module cùng script Health ghi đè hồi máu mặc định.

Các smoke test dùng Lune chạy module thực với Roblox datatype/Instance reflection; dịch vụ engine cần sự kiện, raycast hoặc clock được mô phỏng có ghi rõ. Lune chưa có `Random`; test hình học dùng PRNG xác định trong phạm vi hợp lệ và tạo 294 parts, không khẳng định đây là số parts của engine Roblox. Test bắt được một cột phế tích chắn đường, đã sửa lối vào rồi chạy lại đạt. Không coi các kết quả này là kiểm chứng engine Roblox, mạng nhiều client hoặc vật lý.

Chưa chạy Play trong Roblox Studio: cloud không có Studio. Chưa xác minh hình ảnh cuối, animation/cảm giác đánh, điều khiển mobile thực hoặc FPS. Checklist ở `docs/studio-checklist.md` là phần cần chạy trên máy có Studio; lỗi cụ thể khi thử sẽ được sửa trước khi mở rộng.

**Tiến độ chưa lưu qua phiên**, pet chưa có vai trò riêng hoặc tự chiến đấu, boss chưa có nhiều phase, chưa có âm thanh hoặc map/model hoàn thiện. Chưa tạo Product ID/Game Pass ID, chưa có giao dịch Robux và chưa publish lên Roblox. Không có code gacha trả tiền. Điều kiện để xây nhánh đó nằm ở `docs/monetization.md`. Scale hiện được thử cho 1–4 người góp sát thương; chưa xác minh chơi nhiều client thực.

## Bước nhỏ kế tiếp

Sau khi chạy checklist Studio, dùng thời gian và số lần ngã thật để quyết định cần đổi nhịp hay không. Phần tiếp của mốc pet là một vai trò riêng cho Moss Wolf, thử trên một trận trước khi mở rộng hai pet còn lại; nâng cấp phải đổi lựa chọn chiến thuật thay vì chỉ tăng sát thương. Lưu dữ liệu là mốc 3, bắt buộc trước phát hành hoặc bán hàng.

Khi tiếp tục: đọc README và tệp này, kiểm tra thay đổi người dùng và lỗi Studio mới nếu có; dùng checkout sẵn có. Mỗi đợt chỉ làm một mốc nhỏ có thể kiểm tra. Cập nhật nhật ký khi kết thúc, giữ các giới hạn chưa được kiểm chứng. Không cần tạo worktree vì mỗi task cloud đã được cách ly. Người dùng ưu tiên chất lượng và làm qua nhiều phiên; không đặt lịch reset quota thay họ hoặc hứa quản lý hạn mức token.
