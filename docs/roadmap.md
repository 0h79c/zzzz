# Wildbond — mỗi đợt một phần chơi được

Hướng mới là RPG PvE trên một vùng đất liền: quái biết đi và đánh, nhân vật có class/trang bị, thú tham chiến và về sau tiến hóa. Yêu cầu đầy đủ được giữ ở [design.md](design.md). Tên Wildbond và tên class vẫn là tên làm việc.

Người dùng muốn phát triển chậm, chia theo từng đợt vì hạn mức token làm mới khoảng 5 giờ. Mỗi lượt ưu tiên một phần rõ ràng có thể kiểm tra, ghi trạng thái để tiếp tục khi có lượt làm sau. Không tự đặt lịch hoặc hứa quản lý giờ reset, không cố xây toàn bộ RPG trong một turn. Một mốc lớn dưới đây có thể cần nhiều đợt nhỏ.

## Những gì đã có trước khi đổi hướng

Hai bản đầu dựng đường săn ba trận, một mini-boss, ba ngoại hình thú, đòn thường và BOND, thưởng 60 shells, số đo thời gian/số lần ngã trong phiên. Server kiểm tra sát thương, cự ly, cooldown và đóng góp; máu scale theo người thực sự đánh. Có kiểm tra headless và build Rojo.

Đó là nền thử, **chưa phải RPG hoàn chỉnh**: map còn theo hình đảo, quái thiên về AoE đứng tại chỗ, chưa có class, EXP, túi/trang bị hay DataStore. Chưa có animation được kiểm chứng trong engine, role/evolution của thú hoặc cửa hàng Robux. Giữ thành quả server/công cụ, thay những phần người dùng phản hồi chưa hấp dẫn. Số liệu và checklist cũ lưu ở [progress.md](progress.md), [balance.md](balance.md) và [studio-checklist.md](studio-checklist.md).

## Thứ tự làm

| Mốc | Phần làm | Điều kiện đi tiếp |
| --- | --- | --- |
| 1. Combat có chuyển động — ưu tiên hiện tại | Quái roaming trong ranh giới, aggro/đuổi/trở về, đánh thường có animation, skill có báo đòn; click đánh, 1–8 là nền ô skill, double-Space né với cooldown ban đầu 4 giây | Một trận từ phát hiện đến hạ quái/reset chơi được; đòn khớp animation; không chạy xuyên ranh giới hoặc đứng im chỉ thả AoE; cooldown do server giữ; chạy checklist Studio rồi ghi cảm giác và lỗi |
| 2. Một vùng khởi đầu | Đổi bố cục thành đất liền; trại, đường rừng/suối/phế tích; 8–12 điểm quái thuộc 3–4 loại; bến xe ngựa/cổng ở trạng thái đóng | Có đường săn và đường về rõ, không mắc vật cản; đi lại không biến thành chờ; thấy khác bố cục đảo nhiệt đới; đo hình ảnh/FPS mobile và điều chỉnh mật độ quái |
| 3. Hồ sơ và nền RPG | Lưu tiền, EXP, level, class, túi đồ, đồ mặc và thú; chọn Fighter/Hunter/Arcanist ở level 1; định nghĩa ô và loại vũ khí | Thoát/vào giữ tiến độ; lỗi tải không ghi đè bằng hồ sơ trắng; kiểm thử khóa phiên, version/migration và phục hồi; trang bị server kiểm tra ID/ô/class/level/một-hai tay |
| 4. Loot và shop khởi đầu | Quái rơi tiền/EXP và ít trang bị; NPC bán đồ cơ bản; hoàn thiện UI túi/trang bị cho các ô đã chốt | Không giành last hit; reward một lần; không mất/nhân đôi khi chết hoặc reconnect; người mới chơi được bằng đồ cơ bản; đồ hiếm kiếm từ gameplay |
| 5. Ba class thật sự khác nhau | Mỗi class có đòn/vũ khí và vài skill đầu; học skill, gán 1–8, resource mana/nộ phù hợp; giữ ô trống rõ | Một bộ skill nhỏ cho mỗi class đủ trải nghiệm lối chơi riêng; mana/nộ/cooldown server xác thực; vũ khí không cấp skill bất hợp lệ; mobile và tay cầm dùng được |
| 6. Thú là đồng đội | Tự đánh thường; làm một nội tại và một skill/role trước; sau đó thêm tiến hóa và vai trò damage/buff/stun/taunt | Thú có animation/đường tiếp cận hợp lệ; không đánh khi chết/đổi thú; đóng góp hỗ trợ được xét đúng; vai trò thay cách chơi; toàn bộ chức năng cốt lõi kiếm được miễn phí |
| 7. Đường tiến triển dài hạn | Nghề nhánh level 10/20/30/40; một vùng khó hơn qua cổng/xe ngựa; nguyên liệu/craft roll chỉ số/độ hiếm; boss và mục tiêu endgame | Mở từng nhánh/vùng sau khi phần trước đủ tốt; chuyển nghề có quy tắc; craft không mất nguyên liệu/nhân đôi; vùng mới có cơ chế khác; có mục tiêu chọn chơi lại ngoài grind |
| 8. Thử kín rồi bán hàng | Chơi nhóm, hiệu năng, bản sắc đồ họa/âm thanh; mỹ phẩm mua trực tiếp và pass trong khoảng 200–400 Robux; xem xét riêng dải hộp 60–1200 | Có dữ liệu lưu bền vững và chơi thử thực; receipt/quyền sở hữu/giá vùng/policy được thử; áp điều kiện [monetization.md](monetization.md); paid random vẫn tắt cho tới khi đủ điều kiện riêng |

Map đứng trước hồ sơ vì cần một không gian hợp lý để thử chase, leash và nhịp nhiệm vụ. Nếu combat gặp lỗi dữ liệu hoặc loot cần làm sớm, có thể làm nền hồ sơ trước mở rộng map; vẫn chỉ trang trí một vùng, không bỏ qua lưu dữ liệu để làm shop. Các mốc class/trang bị cần định nghĩa chung rõ trước khi ghép skill và pet buff.

## Trạng thái sau phản hồi đấm/lướt

Đã có AI di chuyển và bản mở rộng chín spawn/bốn loại trong một vùng, cùng đòn đấm C0 và lướt 16 studs sau phản hồi bản ngắn. Sáu quái thường đánh được không cần nhận bounty nhưng chưa có loot/EXP; không đánh dấu mốc dữ liệu/economy là đã xong. Rendering và cảm giác đấm/lướt cần người dùng thử lại trong Studio. Bước code tiếp là hồ sơ + nền level/class/trang bị, sau đó mới drop/shop.

## Chia nhỏ để không bỏ sót

Mốc hiện tại chỉ chữa nền combat và điều khiển. Kiểm thử một quái di chuyển/đánh tốt rồi mới sao chép hành vi cho các loại còn lại. Không ghép vào đợt đó cả EXP, đồ rơi, craft, cây nghề và tám skill hoàn chỉnh. Những mục chưa làm vẫn là yêu cầu được giữ trong design, không tự biến thành tùy chọn bị bỏ.

Mỗi đợt bắt đầu bằng đọc README, progress, roadmap, thay đổi người dùng và lỗi Studio nếu có. Dùng checkout đang có; task cloud đã cách ly nên không tự tạo worktree. Cuối đợt lưu mã/build, cập nhật progress với phần đã làm, kiểm tra đã chạy, giới hạn và một bước tiếp theo; cập nhật bản đóng gói khi mã thay đổi. Mã cần xuất hiện trên GitHub theo quy trình dự án, tránh chỉ báo đường dẫn workspace rồi khiến người dùng không thấy bản mới.

Không thêm hệ thống chỉ vì RPG khác có. Khi thêm một phần, ghi quyết định người chơi nhận được và thử trên một lát nội dung trước. Model/animation cuối cùng, audio, độ khó và hiệu năng cần nhiều đợt riêng; ảnh tham khảo dẫn phong cách, không dẫn việc sao chép asset.

## Kiểm tra trước khi mở rộng

Các kiểm tra cú pháp, logic server và build trong `scripts/check.sh` là bắt buộc cho phần có thay đổi. Roblox Studio cũng bắt buộc để kết luận một mốc combat/map đã chơi tốt; cloud build thành công không xác nhận animation, vật lý hoặc mạng.

- Trong Play: quái đi/chạy/đánh/skill/hạ có chuyển động khớp hit; đuổi và quay về đúng phạm vi; không xuyên tường, mắc đường hoặc để player kéo cả map về spawn.
- Click, phím 1–8 và double-Space hoạt động; nhảy thường vẫn dùng được; spam/dodge khi chết không bỏ cooldown. Kiểm tra cảm ứng và tay cầm có nút tương đương.
- Thử một người, hai và bốn client: damage/aggro/reset/đóng góp đúng; người đứng xem không tăng độ khó; chết/hồi sinh/đổi thú không giữ đòn cũ.
- Đo lượt đầu và lượt quen sau khi sửa combat: thời gian tiếp cận, đánh, về trại, số lần ngã và đoạn phải chờ; không lấy mô hình tĩnh cũ làm bằng chứng cho AI mới.
- Với hồ sơ/loot: thử lỗi tải/lưu, reconnect, hai server cùng hồ sơ, reward lặp và đổi đồ một/hai tay. Không mở bán khi còn nguy cơ mất dữ liệu.

Ghi lỗi Output, cách tái hiện và thiết bị vào progress. Khi cloud không có Studio, ghi rõ phần headless đã đạt và phần engine còn chờ; tiếp tục phần độc lập hữu ích, không tuyên bố đã đo FPS hoặc cảm giác chơi. [studio-checklist.md](studio-checklist.md) cần cập nhật theo từng bản để phản ánh điều khiển mới.
