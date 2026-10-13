# Tiến độ Wildbond

Cập nhật ngày 13/10/2026. Tên dự án tạm thời: Wildbond. Mục tiêu đã chọn cùng người dùng: **PvE, boss và sưu tầm thú** cho thị trường EU, nhóm 12–16 tuổi. Ảnh tham khảo hướng đến thú hình khối và đảo low poly với vách đá, thác nước, làng gỗ và vật dụng nhỏ có chủ ý.

## Bản hiện tại — đấm, lướt dài hơn và chín quái

- Yêu cầu đầy đủ đã lưu ở `docs/design.md`: vùng đất liền và chuyển vùng, click/1–8/double Space, class nền/nhánh 10–20–30–40, tiền/EXP/loot, mọi ô trang bị gồm tối đa ba nhẫn, starter shop, craft gameplay, tiến hóa/nội tại/tự đánh/skill thú. `docs/roadmap.md` chia thứ tự làm; không coi các mục tương lai là đã có.
- Chín quái thuộc bốn loại Sprout/Reed/Ancient/Brush Boar: ba bounty và sáu quái thường. Tuần tra home 12 studs, đuổi tốc độ 7 trong home 28, steering tránh vật cản/mặt đất thiếu; mất mục tiêu 10 giây thì quay về/reset. Quái thường có thể đánh ngay cả khi chưa nhận bounty, không cộng tiến độ/thưởng nhiệm vụ giả. Chưa có pathfinding địa hình phức tạp.
- Quái nhỏ đánh thường thay cho AoE: hướng lấy đà cố định, windup 0,65 giây, damage 8/10; boss damage thường 12 và dùng skill thêm, không đánh hai đòn chồng nhau. Server xét range/front arc/LOS/nhân vật và trạng thái né tại lúc trúng.
- Phản hồi Studio của người dùng: lướt quá ngắn, tay không đấm dù có vệt chém. Đã thay presentation `Transform` bằng pose `C0` R6/R15, jab hai tay luân phiên 0,42 giây; R15 có khuỷu/cổ tay/torso. Test FK tính nắm tay thực tiến về trước, không chỉ kiểm tra biến joint đổi. Vệt theo tay, tia va chạm/số damage chỉ khi server xác nhận trúng. Cần người dùng thử lại rendering native; chưa khẳng định lỗi hình ảnh đã được xác minh trong Studio.
- Quái vẫn có đi/chạy/vung tay/skill/bị hạ bám thời gian server, boar thêm lấy đà/cắn/đạp chân; Reed thân hẹp/tán sậy cao. Animation local giữ hitbox server. Chưa có animation asset hoàn thiện hoặc hiển thị đòn đấm của mọi người chơi cho nhau.
- Click/R2/STRIKE đánh thường, kể cả animation click hụt/tập đánh. Tám ô 1–8 đã có; 1/L2/BOND tạm gọi thú, 2–8 chưa học. F/Q cũ bỏ. Skill tree/class/resource chưa triển khai.
- Space hai lần trong 0,28 giây (lần đầu nhảy), B hoặc DODGE lướt tối đa 16 studs/0,3 giây, hồi 4 giây, miễn damage tối đa 0,18 giây. Server chia đường thành đoạn tối đa 2 studs, kiểm tra tường ba cao độ/floor/drop, tiến tới khoảng an toàn trước tường thay vì bỏ cả bước. Triệt vận tốc ngang cũ, giữ vận tốc nhảy và khôi phục ownership/WalkSpeed/AutoRotate. Hố giữa đường vẫn chặn khi khung hình trễ; không có stamina.
- Vùng **Greywater Reach** có nền đất liền 220×260, rừng/đồi/vách và trạm xe trang trí; thêm hai nhánh tới cụm quái. Khoảng trống lấy trực tiếp từ CombatRules, giữ năm prompt/chín đường nhiệm vụ và trạm xe. Test PRNG tạo 412 BaseParts, không phải số engine đã đo. Xe chưa chuyển map.
- Thưởng/giá thú/session metrics giữ như trước. Chưa có mob drop tiền/EXP/trang bị, class, DataStore, tự đánh/tiến hóa/buff pet; các quái thường mới phục vụ thử combat, không giả đã có nền kinh tế loot.
- Báo cáo `balance_report.luau` chỉ còn cận dưới outgoing và khoảng thoát: 6,0/8,4/25,9 giây khi mọi click/lệnh thú trúng đúng nhịp. Số 60–80 giây/35,5 giây boss/56–6 máu của AI đứng yên đã hết hiệu lực; cần đo mới trong Studio.

## Lịch sử — đòn của thú và cân bằng AI đứng yên

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

Lệnh `bash scripts/check.sh` chạy thành công: CombatService 539, Rules 135, companion 223, DodgeRules 15, DodgeService 840, EnemyView 111, equipment revision 8, Expedition 258, HUD 45, metrics 24, player pose/FK 37, wiring 44 và World 5.240 kiểm tra. Cú pháp, phân tích kiểu bốn module luật, báo cáo cân bằng và build Rojo đạt. Mã thật chạy với reflection/mocks có ghi rõ, không chứng minh vật lý/network/Animator/rendering native. Ở quãng lướt 16, test trước sửa tái hiện vượt hố giữa khung hình; microsegment đã chặn được trường hợp đó.

Các smoke test dùng Roblox datatype/Instance reflection; sự kiện, raycast, clock, network ownership và Animator cần mô phỏng có ghi rõ. Lune chưa có `Random`; test dùng PRNG xác định trong phạm vi hợp lệ, không khẳng định đúng cảnh cây cỏ của engine. Lối vào phế tích từng chắn bởi cột đã sửa và vẫn được kiểm tra. Các control test có CAS-first jump → processed UIS event → second dodge, tránh processed jump xóa lịch sử double tap.

Chưa chạy Play trong Roblox Studio: cloud không có Studio. Chưa xác minh hình ảnh cuối, animation/cảm giác đánh, điều khiển mobile thực hoặc FPS. Checklist ở `docs/studio-checklist.md` là phần cần chạy trên máy có Studio; lỗi cụ thể khi thử sẽ được sửa trước khi mở rộng.

**Tiến độ chưa lưu qua phiên**; các tính năng RPG tương lai ở design vẫn chưa triển khai. Animation/map hiện là bản thử, chưa có audio hoặc đồ họa hoàn thiện; chưa xác minh vật lý, steering, mạng nhiều client, input/dodge hoặc FPS trong Studio. Bán hàng và publish Roblox chưa thực hiện; không có gacha trả tiền. Scale thử cho 1–4 người góp sát thương, chưa kiểm chứng nhóm thực.

## Bước nhỏ kế tiếp

Thử lại đấm/lướt và chín quái trong Studio, sửa lỗi cụ thể nếu còn. Tiếp theo là nền hồ sơ bền vững và EXP/level/class cùng định nghĩa trang bị, rồi loot/shop cơ bản. Không mở cả cây nghề/craft trong cùng lượt; role/tiến hóa thú và mọi yêu cầu trong design vẫn ở roadmap.

Khi tiếp tục: đọc README và tệp này, kiểm tra thay đổi người dùng và lỗi Studio mới nếu có; dùng checkout sẵn có. Mỗi đợt chỉ làm một mốc nhỏ có thể kiểm tra. Cập nhật nhật ký khi kết thúc, giữ các giới hạn chưa được kiểm chứng. Không cần tạo worktree vì mỗi task cloud đã được cách ly. Người dùng ưu tiên chất lượng và làm qua nhiều phiên; không đặt lịch reset quota thay họ hoặc hứa quản lý hạn mức token.
