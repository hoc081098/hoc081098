# Rate limiting strategies for Nginx, API Gateway, and service layers

> Estimated reading time: 7 minutes

Rate limiting không nên được đặt ở một tầng duy nhất. Trong một hệ thống backend có phân tầng rõ ràng, rate limiting
thường xuất hiện ở ba vị trí: Nginx (edge), API Gateway và từng service cụ thể. Mỗi tầng có mục tiêu khác nhau, và nếu
phân định đúng, chúng bổ trợ cho nhau thay vì chồng chéo.

```
Internet
   ↓
Nginx (IP flood protection)
   ↓
YARP (user / tenant policy limit)
   ↓
Service (domain limit / concurrency limit)
```

## 1. Nginx - tầng hạ tầng (edge / infra level)

- Config các basic rate limiting nhằm mục đích chống spam/DDoS, chống flood thô.
  Đây là lớp phòng thủ đầu tiên trước khi request chạm tới business logic.
  Nó không hiểu JWT là gì, không biết UserId hay TenantId nào đang gọi. Nó chỉ nhìn thấy network-level metadata.
- Ví dụ: limit theo IP address, Geo block (theo quốc gia/vùng), hoặc giới hạn request rate và connection ở mức IP
- Mục tiêu: network-level protection - chặn rác ở tầng infra/network, trước khi đi sâu vào business logic

```nginx
http {
    # ... other http settings ...
    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=5r/s;
}

server {
    # ... other server settings ...

    limit_req_status 429; # Return "429 Too Many Requests" error
    location /login/ {
        limit_req zone=mylimit burst=10 nodelay;
        # ... other location settings, e.g., proxy_pass ...
    }
}
```

- Sử dụng `limit_req_zone` directive trong `http` block với
    - `$binary_remote_addr`: sử dụng IP address của client trong dạng nhị phân để làm KEY.
    - `zone=mylimit:10m`: tạo 1 zone tên là "mylimit" có size `10MB` memory (có thể lưu trữ trạng thái của khoảng 160,000 địa chỉ IP)
    - `rate=5r/s`: giới hạn tốc độ là 5 requests/giây cho mỗi IP address.

- Sử dụng `limit_req` directive trong `location` block để áp dụng limit đã định nghĩa ở trên.
    - `zone=mylimit`: chỉ định zone đã tạo ở trên
    - `burst=10`: Thiết lập một "hàng đợi" dự phòng cho phép tối đa 10 request vượt định mức.
      Thay vì bị từ chối ngay lập tức khi vượt quá rate, các request này sẽ được tạm giữ lại trong bộ nhớ của Nginx.
    - Mặc định (không có `nodelay`): Nginx sẽ "điều tiết" lưu lượng bằng cách áp đặt độ trễ (delay).
      Các request trong hàng đợi `burst` sẽ bị ép phải xếp hàng và đi qua cửa kiểm soát từng cái một theo đúng nhịp độ của rate.
      Kết quả là người dùng sẽ thấy ứng dụng bị chậm lại (latency cao) nhưng không bị lỗi.
      `nodelay`: Khi kích hoạt, Nginx sẽ ưu tiên trải nghiệm người dùng bằng cách cho phép các request trong hàng đợi
      được xử lý ngay lập tức mà không cần chờ đợi.
      Tuy nhiên, mỗi request "đi tắt" này vẫn sẽ chiếm dụng một slot trong hàng đợi burst và chỉ được giải phóng (hồi slot) theo đúng tốc độ của rate.
    - Lưu ý: Chỉ khi hàng đợi dự phòng này bị lấp đầy hoàn toàn (vượt quá cả `rate` lẫn `burst`),
      Nginx mới bắt đầu từ chối bằng status code đã cấu hình (ví dụ: 429).

## 2. API Gateway (ví dụ YARP)

- Config rate limiting chung cho các services phía sau. Tầng này có thể parse và hiểu JWT, UserId, TenantId, API key,
  API version. Khác với Nginx, gateway hiểu "ai đang gọi", không chỉ "IP nào đang gọi".
  Vì vậy, nó phù hợp để enforce các chính sách truy cập và quota mang tính hệ thống.
- Ví dụ: limit theo UserId, TenantId, apply quota theo API key, API version, Quota theo app.
- Mục tiêu: policy-level control - bảo vệ tài nguyên theo các rules/policies chung cho nhiều services.

## 3. Service: tầng business logic cụ thể

- Khi request đi tới service, rate limiting không còn đơn thuần là bảo vệ hạ tầng hay thực thi policy chung nữa, mà gắn trực tiếp với domain.
  Ở đây, ta config rate limiting riêng cho service đó, dựa trên business logic đặc thù của service.
- Ví dụ: một user chỉ được tạo 5 order/phút, một tenant chỉ được gửi 1,000 webhook/phút, chỉ cho phép 10 concurrent job
  xử lý
- Mục tiêu: business-level control - bảo vệ tài nguyên dựa trên logic cụ thể.

## 4. Rate Limiting Algorithms trong ASP.NET Core (có thể dùng cho YARP và Services)

- Fixed Window: Đơn giản, giới hạn số requests trong 1 window cố định. Nhưng dễ bị spike ở window boundary.
- Sliding Window: Cải tiến hơn Fixed Window. Giới hạn N request/X giây gần nhất bằng cách chia Window thành nhiều segment cố định, mỗi khi check sẽ đếm số request của segment hiện tại với các segment trước đó.
  Giảm spike tại window boundary. Nhưng tốn kém hơn về mặt memory vì phải lưu nhiều segment.
  Đọc thêm tại https://www.facebook.com/hoc081098/posts/pfbid02XBGAAW7iu8SymptgHhxERbfwri4RQGNGJaJ4kR72vv4iUu6bGTtUJ6q3HPbQP2Wgl
- Token Bucket: Mỗi request sẽ "rút" token từ bucket. Bucket được refill theo thời gian.
  Cho phép burst trong 1 thời gian ngắn & giữ tốc độ trung bình trong thời gian dài.
  Phù hợp với các hệ thống cần cho phép burst nhưng vẫn kiểm soát lưu lượng trung bình.
  Đọc thêm tại https://www.facebook.com/hoc081098/posts/pfbid02s3RrBtD93FminminepcLM4GBhkADZ95bmjwz9GXWAsYMWDgXUc1uRnVYuwRwojRwl
- Concurrency: Giới hạn số requests đang được xử lý đồng thời tại 1 thời điểm.
  Không giới hạn số request theo thời gian, mà giới hạn số request đang xử lý đồng thời.
  Phù hợp với các hệ thống có tài nguyên hạn chế hoặc cần đảm bảo hiệu suất ổn định.

Một đoạn code ví dụ về cách cấu hình Rate Limiting trong YARP:

File `Program.cs`
```csharp
// 1. Add Rate Limiter.
services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("customPolicy", opt =>
    {
        opt.PermitLimit = 4;
        opt.Window = TimeSpan.FromSeconds(12);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = 2;
    });
});

// 2. add the RateLimiter middleware.
app.UseRateLimiter();

app.MapReverseProxy();
```

File `appsettings.json` - Apply `customPolicy` rate limit policy cho route1:
```json
{
  "ReverseProxy": {
    "Routes": {
      "route1" : {
        "ClusterId": "cluster1",
        "RateLimiterPolicy": "customPolicy",
        "Match": {"Hosts": [ "localhost" ]}
      }
    },
    "Clusters": {
      "cluster1": {
        "Destinations": {
          "cluster1/destination1": {
            "Address": "https://localhost:10001/"
          }
        }
      }
    }
  }
}
```

Đọc thêm Microsoft docs: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/rate-limiting?view=aspnetcore-10.0

## Khi phân tầng đúng, chúng bổ trợ nhau

- Edge (Nginx): stateless & IP-based -> chống rác ở network level
- Gateway (YARP): identity-aware -> enforce policy theo identity
- Service: stateful & domain-aware -> enforce invariant theo domain

Chúng chỉ overlap khi ranh giới không rõ ràng. Ví dụ, nếu Nginx limit quá chặt, request hợp lệ có thể bị chặn trước
khi tới gateway hoặc service, khiến các tầng phía dưới không còn ý nghĩa thực tế.
Hoặc nếu cùng một logic rate limiting bị định nghĩa trùng nhau ở cả Nginx và Gateway, hệ thống sẽ trở nên rối rắm và khó kiểm soát.
Rate limiting, nếu nhìn đúng bản chất, không phải một cấu hình duy nhất. Nó là một chiến lược phân tầng.
Và sự rõ ràng trong phân tầng mới là thứ quyết định hệ thống có gọn gàng hay trở thành spaghetti policy.

