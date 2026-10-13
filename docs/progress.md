# Tiến độ Wildbond

Cập nhật 13/10/2026 — **0.4.0**. RPG PvE, boss và sưu tầm thú cho EU 12–16. Yêu cầu đầy đủ ở [design.md](design.md), thứ tự làm ở [roadmap.md](roadmap.md).

## Bản hiện tại

- **Animation:** sau hai lần sửa, người dùng vẫn thấy tay đứng yên. Scanner trước chỉ nhận Motor6D, còn Roblox R15 mới có AnimationConstraint. Bản này hỗ trợ cả hai; đọc Attachment0/1, giữ nguyên rest attachments/C0/C1. Gỡ lớp pose trước Animator ở PreAnimation, đặt lại sau Animator ở PreSimulation. Đấm luân phiên tay, R15 có khuỷu/cổ tay; lướt đổi thân, tay, chân, đầu gối và mắt cá. Joint đến muộn được tìm lại trong đòn. Diagnostics trên Character: WildbondCombatRig/JointCount/Ready. Đây là nguyên nhân khả dĩ từ mã và tài liệu; **chưa xác nhận rig của người dùng hay hình ảnh đã đúng trong Studio**.
- **Điều khiển:** Shift trái/phải một lần để lướt, Space chỉ nhảy; B/DODGE tương đương, ShiftLock tắt. Click/R2/STRIKE đánh thường; 1/L2/BOND yêu cầu skill thú sẵn sàng, ô 2–8 Unlearned; E/X prompt, C/Y bộ sưu tập. Lướt tối đa 16 studs/0,3 giây, CD 4, miễn damage tối đa 0,18; server kiểm tra đoạn ≤2 studs, chặn tường/hố và giữ jump Y.
- **Pet:** actor server trong Workspace.WildbondCompanions; HP 60, giáp 1, tốc độ 22. Basic 4 damage/1,2 giây, windup 0,3, range 5,5; skill 12/6 giây, windup 0,35, range 18. Khi chủ giao tranh, pet tiếp cận, tự đánh và dùng skill. Lệnh thủ công dùng chung cooldown. Enemy basic và AoE có thể đánh pet.
- **Pet chết:** hủy đòn, động tác bị hạ rồi ẩn. Chủ còn sống và rời combat liên tục 10 giây mới hồi; giao tranh lại hoặc thiếu nhân vật sống hủy timer. Equip A→B→A và nhân vật chết/respawn không xóa HP/cooldown hay hồi pet ngay. Hồi đúng điều kiện với HP đầy; pet còn sống chưa hồi HP thụ động. Ba loài cùng sức mạnh, chưa có vai trò/nội tại/tiến hóa.
- **Hình ảnh pet:** mọi client theo actor/root và trạng thái server, có gait, cắn/pounce, hiệu ứng skill, billboard HP và death/respawn. HUD hiện HP/ATK/skill/DEF, trạng thái và countdown. Không hồi sinh theo thời gian client; xử lý folder/root/attribute đến muộn.
- **Map:** nền 550×624 = 343.200 stud², đúng 6× diện tích 220×260 cũ. Giữ tuyến hunt gần làng, thêm 45 đoạn đường, vòng ngoài/đường tắt, nhà thợ rừng, đầm lau, tháp đổ, đồng cỏ/cối xay. Có 25 quái: 3 bounty + 22 ambient, bốn loại Sprout/Reed/Ancient/Boar. Cây/đá tránh toàn footprint leash 28. Giới hạn 140 cây, 65 đá, 30 cụm hoa; mẫu headless 1.143 BaseParts, cap 1.300 không gồm quái/pet/UI. Xe chưa chuyển vùng.
- **Bước RPG tiếp đã bắt đầu:** coins/EXP/level 1–40 trong phiên. Kill thưởng người góp damage còn sống, đúng character và cách điểm hạ ≤40; pet tính cho chủ. Callback một lần trước cập nhật defeated của bounty; Return/reset không thưởng. Boar 4 coins/8 XP, Sprout 5/10, Reed 6/12, boss 25/45. LV1 cần 60 XP, công thức 60+20×(lv−1)+5×(lv−1)²; giữ XP dư, cap 40. Coins khác shells, chưa có shop. Level chưa tăng stats/mở class. Snapshot không alias profile; client không gửi reward.
- Build, Output và HUD mang dấu **0.4.0**. File Wildbond.rbxlx gốc đóng gói cùng mã để tải từ GitHub.

## Nền vẫn giữ

Quái patrol home 12 ở tốc độ 3,5; chase 7 trong leash 28. Basic khóa hướng, windup 0,65, front arc/range 5, recover 0,28. Boss 600 HP đánh thường 12 và skill 22, không chồng động tác; hai bounty 140/200 HP. Mất mục tiêu 10 giây thì Return/reset; chết hồi sau 6 giây. Máu tăng 65% nền cho mỗi người mới góp damage, tối đa bốn người; pet không tính thêm một người.

Click 10/0,6 giây trong 8 studs; hụt vẫn animation. Hunt ba mục tiêu → tinh thể → rương 60 shells; cáo 120, gấu 240 shells. Không hồi HP nhân vật thụ động; accepted hunt/claim/respawn heal. Đồng hồ hunt gồm đi lại/chết; last/best/falls giữ trong phiên, không thưởng tốc độ.

## Kiểm chứng và giới hạn

`bash scripts/check.sh` đạt compile, strict analysis sáu shared modules, 15 test files, báo cáo cân bằng và build Rojo. Checks: CombatService 603, CombatRules 286, Companion 82, DodgeRules 15, DodgeService 840, EnemyView 111, equip revision 8, Expedition 258, HUD 52, HuntMetrics 24, PetService 54, PlayerCombat 50, Progression 527, server wiring 53, World 50.876. Wiring được chạy lại sau bổ sung test kill/profile; không đổi source sau build.

Tests chạy module thật với Roblox reflection; clocks/signals/Animator scheduling/raycasts/physics/network được mô phỏng có ghi rõ. FK chứng minh phương trình tay đi về trước, không chứng minh engine đã render. PRNG test riêng vì Lune chưa có Random; cảnh engine không nhất thiết trùng mẫu.

Tài liệu đã đối chiếu: [AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint), [Motor6D](https://create.roblox.com/docs/reference/engine/classes/Motor6D), [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService). AvatarJointUpgrade không phải setting được script/Rojo tùy ý tắt; hỗ trợ khớp mới thay vì dùng setting không hợp lệ.

**Cloud không có Roblox Studio.** Rendering nhân vật/pet, constraint simulation, hit timing, steering, physics, mạng nhiều client và FPS mobile cần thử theo [checklist](studio-checklist.md). Build/headless đạt không xác nhận đã hết lỗi animation người dùng báo.

## Còn thiếu và đợt tiếp

**Dữ liệu mất khi rời server.** Code tiếp theo: hồ sơ bền vững, khóa phiên/migration/xử lý lỗi; định nghĩa class và trang bị; chọn Fighter/Hunter/Arcanist ở level 1, rồi loot/NPC starter shop. Mọi ô trang bị/ba nhẫn/quy tắc một–hai tay, skill 1–8/mana/nộ, nhánh 10–20–30–40, craft, pet role/tiến hóa/nội tại, map khó/xe/cổng vẫn giữ trong design.

Chưa có Product/Pass IDs, receipt, paid random hoặc publish experience. Art/audio/animation còn thử nghiệm. Báo cáo cân bằng chỉ capacity bound, không suy thời gian hunt/khả năng sống/giữ chân/Robux. Mục tiêu hunt đầu 90–180 giây vẫn cần đo; map lớn không bắt người mới chạy hết vùng.

Lịch sử: nền hunt/tools → roaming/double Space/đất liền → lướt 16/C0/chín quái → 0.4 đổi Shift, khớp mới, pet và mở map. Mỗi đợt đọc docs/lỗi mới, giữ checkout sẵn có, làm mốc nhỏ, build/copy place/commit/push an toàn rồi verify SHA. Người dùng cần commit trên main, không chỉ thay đổi workspace. Không hứa quản lý quota 5 giờ.
