# Wildbond

Một trò chơi Roblox PvE trên quần đảo, nơi người chơi đánh boss và sưu tầm bạn đồng hành. Bản hiện tại đã có **đòn của thú và đợt cân bằng đầu tiên**, vẫn là alpha cần thử trong engine trước khi phát hành.

Bạn xuất hiện ở làng Greywater, nhận chuyến săn tại bảng nhiệm vụ, đánh hai hộ vệ và mini-boss Hollow Crown. Né vòng báo đòn, gọi thú đánh rồi rút khỏi đòn lan quanh boss. Lấy ba tinh thể ở các trụ gần trận đánh, quay về rương làng nhận 60 shells. Chuyến săn có thể nhận lại. Sói đi cùng từ đầu; cáo và gấu con mở bằng shells kiếm trong game.

Ba thú đều có đòn BOND, cùng sức mạnh ở bản này; vai trò riêng chưa triển khai. Tiến độ giữ trong phiên và mất khi rời server. Không có cửa hàng Robux, gacha trả tiền hoặc lưu DataStore trong bản này.

## Mở bản chơi

Trên GitHub, tải [Wildbond.rbxlx](Wildbond.rbxlx) ở thư mục gốc của kho bằng nút **Download raw file**. Đây là bản đóng gói cùng mã nguồn trong commit này; khi sửa mã, dùng lệnh build bên dưới để tạo bản mới.

Tệp đã build: `build/Wildbond.rbxlx`. Tải tệp về máy Windows hoặc macOS có **Roblox Studio**, dùng **File → Open from File**, rồi nhấn **Play**. Map được sinh khi server bắt đầu chạy nên chưa xuất hiện trong chế độ chỉnh sửa trước khi Play. Không cần API key hay asset riêng cho mốc này.

- Di chuyển bằng điều khiển Roblox thông thường.
- **F**, click chuột, **R2** hoặc nút **STRIKE**: đánh quái gần nhất trong phạm vi.
- **Q**, **L2** hoặc nút **BOND**: gọi thú đánh quái gần nhất trong phạm vi 18 studs. Hồi chiêu 3,2 giây; server kiểm tra lại trước khi sát thương đến sau 0,3 giây.
- **E**, nút **X** trên tay cầm hoặc prompt cảm ứng: nhận nhiệm vụ, lấy tinh thể, nhận thưởng.
- **C**, **Y** trên tay cầm hoặc nút **Companions**: mở bộ sưu tập và đổi thú.
- **MOVE!**: rời vòng tại vị trí được đánh dấu. **RETREAT!**: rút ra ngoài vòng quanh boss. Không có hồi máu thụ động; nhận hunt thành công, hoàn thành hoặc hồi sinh sẽ hồi đầy máu. Chết giữ bước nhiệm vụ trong phiên.
- HUD ghi thời gian cả chuyến, số lần ngã, lượt gần nhất và thời gian tốt nhất trong phiên. Không có thưởng thêm vì chạy nhanh.

Giao diện bản đầu dùng tiếng Anh cho người chơi EU. Tên, thông số và kiểu đồ họa là hướng thử nghiệm; model tạo bằng hình khối riêng, lấy cảm hứng từ ảnh tham khảo. Chưa có âm nhạc hoặc asset của bên khác.

## Phát triển trong môi trường đám mây

```bash
cd /workspace/zzzz
python3 scripts/bootstrap.py
bash scripts/check.sh
```

Installer dành cho Linux x86_64: Rojo 7.7.1, Lune 0.11.0 và Luau 0.742. Binary tải từ release chính thức; checksum SHA-256 đã đối chiếu với metadata release GitHub. Tools và build được giữ trong thư mục bỏ qua Git, source không cần package manager. Dùng checkout đang có; mỗi task cloud đã được cách ly, không cần tạo worktree mới.

`check.sh` biên dịch cú pháp Luau, phân tích kiểu các module luật, chạy kiểm tra headless, mô hình cân bằng và đóng gói place bằng Rojo. Những bước này không thay thế engine Roblox, kiểm tra cảm giác điều khiển hoặc đo FPS trên điện thoại. Cloud hiện không có Roblox Studio.

Nhịp mục tiêu: 90–180 giây lượt đầu, 60–120 giây khi thuộc đường. Đây là mục tiêu để chơi thử, chưa phải số đo người dùng. Chi tiết giả định và kết quả ở [docs/balance.md](docs/balance.md); chạy riêng mô hình bằng `.tools/lune run scripts/balance_report.luau`.

Trên máy riêng có thể cài Rojo cùng phiên bản, chạy `rojo serve default.project.json` và kết nối plugin Rojo trong Studio để đồng bộ mã. Với bản `.rbxlx`, không cần plugin. Chỉ publish experience khi đã kiểm tra và chủ tài khoản Roblox quyết định phát hành.

## Kiểm tra trong Studio

Theo [docs/studio-checklist.md](docs/studio-checklist.md), ghi lỗi cùng dòng Output vào lần làm tiếp. [docs/progress.md](docs/progress.md) giữ trạng thái dự án để tiếp tục ở phiên khác; [docs/roadmap.md](docs/roadmap.md) chia các mốc nhỏ. Quyết định cửa hàng và nguồn Roblox ở [docs/monetization.md](docs/monetization.md).

## Cấu trúc mã

| Tệp | Vai trò |
| --- | --- |
| `src/shared/Expedition.luau` | Nhiệm vụ, thưởng, mở và trang bị thú; quy tắc thuần Luau |
| `src/shared/CombatRules.luau` | Thông số quái và điều kiện chiến đấu |
| `src/shared/HuntMetrics.luau` | Đo thời gian và số lần ngã bằng clock server, không thay đổi phần thưởng |
| `src/server/init.server.luau` | Trạng thái phiên, prompt, kiểm tra remote và ghép hệ thống |
| `src/server/CombatService.luau` | Đòn thường/thú, đóng góp và tăng máu theo nhóm, hai đòn boss, reset/hồi quái phía server |
| `src/server/WorldBuilder.luau` | Đảo, làng, thác, phế tích và mốc tương tác |
| `src/client/Hud.luau` | Nhiệm vụ, máu, điều khiển và bộ sưu tập |
| `src/client/CompanionView.luau` | Hình dáng và chuyển động bạn đồng hành ở client |
| `src/character/Health.server.luau` | Ghi đè script Health mặc định để tắt hồi máu thụ động |

Client không gửi giá, phần thưởng, tọa độ đòn hoặc khai đã giết quái. Server quyết định kết quả. Vật phẩm trả tiền không được triển khai cho đến khi có lưu dữ liệu và xử lý giao dịch đáng tin cậy.
