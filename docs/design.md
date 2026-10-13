# Wildbond — hướng RPG đã chốt

Định hướng cập nhật ngày 13/10/2026: PvE, boss và sưu tầm thú, dành cho người chơi EU khoảng 12–16 tuổi. Người chơi đi từ trại đến khu săn, học cách đánh và né, mang chiến lợi phẩm về, chọn trang bị và thú phù hợp rồi thử vùng khó hơn. Mục tiêu là các trận đánh đáng chơi lại, không kéo dài buổi chơi bằng quái nhiều máu hoặc nhiệm vụ bắt chờ.

Đây là bản ghi yêu cầu và quyết định thiết kế, **không phải danh sách tính năng đã triển khai**. Trạng thái mã, kiểm tra và giới hạn mỗi bản nằm trong [progress.md](progress.md). Mốc làm tiếp nằm trong [roadmap.md](roadmap.md).

## Chiến đấu phải có chuyển động

Quái đi lại quanh điểm sinh trong một phạm vi riêng, phát hiện người chơi, đuổi đến cự ly đánh và quay về khi vượt ranh giới săn. Đòn thường là phần chính của giao tranh; skill có vùng báo đòn bổ sung lựa chọn né, không thay toàn bộ hành vi bằng một mô hình đứng im thả AoE.

Phải có animation cho đi/chạy, đánh thường, chuẩn bị skill, bị hạ; animation của đòn phải khớp thời điểm server xét trúng. Bản đầu có thể dùng rig/animation thủ tục tự tạo để thử nhịp, sau đó thay bằng bộ animation có chủ ý. Không coi rung hoặc đổi màu cả model là đủ thay cho chuyển động tấn công. Quái nhỏ, quái giáp và boss cần silhouette, nhịp và cách tiếp cận khác nhau.

| Điều khiển | Hành vi | Phạm vi triển khai |
| --- | --- | --- |
| Click chuột | Đánh thường bằng vũ khí đang dùng | Làm trước; server kiểm tra mục tiêu, cự ly, đường nhìn và hồi đòn |
| 1–8 | Tám ô skill; sau này kéo skill đã học vào từng ô | Làm nền điều khiển trước; ô chưa có skill phải thể hiện trống, không giả tám skill đã tồn tại |
| Shift trái hoặc phải | Né theo hướng di chuyển; không có hướng thì dùng hướng nhân vật | Cooldown ban đầu 4 giây; thể lực và tương tác theo class làm sau |
| E / prompt | Nói chuyện, nhận nhiệm vụ, nhặt và tương tác | Giữ điều khiển tương tác |
| Điều khiển cảm ứng / tay cầm | Có hành động tương đương cho đánh, skill và né | Nút DODGE trên cảm ứng, B trên tay cầm |

Space chỉ dùng nhảy; Shift thay yêu cầu double-Space cũ theo phản hồi mới. Đòn thường, né và skill không được bỏ qua hồi chiêu khi đổi thú, chết/hồi sinh hoặc spam remote. Về sau skill dùng mana hoặc nộ tùy class; chưa ghép mọi class vào một thanh tài nguyên chỉ để tiện viết mã.

## Một vùng đất có bản sắc

Map khởi đầu là **một vùng đất liền liên tục**, có trại/làng, đường rừng, suối, vách đá và phế tích trong cùng cảnh quan. Lối đi, độ cao và vật chắn tạo lựa chọn khi đánh. Tránh bố cục đảo nhiệt đới tách mảnh, quảng trường phẳng nhiều màu và nhịp tiến từ đảo này sang đảo khác làm người chơi liên tưởng tới Blox Fruits. Dùng ảnh tham khảo để học hình khối, ánh sáng và độ rõ; tự thiết kế model và địa danh.

Theo yêu cầu mới, mở rộng diện tích có thể đi khoảng 5–10 lần bản 220×260; mốc này chọn 550×624, đúng 6 lần diện tích, cùng 25 điểm quái thuộc bốn loại. Giữ đường săn đầu gần làng, thêm các tuyến khám phá riêng để map lớn không bắt nhiệm vụ đầu kéo dài. Điều chỉnh mật độ theo đi lại và hiệu năng thực. NPC, dụng cụ nghề, cây cỏ và dấu vết sinh vật giải thích nơi này đang sống; không rải đồ trang trí dày để che địa hình thiếu ý tưởng.

Đặt bến xe ngựa hoặc cổng dẫn sang vùng khác nhưng đóng chức năng cho tới khi vùng đầu chơi tốt. Vùng sau khó hơn, có quái/cơ chế và tài nguyên mới; cần lý do đi tới và đường quay lại, không chỉ thay màu đất rồi tăng máu. Chưa làm cả thế giới trong một đợt.

## Cấp độ, class và vũ khí

Ở level 1, người chơi chọn một trong ba class nền. Tên Việt dưới đây là tên làm việc; UI phát hành dùng tiếng Anh dễ đọc và có khóa dịch. **Thuật sư / Arcanist** là class học phép ban đầu, chưa gọi sẵn là healer hoặc pháp sư DPS.

| Class nền | Họ vũ khí cần hỗ trợ | Vai trò khởi đầu |
| --- | --- | --- |
| Đấu sĩ / Fighter | Kiếm một tay, rìu một tay; kiếm hai tay, rìu hai tay; khiên ở tay phụ | Đánh gần, chọn phòng thủ bằng khiên hoặc đòn chậm mạnh bằng hai tay |
| Thợ săn / Hunter | Cung và dao găm | Giữ khoảng cách hoặc tiếp cận linh hoạt; cơ chế đổi bộ vũ khí cần chốt khi làm hệ trang bị |
| Thuật sư / Arcanist | Gậy phép một tay, sách phép một tay; orb ở tay phụ; gậy phép hai tay, sách phép hai tay | Học phép căn bản rồi mới chọn chuyên môn sát thương hoặc hỗ trợ |

Mỗi vật phẩm có loại, ô được trang bị, yêu cầu class/level và số tay sử dụng. Vũ khí hai tay khóa tay phụ; khi đổi sang hai tay phải trả món tay phụ về túi an toàn, không xóa hoặc nhân đôi. Cung/dao găm và sách một/hai tay là họ vũ khí theo yêu cầu, chưa mặc định tất cả kết hợp đều trang bị đồng thời. Quy tắc cụ thể được ghi khi triển khai hệ này.

WoW Classic và Albion là tham khảo về vai trò, đánh đổi trang bị và cách đọc một bộ kỹ năng. Không sao chép tên class, hệ số, bản đồ, asset hoặc nhận là đã nghiên cứu nguồn mới trong đợt này. Giá trị cần học là lựa chọn có cái được/cái mất: khiên đổi sát thương lấy khả năng trụ, hai tay có nhịp riêng, vũ khí và skill phải cùng một lối chơi.

Các mốc level 10/20/30/40 sẽ mở chuyển nghề hoặc đào sâu nghề. Cây dưới đây là **đề xuất để ghi nhớ hướng**, chưa quyết định số nhánh cuối cùng hay cân bằng:

| Class gốc | Hai hướng ở level 10 | Ý tưởng phát triển ở level 20/30/40 |
| --- | --- | --- |
| Đấu sĩ | Vệ binh / Guard; Phá giáp / Breaker | Vệ binh nghiêng về chắn và bảo vệ đồng đội; Phá giáp dùng nhịp vũ khí nặng và tạo khoảng mở để đánh |
| Thợ săn | Lãng ảnh / Shade; Xạ thủ / Marksman | Lãng ảnh theo nhánh dao găm/đạo tặc, áp sát và thoát hiểm; Xạ thủ theo nhánh cung, định vị và bẫy |
| Thuật sư | Sinh thuật / Lifecaller; Dẫn năng / Channeler | Sinh thuật phát triển hồi phục/hỗ trợ; Dẫn năng phát triển phép sát thương và kiểm soát vị trí |

Tên tự đề xuất, không phải tên từ game tham khảo; có thể đổi nếu chữ trong UI khó hiểu. Sau level 10, ưu tiên mở lựa chọn trong nhánh đã chọn ở 20/30/40 thay vì vẽ hàng chục nghề trước khi ba class nền đủ hay. Cần quyết định khả năng đổi nghề và chi phí hợp lý trong mốc class; chưa khóa người chơi vào lựa chọn không thể sửa.

## Chiến lợi phẩm và trang bị

Quái rơi tiền và EXP, có xác suất thấp rơi trang bị. Server quyết định drop và người đủ điều kiện nhận; không thưởng theo last hit để đồng đội không phải tranh nhau. Xác suất, lượng tiền, EXP và đường lên cấp là bảng cân bằng cần đo, chưa ghi một con số cố định thành lời hứa. Phải có hồ sơ lưu tiền, EXP, level, túi đồ và đồ đang mặc trước khi mở shop hoặc khuyến khích farm đồ hiếm.

| Nhóm | Ô / số lượng |
| --- | --- |
| Giáp | Mũ, áo, găng tay, quần, giày: một món mỗi ô |
| Trang sức | Một vòng cổ, tối đa ba nhẫn, một vòng tay |
| Lưng | Một áo choàng |
| Vũ khí | Vũ khí chính và tay phụ theo quy tắc một/hai tay; hỗ trợ kiếm, rìu, cung, dao găm, gậy, sách, orb và khiên |

Mỗi món có ID sở hữu riêng, định nghĩa gốc và chỉ số do server đọc. Client chỉ yêu cầu thao tác trang bị. Server kiểm tra quyền sở hữu, ô, class/level, tương tác hai tay và phép đổi túi trước khi áp chỉ số. Chết, reconnect và đổi server không được làm mất hoặc nhân đôi đồ.

NPC ở trại chỉ bán đồ cơ bản giúp người mới bắt đầu và đổi lối chơi. Đồ hiếm đến từ chơi: săn quái/boss và về sau farm nguyên liệu rồi craft. Craft có thể roll chỉ số và độ hiếm; phải công bố khả năng nhận trước thao tác, giữ nguyên liệu/roll phía server, xử lý thất bại lưu dữ liệu và cho người chơi đường nâng cấp có thể hiểu. Chưa cần xây nghề chế tác trong đợt combat.

Ngẫu nhiên sức mạnh là phần thưởng gameplay, không nối với gacha trả Robux, tiền mua bằng Robux hay boost trả phí. Trang bị miễn phí phải đủ để hoàn thành nội dung; đồ hiếm mở cách chơi và mục tiêu dài hạn, tránh biến chênh lệch chỉ số thành điều kiện được chơi cùng bạn.

## Thú có vai trò thật

Thú của người chơi phải tiến đến mục tiêu và đánh thường tự động khi chủ tham chiến. Đòn thường cần animation, giới hạn khoảng cách, đường nhìn và quyết định server; không để follower phía client tự gây damage. Cần lệnh trở về khi chủ chạy xa, chết hoặc đổi thú.

Thú có máu và chỉ số riêng; quái có thể đánh thú bằng đòn thường và skill. Khi thú bị hạ, chỉ hồi sinh sau khi chủ rời combat liên tục 10 giây. Quay lại combat hủy đếm ngược; đổi thú hoặc nhân vật hồi sinh không được bỏ qua điều kiện này. Skill thú tự sử dụng khi có mục tiêu hợp lệ; lệnh thủ công nếu còn giữ phải dùng chung hồi chiêu. Hiểu câu “ko chết hồi sinh” trong phản hồi là thú có thể chết và hồi sinh theo điều kiện trên.

Các phần phát triển sau: tiến hóa; nội tại buff nhân vật; skill gây sát thương, buff, gây choáng hoặc thu hút aggro. Làm từng vai trò trên một thú trước khi nhân ra cả bộ sưu tập. Khi có healer/taunt, hệ đóng góp cần nhận cả hỗ trợ hợp lệ, không chỉ người gây sát thương.

Tiến hóa có thể đổi ngoại hình, hành vi và lựa chọn chiến thuật, nhưng chỉ số tăng phải nằm trong cân bằng cấp độ. Hướng miễn phí đủ chức năng chiến đấu; pet hiếm hoặc hình thức mua Robux không mặc định là mạnh hơn. Không biến bộ sưu tập thành thang giá mua sức mạnh.

## Thời lượng, độ khó và chơi lâu dài

Nhịp 90–180 giây chuyến đầu và 60–120 giây khi quen ở [balance.md](balance.md) thuộc bản ba trận cũ; không dùng kết quả mô hình cũ làm kết luận cho AI di chuyển, né hoặc map mới. Đợt combat phải đo lại thời gian tiếp cận, trao đổi đòn, né, chết và đường về trước khi đặt nhiệm vụ dài hơn.

Mỗi lượt nên có một quyết định: chọn đường, đối phó loại quái, thử bộ skill/trang bị hoặc phối hợp với thú/bạn. Nội dung dài hạn thêm boss có cơ chế, vùng khác, nhật ký sinh vật, nguyên liệu và mục tiêu tự chọn. Tránh chỉ thay mức máu, buộc lặp một nhiệm vụ duy nhất hoặc phạt người nghỉ chơi. Tăng thử thách bằng mẫu đòn và phối hợp; nhân vật bắt đầu vẫn có thể học và thắng bằng đồ cơ bản.

Chữ và nút rõ trên điện thoại; tín hiệu nguy hiểm có hình/âm thanh, không chỉ màu. Có mức giảm hiệu ứng và chớp sáng; không dùng máu me cho nhóm tuổi mục tiêu. Animation đẹp phải đi cùng khả năng đọc đòn và FPS, không che màn hình bằng VFX.

## Bán hàng sau khi nền chơi ổn

Giữ yêu cầu pass 200–400 Robux và dải hàng/hộp 60–1200 Robux trong kế hoạch kinh doanh, cùng các điều kiện của [monetization.md](monetization.md). Paid random hiện tắt; chưa có Product ID, receipt hoặc quyết định phát hành cho từng thị trường EU. Đợt này không biến dự định gacha thành tính năng bán sức mạnh. Phải có lưu dữ liệu, trải nghiệm miễn phí tốt, kiểm thử giao dịch và kiểm tra chính sách trước khi bật cửa hàng.

Đồ mua trực tiếp nên có giá trị rõ và xem trước được: mỹ phẩm, biểu cảm, đồ trang trí, ngoại hình thú. Doanh thu cần dữ liệu người chơi thực; không hứa lượng Robux khi chưa có lượt chơi và phản hồi.
