# Wildbond

Roblox RPG PvE trên vùng rừng **Greywater Reach**: quái đi lại, đánh thường, boss và thú tham chiến. Bản **0.4.0** mở rộng map, bổ sung combat của pet và nền EXP/tiền. Đây vẫn là alpha cần thử trong Roblox Studio.

Bạn xuất hiện ở làng Greywater, nhận chuyến săn, hạ hai hộ vệ và Hollow Crown, lấy ba tinh thể rồi về rương nhận 60 shells. Có thể nhận lại hunt. Ngoài đường săn đầu còn có rừng, đồng cỏ, đầm lau và phế tích để khám phá, với 25 quái thuộc bốn loại. Quái thường đánh được ngay khi chưa nhận hunt.

Pet có máu/chỉ số riêng, tự tiếp cận, đánh thường và dùng skill khi chủ giao tranh. Quái có thể đánh pet. Pet bị hạ chỉ hồi sinh sau khi chủ rời combat liên tục 10 giây; giao tranh lại hủy đếm ngược. Sói có từ đầu, cáo/gấu con mở bằng shells; cả ba cùng sức mạnh ở mốc này.

Quái thưởng **coins và EXP** cho người góp sát thương hợp lệ, gồm damage từ pet; nền cấp độ 1–40 và HUD EXP đã có. Coins khác shells dùng mở pet. Cấp độ chưa tăng chỉ số hoặc mở class; chưa có đồ rơi, túi đồ, NPC bán đồ, tiến hóa/nội tại thú hay skill tree. **Mọi tiến độ chỉ giữ trong phiên**, mất khi rời server; chưa có DataStore hay bán hàng Robux.

## Mở bản chơi

Trên GitHub tải [Wildbond.rbxlx](Wildbond.rbxlx) bằng **Download raw file**. Mở trong Roblox Studio trên Windows/macOS bằng **File → Open from File**, nhấn **Play**. Map được sinh khi server bắt đầu chạy nên chưa hiện trước Play. Output/HUD có dấu bản **0.4.0** để phân biệt bản cũ.

- **Click**, **R2**, **STRIKE**: đánh thường, 10 damage/0,6 giây trong 8 studs. Click hụt vẫn diễn đòn.
- **Shift trái/phải**, **B**, **DODGE**: lướt tối đa 16 studs/0,3 giây, hồi 4 giây. Space chỉ nhảy. Server kiểm tra tường/mặt đất trên từng đoạn và giữ vận tốc nhảy.
- Pet **tự đánh và tự dùng skill**; **1**, **L2**, **BOND** yêu cầu dùng skill sớm nếu sẵn sàng, dùng chung cooldown 6 giây. Ô 2–8 chưa học, để dành skill class.
- **E**, **X** hoặc prompt cảm ứng: nhận hunt, lấy tinh thể, nhận thưởng.
- **C**, **Y**, **Companions**: bộ sưu tập/đổi thú. HUD hiển thị máu, chỉ số và trạng thái hồi sinh pet.
- **MOVE!**: rời vòng đã đánh dấu; **RETREAT!**: rút khỏi vòng quanh boss. Di chuyển khỏi cung đánh thường cũng tránh được đòn, không cần chờ lướt cho mọi đòn.
- Không hồi máu nhân vật thụ động. Nhận hunt thành công, nhận thưởng hoặc hồi sinh sẽ hồi đầy máu nhân vật; không thay quy tắc hồi sinh pet. Đồng hồ hunt ghi tổng thời gian và số lần ngã, không thưởng thêm vì chạy nhanh.

Nền đất liền mới **550×624**, đúng **6 lần diện tích** nền 220×260 cũ. Đường săn ba mục tiêu vẫn gần làng, không bắt người mới chạy hết map. Bến xe ngựa đang trang trí, chưa chuyển vùng. Geometry gốc theo hướng rừng low poly, chưa có bộ art/audio cuối cùng.

Đợt sửa animation hỗ trợ cả `Motor6D` và khớp R15 mới `AnimationConstraint`, đặt pose sau Animator ở PreSimulation và gỡ lớp trước lượt Animator tiếp theo. Có chuyển động vai/khuỷu/cổ tay khi đấm, thân/chân khi lướt và hiệu ứng trúng. Đây là sửa từ mã và tài liệu Roblox; **chưa xác minh hình ảnh native trong Studio**. Nếu còn lỗi, kiểm tra thuộc tính nhân vật `WildbondCombatRig`/`WildbondCombatJointCount` và Output theo checklist.

## Phát triển trong cloud

```bash
cd /workspace/zzzz
python3 scripts/bootstrap.py
bash scripts/check.sh
```

Installer Linux x86_64 giữ Rojo 7.7.1, Lune 0.11.0, Luau 0.742, kiểm SHA-256 từ release chính thức. Tools/build bỏ qua Git; dùng checkout sẵn có vì mỗi task cloud đã cách ly.

`check.sh` biên dịch Luau, phân tích kiểu các luật, chạy test module thực với reflection/mocks, báo cáo cân bằng và build `build/Wildbond.rbxlx`. Sau sửa mã, copy build mới sang `Wildbond.rbxlx` gốc trước commit để người dùng GitHub tải được bản tương ứng. Cloud Linux không có Roblox Studio: những bước này không xác minh rendering, physics, network hoặc FPS mobile.

Trên máy riêng có thể chạy `rojo serve default.project.json` cùng plugin Rojo trong Studio; mở file place thì không cần plugin. Xem [checklist Studio](docs/studio-checklist.md), [cân bằng](docs/balance.md), [tiến độ](docs/progress.md), [yêu cầu đầy đủ](docs/design.md) và [roadmap](docs/roadmap.md). Bán hàng theo [monetization.md](docs/monetization.md), chưa triển khai.

## Cấu trúc

| Tệp | Vai trò |
| --- | --- |
| `shared/Expedition` | Hunt, shells, bộ sưu tập và equip revision |
| `shared/CombatRules`, `shared/DodgeRules` | Quái, phạm vi, đóng góp và lướt |
| `shared/PetRules`, `server/PetService` | Chỉ số pet, tự chiến đấu, máu, chết/hồi sinh |
| `shared/Progression` | EXP/coins/cấp độ trong phiên, chỉ server trao thưởng |
| `shared/HuntMetrics` | Thời gian hunt và số lần ngã |
| `server/init.server`, `server/CombatService` | Remote, AI, damage và reward authority |
| `server/DodgeService`, `server/WorldBuilder` | Lướt an toàn và tạo vùng đất |
| `client/Hud`, `client/CompanionView` | UI và pet từ actor server |
| `client/EnemyView`, `client/PlayerCombatView` | Animation/VFX, giữ authority server |
| `character/Health.server` | Tắt hồi máu nhân vật mặc định |

Client không gửi giá, số thưởng, damage hoặc tuyên bố đã hạ quái. Server quyết định kết quả. Các phần class/trang bị/craft/chuyển vùng được giữ trong design để làm tiếp qua những đợt nhỏ.
