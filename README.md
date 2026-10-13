# Wildbond

Một trò chơi Roblox RPG PvE trên vùng rừng **Greywater Reach**, nơi người chơi đánh boss và sưu tầm bạn đồng hành. Bản hiện tại đã có **quái tuần tra/đuổi/đánh thường, animation thủ tục và né**, vẫn là alpha cần thử trong engine trước khi phát hành.

Bạn xuất hiện ở làng Greywater, nhận chuyến săn tại bảng nhiệm vụ, đánh hai hộ vệ và mini-boss Hollow Crown. Quái đi quanh điểm sinh, đuổi vào phạm vi đánh và lấy đà vung tay; boss kết hợp đánh thường với skill. Di chuyển/né, gọi thú hỗ trợ, lấy ba tinh thể rồi quay về rương làng nhận 60 shells. Chuyến săn có thể nhận lại. Sói đi cùng từ đầu; cáo và gấu con mở bằng shells kiếm trong game.

Ba thú đều có đòn BOND, cùng sức mạnh ở bản này; vai trò riêng/tự đánh/tiến hóa chưa triển khai. Có tám ô skill, ô 1 tạm dùng cho lệnh thú, ô 2–8 chưa học. Chưa có class, level/EXP, loot trang bị, túi đồ hay NPC bán đồ. Tiến độ giữ trong phiên và mất khi rời server. Không có cửa hàng Robux hoặc lưu DataStore.

## Mở bản chơi

Trên GitHub, tải [Wildbond.rbxlx](Wildbond.rbxlx) ở thư mục gốc của kho bằng nút **Download raw file**. Đây là bản đóng gói cùng mã nguồn trong commit này; khi sửa mã, dùng lệnh build bên dưới để tạo bản mới.

Tệp đã build: `build/Wildbond.rbxlx`. Tải tệp về máy Windows hoặc macOS có **Roblox Studio**, dùng **File → Open from File**, rồi nhấn **Play**. Map được sinh khi server bắt đầu chạy nên chưa xuất hiện trong chế độ chỉnh sửa trước khi Play. Không cần API key hay asset riêng cho mốc này.

- Di chuyển bằng điều khiển Roblox thông thường.
- **Click**, **R2** hoặc nút **STRIKE**: đánh thường. Click hụt/tập đánh vẫn có animation, không gây sát thương ngoài phạm vi.
- **1**, **L2** hoặc nút **BOND**: gọi thú đánh quái gần nhất trong phạm vi 18 studs. Hồi chiêu 3,2 giây; server kiểm tra lại trước khi sát thương đến sau 0,3 giây. Ô 2–8 để dành skill class đã học ở các mốc sau.
- **Space hai lần trong 0,28 giây**, **B** trên tay cầm hoặc **DODGE**: né theo hướng di chuyển/hướng nhìn, tối đa 8 studs trong 0,22 giây; cooldown 4 giây. Space lần đầu vẫn nhảy. Vật cản hoặc thiếu mặt đất có thể kết thúc né sớm; chưa có thanh thể lực.
- **E**, nút **X** trên tay cầm hoặc prompt cảm ứng: nhận nhiệm vụ, lấy tinh thể, nhận thưởng.
- **C**, **Y** trên tay cầm hoặc nút **Companions**: mở bộ sưu tập và đổi thú.
- **MOVE!**: rời vòng tại vị trí được đánh dấu. **RETREAT!**: rút ra ngoài vòng quanh boss. Không có hồi máu thụ động; nhận hunt thành công, hoàn thành hoặc hồi sinh sẽ hồi đầy máu. Chết giữ bước nhiệm vụ trong phiên.
- HUD ghi thời gian cả chuyến, số lần ngã, lượt gần nhất và thời gian tốt nhất trong phiên. Không có thưởng thêm vì chạy nhanh.

Vùng hiện tại có nền liên tục 220×260, đường rừng, thác, phế tích và bến xe ngựa trang trí chưa chở người. Vẫn ba quái nhiệm vụ; thêm cụm quái và loại mới là mốc tiếp. Animation quái và nhân vật tạo bằng chuyển động thủ tục, chưa phải bộ animation hoàn thiện hoặc đã được kiểm chứng trong Studio. Giao diện dùng tiếng Anh; model/hình khối gốc lấy cảm hứng từ ảnh tham khảo. Chưa có âm nhạc hoặc asset của bên khác.

## Phát triển trong môi trường đám mây

```bash
cd /workspace/zzzz
python3 scripts/bootstrap.py
bash scripts/check.sh
```

Installer dành cho Linux x86_64: Rojo 7.7.1, Lune 0.11.0 và Luau 0.742. Binary tải từ release chính thức; checksum SHA-256 đã đối chiếu với metadata release GitHub. Tools và build được giữ trong thư mục bỏ qua Git, source không cần package manager. Dùng checkout đang có; mỗi task cloud đã được cách ly, không cần tạo worktree mới.

`check.sh` biên dịch cú pháp Luau, phân tích kiểu các module luật, chạy kiểm tra headless, mô hình cân bằng và đóng gói place bằng Rojo. Những bước này không thay thế engine Roblox, kiểm tra cảm giác điều khiển hoặc đo FPS trên điện thoại. Cloud hiện không có Roblox Studio.

Nhịp mục tiêu của vòng alpha cũ là 90–180 giây lượt đầu, 60–120 giây khi thuộc đường; cần đo lại sau khi đổi AI. Báo cáo giờ chỉ tính cận dưới sát thương và khoảng thoát, không dự báo thời gian hoàn thành hoặc khả năng sống. Chi tiết ở [docs/balance.md](docs/balance.md); chạy bằng `.tools/lune run scripts/balance_report.luau`.

Trên máy riêng có thể cài Rojo cùng phiên bản, chạy `rojo serve default.project.json` và kết nối plugin Rojo trong Studio để đồng bộ mã. Với bản `.rbxlx`, không cần plugin. Chỉ publish experience khi đã kiểm tra và chủ tài khoản Roblox quyết định phát hành.

## Kiểm tra trong Studio

Theo [docs/studio-checklist.md](docs/studio-checklist.md), ghi lỗi cùng dòng Output vào lần làm tiếp. [docs/design.md](docs/design.md) giữ đầy đủ yêu cầu RPG; [docs/progress.md](docs/progress.md) ghi trạng thái; [docs/roadmap.md](docs/roadmap.md) chia các đợt nhỏ. Quyết định cửa hàng và nguồn Roblox ở [docs/monetization.md](docs/monetization.md).

## Cấu trúc mã

| Tệp | Vai trò |
| --- | --- |
| `src/shared/Expedition.luau` | Nhiệm vụ, thưởng, mở và trang bị thú; quy tắc thuần Luau |
| `src/shared/CombatRules.luau` | Thông số quái và điều kiện chiến đấu |
| `src/shared/HuntMetrics.luau` | Đo thời gian và số lần ngã bằng clock server, không thay đổi phần thưởng |
| `src/shared/DodgeRules.luau` | Khoảng né, hồi chiêu và kiểm tra hướng |
| `src/server/init.server.luau` | Trạng thái phiên, prompt, kiểm tra remote và ghép hệ thống |
| `src/server/CombatService.luau` | Tuần tra/đuổi/trở về, đánh thường/skill, sát thương/thú và đóng góp phía server |
| `src/server/DodgeService.luau` | Di chuyển né, raycast, miễn sát thương ngắn và quyền sở hữu mạng |
| `src/server/WorldBuilder.luau` | Vùng rừng, làng, thác, phế tích, trạm xe và mốc tương tác |
| `src/client/Hud.luau` | Nhiệm vụ, máu, điều khiển và bộ sưu tập |
| `src/client/CompanionView.luau` | Hình dáng và chuyển động bạn đồng hành ở client |
| `src/client/EnemyView.luau` | Animation quái từ trạng thái/thời gian server; giữ hitbox gốc |
| `src/client/PlayerCombatView.luau` | Vung tay/né R6/R15 và VFX, không tự di chuyển nhân vật |
| `src/character/Health.server.luau` | Ghi đè script Health mặc định để tắt hồi máu thụ động |

Client không gửi giá, phần thưởng, tọa độ đòn hoặc khai đã giết quái. Server quyết định kết quả. Vật phẩm trả tiền không được triển khai cho đến khi có lưu dữ liệu và xử lý giao dịch đáng tin cậy.
