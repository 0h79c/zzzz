# Cân bằng combat và nhịp nhiệm vụ Wildbond

Bản này đổi từ quái đứng yên báo vòng sang quái tuần tra, đuổi người chơi, đánh thường có lấy đà và hồi động tác. Boss giữ hai kỹ năng diện rộng bên cạnh đòn thường. Vì vị trí, góc đánh và thời gian tiếp cận đã thay đổi, bảng mô hình cũ cho chuyến săn khoảng 60–80 giây, boss 35,5 giây và máu còn lại 56/6 **không còn áp dụng**. Chưa có thời lượng hay tỷ lệ sống đo bằng Roblox Studio.

Chuyến săn ba mục tiêu hiện là bài thử nền combat. Mục tiêu thử **90–180 giây lượt đầu, 60–120 giây khi thuộc đường** vẫn là một giả thuyết cho chuyến săn này; không phải thời lượng map RPG đầu hay cam kết mỗi nhiệm vụ đều dài như vậy. Khi có nhiều quái, class, rơi đồ và đường khám phá, cần đo lại nhịp tiến triển thay vì tăng máu hoặc bắt người chơi chờ để đủ số phút.

## Chỉ số và hành vi hiện tại

| Thành phần | Chỉ số |
| --- | --- |
| Người chơi | 100 máu; đi 20 studs/giây |
| Đánh thường | Click; 10 sát thương, hồi 0,6 giây, cự ly 8 studs |
| Lệnh thú | 18 sát thương, hồi 3,2 giây, cự ly 18 studs; đòn tới sau 0,3 giây |
| Né | Nhấn Space hai lần trong 0,28 giây; tối đa 16 studs trong 0,3 giây; miễn sát thương tối đa 0,18 giây; hồi 4 giây |
| Đòn thường của quái | Lấy đà 0,65 giây, khóa hướng, kiểm tra cung đánh phía trước và cự ly 5 studs; hồi động tác 0,28 giây |
| Bramble Sprout | 140 máu; đánh thường 8 sát thương, hồi 1,2 giây từ lúc lấy đà; hiện không dùng kỹ năng AoE |
| Reed Guardian | 200 máu; đánh thường 10 sát thương, hồi 1,2 giây từ lúc lấy đà; hiện không dùng kỹ năng AoE |
| Hollow Crown | 600 máu; đánh thường 12 sát thương, hồi 1,5 giây từ lúc lấy đà |
| Kỹ năng boss | 22 sát thương, lấy đà 1,2 giây; đổi giữa vòng tại mục tiêu bán kính 7 và vòng quanh boss bán kính 10 studs |
| Di chuyển của quái | Tuần tra trong phạm vi nhà 12 studs ở tốc độ 3,5; đuổi ở tốc độ 7; giới hạn kéo ra khỏi nhà 28 studs |
| Chơi nhóm | Máu nền × [1 + 0,65 × (số người góp sát thương − 1)], tối đa bốn người tính độ khó |

Boss chỉ bắt đầu một kỹ năng khi không còn đòn thường hoặc động tác hồi đang chạy. Lần đầu sẵn sàng sau 2,8 giây từ khi vào trận; các lần sau sẵn sàng 5 giây sau khi kỹ năng giải quyết. Kỹ năng có thể chờ một động tác đang dở; không cộng hai loại sát thương như thể cả hai đánh cùng lúc.

Quái khóa hướng đòn thường khi lấy đà, không quay theo người chơi tới tận thời điểm trúng. Người chơi có thể lùi khỏi tầm hoặc đi vòng khỏi hướng đánh. Phạm vi và đường nhìn được kiểm tra lại khi đòn tới; miễn sát thương khi né do server kiểm tra. Di chuyển có kiểm tra vật cản và mặt đất, chưa phải hệ tìm đường cho mọi địa hình. Né có thể bị rút ngắn hoặc từ chối nếu đường không an toàn, nên 8 studs là giới hạn chứ không bảo đảm mỗi lần đều đi đủ.

Không hồi máu thụ động trong trận. Nhận hunt, nhận thưởng và hồi sinh hồi đầy máu. Các mục tiêu đã hoàn thành vẫn giữ nếu chết trong phiên. Máu quái tăng khi một người mới thực sự góp sát thương; người đứng xem không tăng độ khó. Rời trận không làm phần máu đã phân bổ tự giảm. Sau 10 giây không còn người đủ điều kiện gần đó và có đường nhìn, quái quay về nhà và reset; quái bị hạ hồi sau 6 giây. Trước khi nhận hunt, hoặc sau khi đã hoàn thành mục tiêu tương ứng, người chơi chưa bị các quái đó chọn làm mục tiêu.

## Khoảng thoát và độ khó

Ở mặt đất trống, lấy trường hợp người chơi đứng sát tâm quái: để đi ra ngoài cự ly 5 studs ở tốc độ 20 cần hơn 0,25 giây. Windup 0,65 giây để lại dưới 0,40 giây cho nhận biết và bắt đầu di chuyển, chưa trừ độ trễ hoặc vật cản. Đây là lý do tăng windup từ 0,45 lên 0,65 giây; hoạt ảnh lấy đà phải cho người chơi nhìn thấy đúng khoảng thời gian đó. Đi ngang khỏi cung đánh có thể thoát nhanh hơn, nhưng phải thử camera và animation trong Studio.

Nhịp đòn thường 1,2–1,5 giây nhanh hơn hồi né 4 giây. Vì vậy người chơi cần vừa đánh vừa đi, không thể nhấn né cho mọi đòn. Hai lần Space cần được nhận trong 0,28 giây; độ trễ input và mạng xảy ra trước lúc server chấp nhận né. Miễn sát thương chỉ dài tối đa 0,18 giây đầu, ngắn hơn động tác 0,22 giây; nếu bị vật cản dừng sớm, miễn sát thương cũng kết thúc sớm. Không mô tả né là bất tử trong toàn bộ động tác, và không yêu cầu né là cách duy nhất thoát kỹ năng boss.

Vòng tại mục tiêu bán kính 7 cần hơn 0,35 giây đi bộ từ tâm tới ngoài vòng; windup 1,2 để lại dưới 0,85 giây phản ứng trên mặt đất trống. Vòng quanh boss bán kính 10, nếu bắt đầu ở mép cự ly đánh của người chơi 8, chỉ cần đi thêm hơn 2 studs, tức hơn 0,10 giây; khoảng phản ứng còn dưới 1,10 giây. Nếu đã đứng sát boss, phải đi xa hơn. Các phép tính không bao gồm kích thước cơ thể, đường vòng, camera, tick server hoặc vật cản.

Rủi ro ngược lại là combat quá dễ khi giữ khoảng cách: người chơi đi 20, quái đuổi 7, còn đòn người chơi với tới 8 so với tầm quái 5. Giữ đúng khoảng cách trên đường trống có thể né phần lớn đòn thường và vẫn đánh được. Giai đoạn đầu ưu tiên việc học động tác; sau khi thử thực tế mới cân nhắc tốc độ từng loài, khoảng cách tiếp cận hay một đòn lao có báo trước. Không tăng máu để che việc AI không tạo áp lực.

Với thanh 100 máu đầy, riêng đòn thường cần 13 lần trúng từ Sprout, 10 từ Guardian hoặc 9 từ boss để hạ người chơi. Đây là ngân sách lỗi theo từng loại đòn, không phải số lần một người sẽ bị trúng. Máu mang từ trận trước và kỹ năng boss làm ngân sách thực thấp hơn. Chưa dự đoán tỷ lệ chết cho người mới khi chưa có dữ liệu về di chuyển và camera.

## Thời gian hạ quái lý thuyết

Vùng nay có chín spawn/bốn loại. Ba bounty vẫn là vòng nhiệm vụ; sáu quái thường (Sprout 80 máu, Boar 75, Reed 100) có thể đánh không cần bounty nhưng chưa drop tiền/EXP/gear. Không cộng sáu trận này vào thời gian nhiệm vụ mặc định. Lướt vừa tăng từ 8 lên 16 studs theo phản hồi; thời gian 0,3 giây/cooldown 4 giây và kiểm tra từng đoạn cần thử lại trong Studio, không suy độ khó bằng quãng lướt đơn lẻ.

Chạy `.tools/lune run scripts/balance_report.luau` từ thư mục project. Báo cáo đọc `CombatRules`, `DodgeRules`, `Expedition`, tốc độ từ project và hình học đường nếu còn biểu diễn bằng bảng tọa độ. Không có bộ chỉ số quái thứ hai trong script.

Bảng dưới cho **thời gian ngắn nhất theo sát thương hiện có**: bắt đầu với cooldown sẵn sàng, click đúng nhịp từ giây 0, tất cả đòn trúng, luôn đủ cự ly và đường nhìn; lệnh pet cũng dùng đúng nhịp và tới sau 0,3 giây. Bỏ qua di chuyển, sát thương nhận vào, đọc tình huống, đánh trượt và độ trễ. Pet chưa tự đánh thường; không thêm sát thương giả định từ tính năng tương lai.

| Quái | Chỉ đánh thường | Đánh thường + lệnh pet |
| --- | --- | --- |
| Bramble Sprout, 140 máu | 7,8 giây | 6,0 giây |
| Reed Guardian, 200 máu | 11,4 giây | 8,4 giây |
| Hollow Crown, 600 máu | 35,4 giây | 25,9 giây |

Tốc độ sát thương danh nghĩa dài hạn là 16,67/giây từ đòn thường và 5,625/giây từ lệnh pet, tổng khoảng 22,29/giây. Bảng dùng từng lần trúng theo cooldown và windup, không chia máu thẳng cho DPS để đo thời gian trận ngắn. Trận thật sẽ chịu ảnh hưởng của việc dừng đánh, mất cự ly, quái di chuyển và người chơi ngã; bảng không chứng minh boss mất khoảng 26 giây trong Studio.

Nếu mọi người cùng góp sát thương từ đầu, boss có:

| Người góp sát thương | Máu boss | Cận dưới thời gian với pet tương đương |
| --- | --- | --- |
| 1 | 600 | 25,9 giây |
| 2 | 990 | 21,6 giây |
| 3 | 1.380 | 19,8 giây |
| 4 | 1.770 | 19,5 giây |

Đây là người đánh thực sự, không phải số người trong server. Mô hình giả định đòn của nhóm đồng thời và luôn trúng; tham gia giữa trận hoặc phối hợp kém cần thử bằng nhiều client. Boss AoE có thể trúng nhiều người, trong khi đòn thường nhắm một mục tiêu, nên không suy khả năng sống của nhóm từ bảng máu.

Script in thêm áp lực đòn thường nếu luôn đứng trong cự ly và nhận mọi đòn: tối đa danh nghĩa 6,67/8,33/8 máu mỗi giây. Đây là kiểm tra riêng bỏ qua kỹ năng, chase, né và tick server. Không cộng nó với một DPS kỹ năng rồi coi là dự báo sát thương thực.

Chiều dài đường dựng sẵn chỉ là bối cảnh hình học. Không cộng đường đó với bảng hạ quái để khẳng định thời lượng hunt: người chơi có thể đi tắt, tìm quái đang tuần tra, nhặt tinh thể, lùi khỏi trận, bị hạ hoặc tìm đường lần đầu. Mô hình đi đứng và nhận sát thương của quái đứng yên ở bản trước đã được gỡ khỏi báo cáo.

## Thưởng, class, trang bị và thú ở các đợt sau

Thưởng hiện giữ 60 shells/chuyến; cáo 120, gấu con 240. Mở riêng cáo cần hai chuyến; mua cáo rồi gấu cần tổng sáu chuyến. Cả ba thú có cùng lệnh đánh hiện tại, chưa có tiến hóa, nội tại, tự đánh hoặc vai trò riêng. Đây là vòng sưu tầm của alpha; chưa tăng giá để kéo dài grind trước khi có nội dung.

Hướng RPG mới cần tách tiến triển thành mục tiêu nhỏ: học một động tác, kiếm một món cơ bản, thử một vùng quái mới và mở nhánh nghề. Sau khi có map và mật độ quái thật mới đo thời gian đạt level/class và đồ cần thiết. Trang bị khởi đầu ở NPC phải đủ để đánh quái cùng cấp; rơi đồ hiếm là phần thưởng thêm, không là điều kiện vượt vùng đầu. Xác suất thấp cần đánh giá bằng số lượt trung bình `1/p` cùng thời gian mỗi lượt đã đo, không chỉ ghi một tỷ lệ nghe hấp dẫn.

Thanh phím 1–8 là chỗ gán kỹ năng về sau; không mặc định người mới phải học và dùng đủ tám kỹ năng ngay lập tức. Tốn mana, nộ, thể lực và nhánh nghề sẽ có ngân sách riêng theo class. Ở giai đoạn này chưa có hệ tài nguyên, nên báo cáo không giả lập chi phí hay khả năng duy trì kỹ năng.

Khi có nhiều ô trang bị, cần giới hạn tổng sát thương, giảm hồi chiêu và chống chịu theo cấp; cộng từng món riêng có thể làm boss mất toàn bộ cơ chế. Vũ khí hai tay phải khóa ô phụ; ba nhẫn không được trở thành ba bản sao cộng dồn cùng một nội tại mạnh. Các nguyên tắc này là yêu cầu thiết kế cho đợt trang bị, chưa phải tính năng đang chạy.

Khi pet có tự đánh, tiến hóa và nội tại buff, phải đưa cả ba vào tổng sát thương của người chơi trước khi chỉnh máu quái. Tiến hóa nên mở một vai trò hoặc quyết định chiến thuật, như chặn một đòn, kéo aggro có giới hạn hoặc hỗ trợ hồi phục; không để mọi pet cùng cộng sát thương, choáng và hút aggro liên tục. Các vai trò miễn phí phải chơi được các vùng chính. Không dùng pet Robux để bù một trận cố tình quá khó cho thú miễn phí.

## Kiểm tra tiếp trong Studio

Thử một người trước, rồi hai và bốn client thực sự đánh. Ghi riêng thời gian nhận hunt tới trận đầu, từng trận và đoạn nhặt tinh thể tới nhận thưởng; ghi cả lần thất bại, số đòn thường/kỹ năng bị trúng, lần né bị từ chối và đoạn đứng chờ. Đồng hồ hunt giúp lấy tổng thời gian và số lần ngã, chưa phân loại tự động sát thương theo từng đòn. Không chỉ lấy lần chơi nhanh nhất.

Trong từng trận, thử đứng yên một lần để xem đòn thường có tới đúng animation; lùi sau dấu lấy đà; đi ngang; đánh từ mép 8 studs; dụ ra giới hạn nhà; né khi sát tường và khi lần Space đầu đang nhảy. Quái không được vừa đánh vừa đổi hướng để đuổi theo sau lưng, mắc vào cảnh vật mà vẫn gây sát thương, hoặc giữ damage khi đã quay về reset. Thử riêng né sớm và muộn vì 0,18 giây miễn sát thương không phủ toàn bộ 0,22 giây di chuyển.

Nếu người mới hiểu dấu báo nhưng vẫn bị hạ liên tiếp, kiểm tra độ rõ của animation, đường thoát và độ trễ trước khi giảm sát thương. Nếu giữ khoảng cách khiến quái không đánh được lần nào, sửa hành vi và cự ly thay vì tăng máu. Nếu chuyến săn vượt ba phút do đi lạc hoặc chờ quái hồi, sửa chỉ dẫn và mật độ spawn; đó không phải nội dung để giữ chân.

Chưa có dữ liệu giữ chân, chi tiêu hay chơi nhiều phiên để suy khả năng kiếm Robux. Combat, tiến độ lưu đáng tin cậy và nội dung đủ chơi phải được thử trước khi đánh giá cửa hàng.
