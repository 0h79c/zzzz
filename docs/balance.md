# Cân bằng Wildbond 0.4.0

Quái di chuyển, pet có thể chết và map vừa lớn gấp sáu lần diện tích. Mô hình đứng yên cũ về hunt 60–80 giây/boss 35,5 giây/máu còn 56–6 đã hết hiệu lực. **Chưa có thời gian trận hay tỷ lệ sống đo trong Studio.**

| Phần | Chỉ số |
| --- | --- |
| Nhân vật | 100 HP, đi 20 studs/giây |
| Click | 10 damage/0,6 giây, range 8 |
| Shift/B/DODGE | Tối đa 16 studs/0,3 giây, CD 4, miễn damage tối đa 0,18 giây |
| Pet | 60 HP, giáp 1, đi 22; ba loài cùng sức mạnh |
| Pet basic | 4/1,2 giây, windup 0,3, range 5,5 |
| Pet skill tự động/thủ công | 12/6 giây, windup 0,35, range 18; chung cooldown |
| Pet hồi sinh | Sau chủ sống và ngoài combat liên tục 10 giây; reengage hủy timer |
| Enemy basic | Windup 0,65, cung phía trước/range 5, recover 0,28; CD 1,2 hoặc boss 1,5 |
| Ba bounty | HP 140/200/600; basic 8/10/12 |
| Boss skill | 22/windup 1,2; vòng mục tiêu 7 hoặc centered 10 |
| Di chuyển quái | Patrol 3,5/home 12; chase 7/leash 28 |
| Party | HP nền×[1+0,65×(contributors−1)], tối đa bốn người; pet tính cho chủ |

Boss skill sẵn sàng sau 2,8 giây engage, rồi 5 giây sau resolve; chờ basic/recover nếu cần. Không cộng hai đòn đồng thời. HP quái tăng khi người mới gây damage, giữ damage trước đó; người đứng xem không tăng độ khó. Mất mục tiêu 10 giây Return/reset; bị hạ hồi 6 giây. Ba bounty cần hunt; 22 ambient không cần quest.

Nhân vật không hồi HP thụ động; accepted hunt/claim/respawn heal. Pet còn sống chưa hồi HP; equip/respawn nhân vật không chữa pet. Giáp 1 giảm một điểm mỗi đòn, tối thiểu nhận 1. Với 60 HP, pet chịu được năm basic boss 11 damage rồi chết ở đòn sáu, hoặc hai AoE 21 rồi chết ở đòn ba. Đây là ngân sách lỗi riêng, không dự đoán pet sống bao lâu hay đã là tank hoàn thiện.

## Cận dưới sát thương

Chạy `.tools/lune run scripts/balance_report.luau`. Script đọc các module luật, không giữ bộ stats quái thứ hai. Capacity danh nghĩa: player 16,67 + pet basic 3,33 + skill 2,00 = 22,00 damage/giây.

Bảng đặt clocks basic/skill pet độc lập, mọi đòn trúng, mọi người bắt đầu cùng t0, không di chuyển/LOS delay và pet không chết. Service thực tế nối tiếp windup, phải đi lại và có thể mất pet. **Cận dưới có thể không đạt được**, không phải mô phỏng trận hay dự báo boss 26,7 giây.

| Bounty | Chỉ click | Click+pet, capacity bound |
| --- | --- | --- |
| Bramble Sprout 140 HP | 7,8s | 6,0s |
| Reed Guardian 200 HP | 11,4s | 8,4s |
| Hollow Crown 600 HP | 35,4s | 26,7s |

Boss với 2/3/4 contributors: 990/1380/1770 HP, capacity bounds 22,2/20,4/19,5s. Không suy khả năng sống từ bảng. Basic contact pressure danh nghĩa 6,67/8,33/8 HP/giây nếu đứng yên nhận mọi đòn; không cộng DPS skill như thể hai động tác chồng.

## Né và độ khó

Từ tâm ra ngoài range 5 ở tốc độ 20 cần hơn 0,25s, để dưới 0,40s trong windup 0,65 trước mạng/vật cản. Lùi/đi ngang khỏi cung đánh phải hữu dụng giữa các lần Shift CD 4. Shift thay double Space, Space chỉ nhảy; request latency vẫn xảy ra trước server chấp nhận. Miễn damage 0,18 ngắn hơn chuyển động 0,3; tường/hố dừng sớm cũng kết thúc miễn sát thương.

Vòng mục tiêu 7 cần hơn 0,35s từ tâm, để dưới 0,85s của windup 1,2. Centered 10 từ mép click 8 cần hơn 0,10s, để dưới 1,10s; đứng sát boss phải đi xa hơn. Chưa gồm body radius, camera, vật chắn hoặc server frame.

Player đi 20, enemy chase 7, click reach 8 so với enemy 5: giữ khoảng cách trên đất trống có thể làm basic quá dễ. Sau thử thực hãy xem hành vi/tốc độ/đòn lao có báo/vị trí, không tăng HP để che AI. Animation phải cho thấy windup trước khi chỉnh damage.

## Map và nhịp nhiệm vụ

550×624 = 343.200 stud², đúng 6×57.200 cũ. Tuyến ba bounty giữ gần làng; rừng/đầm/đồng cỏ để khám phá và farm tự chọn. Không nhân thời lượng hunt với diện tích map. 45 đoạn đường/25 spawns chưa chứng minh mật độ, chỉ dẫn và FPS tốt.

Mục tiêu thử 90–180 giây lượt đầu, 60–120 khi quen vẫn là giả thuyết. Ghi riêng đi đến trận/đánh/nhặt/về trại, cả thất bại và pet chết; không lấy lượt nhanh nhất. Nếu lâu vì lạc/chờ respawn, sửa tuyến/dấu/mật độ, không coi đó là nội dung giữ chân. Timer hồi pet chỉ chạy ngoài trận.

## Reward và EXP trong phiên

| Loại | Coins | EXP |
| --- | --- | --- |
| Boar | 4 | 8 |
| Sprout | 5 | 10 |
| Reed | 6 | 12 |
| Hollow Crown | 25 | 45 |

Reward một lần cho contributor sống, đúng character và cách điểm hạ ≤40; pet tính cho chủ, last hit không độc quyền. Callback XP trước defeated bounty; Return/reset không thưởng. Coins khác 60 shells/hunt; cáo 120/gấu 240 shells: hai hunts mở cáo, tổng sáu mở cả hai.

LV1 cần 60 XP lên 2; công thức 60+20×(lv−1)+5×(lv−1)². Các mốc 2→3=85, 9→10=540, 19→20=2040, 29→30=4540, 39→40=8040. XP dư giữ, cap 40; level chưa tăng stats/mở class. Đây là curve thử để nối hồ sơ, chưa phải grind 40 level đã cân bằng. Không đổi XP thành phút khi chưa đo.

Bước sau: lưu hồ sơ/class/equipment rồi loot/shop. Đồ cơ bản phải chơi được vùng đầu; đồ hiếm là thưởng thêm. Craft/ba nhẫn/một–hai tay/skill resource cần ngân sách riêng. Pet tiến hóa/nội tại/taunt/stun/heal chưa có. Không đưa damage giả từ tính năng tương lai hoặc kết luận giữ chân/Robux. Dữ liệu mất khi rời server; chưa bán hàng.
