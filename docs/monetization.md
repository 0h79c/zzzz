# Wildbond — cửa hàng và Robux

Mục tiêu là bán thứ người chơi muốn giữ vì đẹp và có cá tính. Chiến thắng boss, mở vùng đất và tìm pet đều phải có đường chơi miễn phí đủ tốt. Bản chơi đầu tiên không thu Robux; các mức giá dưới đây là đề xuất, chưa có Product ID, Pass ID hay sản phẩm được tạo trên Roblox.

## Hàng bán trước

| Món hàng | Giá gốc đề xuất | Người chơi nhận chắc chắn |
| --- | ---: | --- |
| Explorer Style, game pass | 249 Robux | Bộ trang phục thám hiểm trong game, dấu chân trang trí và emote chụp ảnh |
| Camp Atelier, game pass | 349 Robux | Bộ đồ trang trí trại và khung ảnh sưu tập; chức năng cốt lõi của trại vẫn miễn phí |
| Cosmetic bundles, developer products | 60–1200 Robux | Nội dung được xem đầy đủ trước mua: màu pet, hiệu ứng hoặc bộ trang trí; không tăng sức chiến đấu |

Đừng mở cả thang giá ngay ngày đầu. Bắt đầu bằng một bộ nhỏ và một pass có giá trị rõ ràng, kiểm tra người chơi có thích chúng không. Mức 1200 chỉ nên dành cho bộ lớn có nhiều món xác định trước, sau khi đã có phản hồi. Robux thực người chơi thấy có thể khác giá gốc khi Roblox áp dụng giá vùng.

Không bán thêm ô pet chiến đấu, sát thương, lợi thế bảng xếp hạng hay tiền mà sau đó có thể dùng để quay thưởng. Cửa hàng nằm ở trại và trong một nút riêng; không chen lời mời mua sau khi chết hoặc chặn màn hình nhận thưởng. Không dùng đếm ngược giả, chuỗi đăng nhập bị mất nếu nghỉ chơi hoặc lời mời mua để cứu chuỗi.

## Yêu cầu gacha 60–1200 Robux

Giữ đây là một nhánh cần đánh giá sau, không bật trong milestone 1. Với nhóm 12–16 tuổi ở EU, không có một thiết lập chung đủ để kết luận bán hộp trả tiền được phép cho mọi người. Tuân thủ Roblox và xem xét pháp luật ở từng thị trường là hai công việc khác nhau; tài liệu Roblox dưới đây không thay thế đánh giá pháp lý trước phát hành.

Trong lúc đó, có thể tạo cảm giác khám phá bằng thưởng ngẫu nhiên kiếm từ hoạt động chơi. Nếu dùng vé săn, vé chỉ kiếm được bằng chơi, không bán hoặc đổi từ Robux, tiền trả phí hay pass; không bán tăng xác suất nhận thưởng. Pet mở đầu được nhận trực tiếp theo mốc, không quay. Mỹ phẩm mua trực tiếp không đổi sang vé hoặc vật phẩm quay.

Nếu sau này có nhánh gacha trả tiền, chỉ triển khai khi đã hoàn thành tất cả điều kiện này:

- Tra cứu `PolicyService:GetPolicyInfoForPlayerAsync(player)` phía server và xử lý lỗi bằng `pcall`. `ArePaidRandomItemsRestricted == true` phải chặn tương tác với bộ sinh thưởng trả tiền; chưa có kết quả đáng tin cũng không mở mua. UI phải phản ánh quyết định server, không chỉ giấu nút.
- Hiển thị trước mua mọi kết quả cuối cùng và xác suất thực theo phần trăm. Xác suất bên dưới phải tổng 100%; nếu làm tròn số hiển thị, áp dụng chú thích làm tròn theo hướng dẫn Roblox. Chỉ ghi xác suất theo độ hiếm mà không có danh sách từng món là chưa đủ.
- Nếu thay đổi phần thưởng theo bộ sưu tập, pity hoặc boost, xác suất hiển thị phải khớp xác suất hiện tại của người đó. Mua chìa khóa, tiền hoặc lượt quay bằng Robux cũng là mua ngẫu nhiên gián tiếp, không phải đường tránh chính sách.
- Giữ cửa hàng mua trực tiếp và con đường nhận thưởng miễn phí cho người không được phép mua ngẫu nhiên. Tránh thiết kế cả khu vực xoay quanh hộp trả tiền rồi loại những người này khỏi cuộc chơi.
- Không triển khai trao đổi ở các milestone đầu. Khi có trao đổi vật phẩm trả phí, kiểm tra `IsPaidItemTradingAllowed` cho các bên và nguồn gốc món đồ; cờ false không được trao đổi đồ trả phí. Giao dịch/quà tặng với giá vùng cần xử lý chênh lệch giá riêng.
- Kiểm thử quyền bị hạn chế, lỗi API, mua bị hủy, receipt lặp, đổi server và lỗi lưu dữ liệu. Cấu hình mặc định vẫn tắt paid random; chỉ đổi sau khi xác nhận sản phẩm, chính sách và thị trường áp dụng.

## Giao dịch phải chịu được mất kết nối

Developer products là món có thể mua nhiều lần; game pass là quyền lợi mua một lần. Dùng `MarketplaceService.ProcessReceipt` ở server cho developer products. `PromptProductPurchaseFinished` chỉ báo kết thúc prompt, không chứng minh giao dịch thành công và không được dùng để phát đồ.

Thiết kế receipt theo `PurchaseId`: trong một thao tác cập nhật hồ sơ bền vững, vừa cấp đồ vừa ghi receipt đã xử lý. Nếu receipt cũ chạy lại, trả quyết định thành công mà không phát lần hai. Không làm hai bước độc lập “phát đồ, rồi ghi receipt”, vì server có thể tắt giữa chúng. Có cơ chế khóa/cập nhật hồ sơ phù hợp và thử hai server xử lý cùng một receipt. Chỉ trả `PurchaseGranted` khi quyền lợi đã lưu thành công; khi chưa thể lưu/cấp, trả `NotProcessedYet`. Roblox không hứa tự thử lại theo bộ đếm thời gian, nên cần trải nghiệm thông báo chờ xử lý rõ ràng.

Với pass, kiểm tra quyền sở hữu bằng API server và áp lại quyền lợi khi vào game. Client không được tự khai đã mua, giá hoặc số lượng nhận. Mỗi sản phẩm phải có ID thật trong đúng experience; không dùng ID mẫu ở bản phát hành.

Lấy thông tin giá trên client bằng `MarketplaceService:GetProductInfoAsync` với `Enum.InfoType.Product` hoặc `Enum.InfoType.GamePass`; hiển thị `PriceInRobux` theo kết quả hiện tại. Không in cố định “249” vào UI bán hàng. Nếu chưa lấy được giá, hiển thị trạng thái chờ và không bịa giá. Dùng công cụ Dynamic Price Check của Roblox trước khi bật cửa hàng.

## Đo chất lượng trước doanh thu

Theo dõi tỷ lệ hoàn thành chuyến săn đầu tiên, người quay lại ngày 1/ngày 7, số chuyến săn tự chọn chơi thêm, hiệu năng mobile và lỗi lưu/giao dịch. Ghi nhận mua và giao đồ để đối soát, không thu thông tin cá nhân để suy đoán khả năng chi tiền của trẻ. Không đưa dự báo Robux khi chưa có dữ liệu người chơi thực.

UI trong game dùng tiếng Anh ngắn, dễ dịch qua string keys; thêm ngôn ngữ EU dựa trên người chơi thực. Khi hàng không khả dụng, lời nhắn nói rõ trạng thái và vẫn cho người chơi tiếp tục chơi.

## Nguồn đã đọc ngày 13/10/2026

Trang `create.roblox.com` bị mạng môi trường chặn; các bản nguồn tương ứng dưới đây được đọc trực tiếp từ kho tài liệu chính thức `Roblox/creator-docs`, nhánh `main`. Kiểm tra lại khi triển khai vì tài liệu có thể thay đổi.

- [Paid random items policy guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items) — [nguồn chính thức đã đọc](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/paid-random-items.md): cả mua trực tiếp/gián tiếp, từng kết quả, xác suất và xử lý người bị hạn chế.
- [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService) — [nguồn đã đọc](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/PolicyService.yaml): quyền được xác định theo tuổi, vị trí và nền tảng; API có thể lỗi.
- [Developer products](https://create.roblox.com/docs/production/monetization/developer-products) và [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt) — [nguồn products](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/developer-products.md), [nguồn API](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MarketplaceService.yaml): xử lý receipt, gọi lặp và đồng thời giữa server.
- [Passes](https://create.roblox.com/docs/production/monetization/passes) — [nguồn đã đọc](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/passes.md): quyền lợi mua một lần và kiểm tra sở hữu.
- [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing) — [nguồn đã đọc](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/regional-pricing.md): giá runtime, Managed Pricing và Dynamic Price Check.
