# Tiến độ Wildbond

Cập nhật ngày 13/10/2026. Tên dự án tạm thời: Wildbond. Mục tiêu đã chọn cùng người dùng: **PvE, boss và sưu tầm thú** cho thị trường EU, nhóm 12–16 tuổi. Ảnh tham khảo hướng đến thú hình khối và đảo low poly với vách đá, thác nước, làng gỗ và vật dụng nhỏ có chủ ý.

## Bản hiện tại — combat chuyển động và hướng RPG

- Yêu cầu đầy đủ đã lưu ở `docs/design.md`: vùng đất liền và chuyển vùng, click/1–8/double Space, class nền/nhánh 10–20–30–40, tiền/EXP/loot, mọi ô trang bị gồm tối đa ba nhẫn, starter shop, craft gameplay, tiến hóa/nội tại/tự đánh/skill thú. `docs/roadmap.md` chia thứ tự làm; không coi các mục tương lai là đã có.
- Ba quái hiện có tuần tra trong bán kính 12 studs quanh home, đuổi tốc độ 7 trong ranh giới home 28, tránh vật cản/mặt đất thiếu bằng steering ngắn. Mất mục tiêu 10 giây thì quay về và reset khi tới home. Chưa có pathfinding cho địa hình phức tạp hoặc bestiary mở rộng.
- Quái nhỏ đánh thường thay cho AoE: hướng lấy đà cố định, windup 0,65 giây, damage 8/10; boss damage thường 12 và dùng skill thêm, không đánh hai đòn chồng nhau. Server xét range/front arc/LOS/nhân vật và trạng thái né tại lúc trúng.
- Animation quái đi/chạy/vung tay/chuẩn bị skill/bị hạ phía client bám State và thời gian server. Giữ nguyên hitbox server; nhân vật R6/R15 có vung tay/né và VFX thủ tục. Chưa có animation asset hoàn thiện hoặc kiểm chứng rendering thật.
- Click/R2/STRIKE đánh thường, kể cả animation click hụt/tập đánh. Tám ô 1–8 đã có; 1/L2/BOND tạm gọi thú, 2–8 chưa học. F/Q cũ bỏ. Skill tree/class/resource chưa triển khai.
- Space hai lần trong 0,28 giây (lần đầu vẫn nhảy), B trên tay cầm hoặc DODGE né tối đa 8 studs/0,22 giây, cooldown 4 giây, miễn sát thương tối đa 0,18 giây. Server kiểm tra hướng, tường ở ba cao độ, floor/drop; tạm giữ network ownership khi né rồi khôi phục. Block có thể kết thúc sớm, không có stamina.
- Vùng **Greywater Reach** đã đổi thành nền đất liền 220×260, bỏ biển/bãi cát, có rừng/đồi/vách bao quanh và trạm xe ngựa trang trí. Giữ năm prompt và chín đường nhiệm vụ; xe chưa chở sang map khác. Test PRNG tạo 438 BaseParts, không phải số engine đã đo.
- Thưởng/giá thú/session metrics giữ như trước. Chưa có mob drop tiền/EXP/trang bị, class, DataStore, tự đánh/tiến hóa/buff pet. Vẫn ba trận để kiểm tra nền combat trước khi thêm cụm quái.
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

Lệnh `bash scripts/check.sh` chạy thành công: CombatService 478, CombatRules 86, CompanionView 223, DodgeRules 15, DodgeService 294, EnemyView 81, revision đổi thú 8, Expedition 258, HUD 45, HuntMetrics 24, player pose 27, ghép server 42 và hình học WorldBuilder 4.122 kiểm tra. Cú pháp, phân tích kiểu bốn module luật, báo cáo cân bằng và build Rojo đạt. Các kiểm tra chạy mã module thật với reflection/mocks có ghi rõ; không chứng minh vật lý/network/Animate/rendering native.

Các smoke test dùng Roblox datatype/Instance reflection; sự kiện, raycast, clock, network ownership và Animator cần mô phỏng có ghi rõ. Lune chưa có `Random`; test dùng PRNG xác định trong phạm vi hợp lệ, không khẳng định đúng cảnh cây cỏ của engine. Lối vào phế tích từng chắn bởi cột đã sửa và vẫn được kiểm tra. Các control test có CAS-first jump → processed UIS event → second dodge, tránh processed jump xóa lịch sử double tap.

Chưa chạy Play trong Roblox Studio: cloud không có Studio. Chưa xác minh hình ảnh cuối, animation/cảm giác đánh, điều khiển mobile thực hoặc FPS. Checklist ở `docs/studio-checklist.md` là phần cần chạy trên máy có Studio; lỗi cụ thể khi thử sẽ được sửa trước khi mở rộng.

**Tiến độ chưa lưu qua phiên**; các tính năng RPG tương lai ở design vẫn chưa triển khai. Animation/map hiện là bản thử, chưa có audio hoặc đồ họa hoàn thiện; chưa xác minh vật lý, steering, mạng nhiều client, input/dodge hoặc FPS trong Studio. Bán hàng và publish Roblox chưa thực hiện; không có gacha trả tiền. Scale thử cho 1–4 người góp sát thương, chưa kiểm chứng nhóm thực.

## Bước nhỏ kế tiếp

Chạy checklist combat/input/map trong Studio và sửa lỗi cụ thể trước khi nhân rộng. Sau đó thêm 8–12 điểm quái/3–4 loại trong cùng vùng, rồi nền hồ sơ + level/class/trang bị trước loot/shop. Mỗi mốc có thể chia nhiều đợt; chưa làm tất cả class và cây nghề trong một lượt. Tuân theo roadmap mới; role pet và lưu dữ liệu cũ được chuyển vào chuỗi RPG này, không bỏ yêu cầu.

Khi tiếp tục: đọc README và tệp này, kiểm tra thay đổi người dùng và lỗi Studio mới nếu có; dùng checkout sẵn có. Mỗi đợt chỉ làm một mốc nhỏ có thể kiểm tra. Cập nhật nhật ký khi kết thúc, giữ các giới hạn chưa được kiểm chứng. Không cần tạo worktree vì mỗi task cloud đã được cách ly. Người dùng ưu tiên chất lượng và làm qua nhiều phiên; không đặt lịch reset quota thay họ hoặc hứa quản lý hạn mức token.
