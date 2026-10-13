# Wildbond — mỗi đợt một phần có thể thử

RPG PvE trên đất liền, quái biết đi/đánh, class/trang bị và pet tham chiến. Yêu cầu đầy đủ ở [design.md](design.md), triển khai thực ở [progress.md](progress.md). Người dùng ưu tiên chất lượng qua nhiều đợt vì quota khoảng 5 giờ; mỗi lượt có mốc rõ, test/build/file place trên GitHub và ghi phần tiếp. Không hứa quản lý lịch reset.

## Trạng thái 0.4.0

AI roaming đã có. Animation hỗ trợ Motor6D/AnimationConstraint và Shift nhưng còn chờ thử hình ảnh trong Studio. Map 550×624/25 quái. Pet HP/stats/auto basic/auto skill/death/10s ngoài combat đã triển khai. Coins/EXP/level bắt đầu trong phiên. **Chưa có lưu dữ liệu lâu dài, class, trang bị, loot hoặc shop**; chưa hoàn thành mốc dữ liệu/pet role.

## Thứ tự tiếp tục

| Mốc | Làm gì | Điều kiện |
| --- | --- | --- |
| 1. Kiểm chứng bản mới | R6/R15/upgraded, Shift/Space, pet đánh/chết/hồi, routes trong Studio; sửa lỗi cụ thể | Động tác rõ/khớp hit, không giật/xuyên vật chắn; đo mobile và 2–4 client |
| 2. Hồ sơ bền vững — code tiếp | Coins/EXP/level/hunt/class/túi/trang bị/pet; schema, migration, khóa phiên | Lỗi tải không ghi đè trắng; reconnect/hai server/retry không mất hoặc nhân đôi |
| 3. Class/định nghĩa đồ | Fighter/Hunter/Arcanist từ level 1; mọi ô kể cả ba nhẫn; họ vũ khí/offhand | Server kiểm ID/ownership/ô/class/level/một–hai tay; chọn/đổi nghề hợp lý |
| 4. Loot/starter shop | Đồ cơ bản ở làng, ít đồ hiếm từ quái; UI bag/equip | Reward một lần, đồ hiếm không bắt buộc, không dupe qua equip/reconnect |
| 5. Skill nhỏ từng class | Đòn vũ khí, vài skill đầu học rồi gán 1–8; mana/nộ | Lối chơi khác nhau, resource/CD server, mobile/gamepad, ô trống rõ |
| 6. Pet role/evolution | Một passive/skill khác biệt trên một pet trước; buff/stun/taunt/heal/tiến hóa | Giữ HP/10s revive; hỗ trợ có credit; vai trò tạo lựa chọn |
| 7. Nghề/vùng/craft | Nhánh 10/20/30/40; cổng/xe sang một vùng khó; nguyên liệu/craft roll | Từng nhánh/vùng, không mất/dupe nguyên liệu, vùng mới có cơ chế riêng |
| 8. Thử kín/art/audio/commerce | Asset gốc/animation có chủ ý, hiệu năng/coop; pass 200–400, xem riêng hộp 60–1200 | Hồ sơ/giao dịch đáng tin cậy; [monetization.md](monetization.md); paid random tắt đến đủ điều kiện |

Yêu cầu “sau đó làm công việc tiếp theo” đã bắt đầu bằng coins/EXP/session level sau animation/pet/map. Đợt sau không làm cả craft/cây nghề/tám skill khi hồ sơ chưa có. Các yêu cầu tương lai vẫn được giữ.

## Quy trình mỗi lượt

Đọc README/design/progress/roadmap và lỗi Studio mới, giữ thay đổi người dùng, dùng checkout sẵn có. Task cloud đã cách ly nên không tự tạo worktree. Chạy `bash scripts/check.sh`; Studio cần thiết để kết luận hình ảnh/cảm giác/physics/FPS tốt. Cloud thiếu Studio thì ghi headless đã đạt và native còn chờ, tiếp tục phần độc lập.

Cuối mốc cập nhật docs, build Rojo, copy `build/Wildbond.rbxlx` sang file gốc, commit/push an toàn main GitHub và verify SHA. Người dùng cần commit/file chơi, không chỉ thay đổi workspace. Giữ remote changes, không force push. Publish Roblox khi chủ dự án quyết định.

Nhịp hunt phải đo lại sau map/pet; không kéo dài bằng HP/chờ/đường trống. Mỗi phần giúp chọn đường/đồ/skill/thú/coop rõ hơn và thử trên một lát nội dung nhỏ.
