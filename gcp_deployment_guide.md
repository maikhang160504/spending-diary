# Hướng Dẫn Triển Khai Google Cloud Platform (GCP) & Tối Ưu Hóa Hệ Thống

Tài liệu này cung cấp hướng dẫn chi tiết từng bước để triển khai hệ thống **Node.js Backend**, **FastAPI AI Service**, **Expense OCR-NLU**, và **Web Admin** lên hạ tầng Google Cloud Platform (GCP), đồng thời đề xuất các chỉnh sửa mã nguồn, cải tiến và giải pháp khắc phục rủi ro vận hành thực tế.

---

## 1. Đề Xuất Kiến Trúc Triển Khai Trên GCP

Để đảm bảo hiệu năng và tối ưu chi phí, hệ thống được đề xuất phân tách thành các dịch vụ riêng biệt:

```mermaid
graph TD
    subgraph Google Cloud Platform (GCP)
        LB[Cloud Load Balancing] --> WA[Firebase Hosting / Cloud Storage: Web Admin Static]
        LB --> BE[Cloud Run: Node.js Backend]
        
        BE --> Redis[(Memorystore for Redis)]
        BE --> DB[(Cloud SQL for PostgreSQL)]
        
        BE -- HTTP/Queue --> AI[Compute Engine/GKE: FastAPI AI Service]
        AI -- CUDA/PyTorch --> GPU[NVIDIA T4/L4 GPU]
        
        AI <--> GCS[(Google Cloud Storage)]
        BE <--> GCS
        
        Secret[Secret Manager] -. Inject env .-> BE
        Secret -. Inject env .-> AI
    end
    
    Client[Mobile / Web Client] --> LB
```

### Chi tiết các dịch vụ GCP:
1. **Web Admin**: Triển khai dạng Static Web Hosting trên **Firebase Hosting** hoặc **Google Cloud Storage (GCS)** tích hợp CDN để tối ưu hóa tốc độ tải trang toàn cầu và giảm chi phí vận hành về gần mức $0$.
2. **Node.js Backend**: Triển khai trên **Google Cloud Run** (Serverless). Tự động scale từ 0 đến N instance, tiết kiệm tối đa chi phí khi không có người dùng.
3. **FastAPI AI Service & OCR-NLU**:
   - **Lựa chọn 1 (Khuyến nghị)**: **Google Compute Engine (VM)** loại `g2-standard-4` sử dụng **GPU NVIDIA L4** (24GB VRAM) hoặc `n1-standard-4` sử dụng **GPU NVIDIA T4** (16GB VRAM). Phù hợp chạy PyTorch/PaddleOCR ổn định với Driver CUDA cài sẵn.
   - **Lựa chọn 2**: **GKE (Google Kubernetes Engine)** với node pool có GPU hỗ trợ Auto-scaling. Phù hợp nếu có quy mô tải cực lớn và ngân sách dư dả.
4. **Database & Cache**:
   - **Cloud SQL (PostgreSQL 15+)**: Quản lý giao dịch, người dùng và dữ liệu huấn luyện.
   - **Memorystore for Redis**: Làm cache và broker quản lý hàng đợi bất đồng bộ.
5. **Storage & Security**:
   - **Google Cloud Storage (GCS)**: Lưu trữ ảnh hóa đơn thô (thay thế Cloudflare R2).
   - **GCP Secret Manager**: Lưu trữ API Key (Gemini, Kaggle, Postgres password) bảo mật.

---

## 2. Những Thay Đổi Cần Thực Hiện Trong Mã Nguồn (Cần Sửa Những Gì?)

### 2.1. Thay đổi Lưu trữ Hình ảnh: Chuyển đổi từ Cloudflare R2 sang Google Cloud Storage (GCS)

Hiện tại, hệ thống đang dùng [r2Client.js](file:///d:/Luan-Van/Project/app/backend/src/services/r2Client.js). Khi lên GCP, chúng ta cần thay thế hoặc cấu hình GCS Interoperability (tương thích S3 API). 

> [!TIP]
> **Giải pháp tối ưu**: Không cần viết lại code S3, hãy kích hoạt **Interoperability API trên GCS Console** để giả lập S3 Endpoint của Google, sau đó cấu hình lại biến môi trường trong Node.js và Python:
> - `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY` lấy từ GCP Interoperable keys.
> - `ENDPOINT` chuyển thành `https://storage.googleapis.com`.

Nếu muốn sử dụng thư viện gốc `@google-cloud/storage` của Google, cần thay thế code upload trong Node.js Backend:
```javascript
// NEW: gcsClient.js
const { Storage } = require('@google-cloud/storage');
const storage = new Storage();
const bucket = storage.bucket(process.env.GCS_BUCKET_NAME);

async function uploadToGCS(fileBuffer, destination, contentType) {
  const file = bucket.file(destination);
  await file.save(fileBuffer, {
    metadata: { contentType },
    resumable: false,
  });
  return `https://storage.googleapis.com/${bucket.name}/${destination}`;
}
```

### 2.2. Độc lập hóa Model Weights khỏi Docker Image
Kích thước tệp weights của `VietOCR` (`vgg_transformer.pth` ~ 400MB) và `PICK KIE` (`model_best.pth` ~ 500MB) rất lớn. Nếu đóng gói trực tiếp vào Docker Image, kích thước Image sẽ vượt quá 4GB, khiến thời gian deploy và khởi động lạnh (Cold Start) của GCP Container cực kỳ lâu.

* **Giải pháp sửa đổi**:
  1. Upload toàn bộ file weights lên một Bucket trên **Google Cloud Storage** (ví dụ: `gs://my-app-ai-weights/`).
  2. Trong file `Dockerfile` của `ai-service`, cấu hình bước tải weights khi container khởi động:
     ```dockerfile
     # Dockerfile - ai-service
     FROM python:3.11-slim
     # ... Cài đặt CUDA, PyTorch ...
     
     # Thay vì COPY weights, ta chạy script tải ngầm từ GCS
     # (Yêu cầu Container Service Account có quyền Storage Reader)
     ENTRYPOINT ["sh", "-c", "gcloud storage cp gs://my-app-ai-weights/* ./weights/ && uvicorn src.api.app:app --host 0.0.0.0 --port 8000"]
     ```

### 2.3. Cấu hình xác thực Kaggle API bảo mật
Các job huấn luyện lại PICK KIE chạy trên Kaggle cần file credential `kaggle.json`. 
* **Sửa đổi**: Thay vì ghi đè file này cục bộ, hãy lưu nội dung `KAGGLE_USERNAME` and `KAGGLE_KEY` vào **GCP Secret Manager**. Khi container `ai-service` chạy, đọc các biến này từ môi trường và tự động ghi ra thư mục `~/.kaggle/kaggle.json` bằng code Python khởi động:
  ```python
  # startup.py
  import os
  import json
  from pathlib import Path

  kaggle_dir = Path.home() / ".kaggle"
  kaggle_dir.mkdir(exist_ok=True)
  with open(kaggle_dir / "kaggle.json", "w") as f:
      json.dump({
          "username": os.getenv("KAGGLE_USERNAME"),
          "key": os.getenv("KAGGLE_KEY")
      }, f)
  os.chmod(kaggle_dir / "kaggle.json", 0o600)
  ```

---

## 3. Cải Tiến Hiệu Năng Vận Hành (Performance Improvements)

### 3.1. Biên dịch sang ONNX Runtime để giảm Latency trên CPU/GPU rẻ
PyTorch mặc định tiêu tốn rất nhiều tài nguyên và có độ trễ cao khi chạy trên CPU của VM giá rẻ.
* **Cải tiến**: Biên dịch mô hình **VietOCR** và **PICK KIE** sang định dạng **ONNX**.
  - ONNX Runtime chạy nhanh gấp **2 đến 3 lần** trên CPU thông thường và tốn ít RAM hơn.
  - Sử dụng lệnh PyTorch để export:
    ```python
    torch.onnx.export(model, dummy_input, "model.onnx", opset_version=12)
    ```
  - Thay thế engine dự đoán trong `pick_kie_inference.py` and `pipeline.py` sử dụng thư viện `onnxruntime` thay vì `torch`.

### 3.2. Cấu hình GPU Passthrough & CUDA Dynamic Memory Allocation
Nếu chạy trên Compute Engine có GPU T4/L4, PyTorch thường chiếm dụng (allocate) toàn bộ VRAM trống ngay khi import model. Điều này làm cho hệ thống không thể chạy song song nhiều tiến trình Python khác.
* **Cải tiến**: Thiết lập biến môi trường sau trong Container của AI Service:
  ```bash
  PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
  ```
  Giúp PyTorch giải phóng VRAM ngay khi xử lý xong một hóa đơn, tránh lỗi tràn bộ nhớ đồ họa (Out of Memory - OOM).

### 3.3. Tận dụng Cloud SQL Proxy cho bảo mật kết nối DB
Không được mở cổng công khai `5432` của Cloud SQL PostgreSQL ra ngoài internet.
* **Cải tiến**: Sử dụng **Cloud SQL Auth Proxy** chạy như một sidecar container bên cạnh Node.js Backend trong Cloud Run. Proxy này tự động tạo đường ống bảo mật mã hóa (mTLS) kết nối đến cơ sở dữ liệu mà không cần cấu hình IP Whitelist.

---

## 4. Khắc Phục Lỗi Vận Hành & Phòng Chống Sự Cố (Fault Tolerance)

### 4.1. Khắc phục lỗi Crash Container do thiếu bộ nhớ (Out Of Memory - OOM)
PaddleOCR + VietOCR khi xử lý ảnh độ phân giải cao (ví dụ: ảnh chụp hóa đơn 4K từ camera điện thoại) có thể tiêu tốn tới 3-4 GB RAM tại đỉnh điểm xử lý, dễ làm container của Google Cloud Run bị tắt đột ngột (OOM Killed).
* **Giải pháp khắc phục**:
  - Đặt giới hạn tài nguyên RAM tối thiểu cho container `ai-service` là **4GB RAM** (không dùng cấu hình mặc định 512MB/1GB).
  - Trước khi đưa ảnh vào PaddleOCR, tự động resize ảnh xuống độ phân giải tối đa là **1600px** ở chiều dài nhất. Việc này giảm 70% mức tiêu thụ RAM và tăng tốc độ OCR lên gấp 3 lần mà không làm giảm độ chính xác nhận dạng.
    ```python
    # rotation_corrector.py hoặc pipeline.py
    # Resize heuristic trước khi OCR
    h, w = image.shape[:2]
    if max(h, w) > 1600:
        scale = 1600 / max(h, w)
        image = cv2.resize(image, (int(w * scale), int(h * scale)))
    ```

### 4.2. Cấu hình Dead Letter Queue (DLQ) cho Hàng đợi Pipeline
Khi chạy kiến trúc bất đồng bộ (Asynchronous Queue), một số hóa đơn bị lỗi (ví dụ: file ảnh bị hỏng không thể giải mã) có thể làm treo worker mãi mãi nếu nó liên tục retry.
* **Giải pháp khắc phục**:
  - Cấu hình trong **BullMQ / Celery** giới hạn số lần retry tối đa là 3 lần (`max_retries = 3`).
  - Nếu sau 3 lần vẫn lỗi, tự động di chuyển tin nhắn sang **Dead Letter Queue (DLQ)** để tránh làm nghẽn các hóa đơn của người dùng khác. Hệ thống sẽ bắn cảnh báo qua Telegram/Slack Webhook cho Admin kiểm tra thủ công.

---

## 5. Triển Khai Web Admin trên GCP (Web Admin Deployment)

Web Admin được xây dựng trên React + Vite. Dưới đây là 3 phương án triển khai phổ biến từ dễ đến chuyên nghiệp.

> [!IMPORTANT]
> **Vấn đề định tuyến client-side (React Router Router Fallback)**:
> Vì React sử dụng định tuyến phía Client (Client-side routing), khi người dùng truy cập trực tiếp link con (ví dụ: `domain.com/nlu-ops`) hoặc nhấn F5 làm mới trang, máy chủ sẽ trả về lỗi **404 Not Found** do không tìm thấy file vật lý `/nlu-ops/index.html`. 
> Do đó, bất kể phương án triển khai nào, chúng ta bắt buộc phải cấu hình **Rewrite tất cả các request không phải file tĩnh về `index.html`**.

### Phương Án 1: Firebase Hosting (Khuyến nghị - Nhanh nhất & Miễn phí)
Firebase là một phần của GCP, cung cấp dịch vụ CDN toàn cầu và tự động cấp chứng chỉ SSL miễn phí.

1. **Chuẩn bị và cài đặt CLI**:
   ```powershell
   npm install -g firebase-tools
   firebase login
   ```
2. **Khởi tạo project**: Chạy lệnh sau tại thư mục `app/frontend/web-admin`:
   ```powershell
   firebase init hosting
   ```
   * *Chọn Project*: Chọn dự án GCP hiện tại của bạn.
   * *What do you want to use as your public directory?* Nhập `dist` (đây là thư mục build mặc định của Vite).
   * *Configure as a single-page app (rewrite all urls to /index.html)?* Chọn **Yes (y)** (Giúp xử lý lỗi 404 React Router).
   * *Set up automatic builds and deploys with GitHub?* Chọn No (hoặc Yes nếu muốn tích hợp CI/CD tự động).
3. **Biên dịch và Triển khai**:
   ```powershell
   npm run build
   firebase deploy --only hosting
   ```

---

### Phương Án 2: Google Cloud Storage (GCS) + HTTPS Load Balancing (Hiệu năng tối ưu)
Phương án này lưu file tĩnh trực tiếp trên Cloud Storage, sử dụng Cloud CDN để cache ở mép mạng gần người dùng nhất.

1. **Tạo Bucket lưu trữ**:
   - Tạo một Bucket trên GCP với tên trùng tên miền của bạn (ví dụ: `admin.spendingdiary.com`).
   - Cấp quyền đọc công khai cho mọi người: Thêm quyền `Storage Object Viewer` cho `allUsers`.
2. **Cấu hình Bucket thành Website tĩnh**:
   - Chạy lệnh CLI để thiết lập trang chủ và trang lỗi:
     ```powershell
     gcloud storage buckets update gs://admin.spendingdiary.com --web-main-page-suffix=index.html --web-error-page-suffix=index.html
     ```
     > [!TIP]
     > Bằng cách đặt `--web-error-page-suffix=index.html`, GCS sẽ tự động điều hướng tất cả các đường dẫn Router con không tồn tại về lại `index.html` của React, giải quyết triệt để lỗi 404 khi refresh trang.
3. **Upload mã nguồn**:
   - Biên dịch dự án: `npm run build`
   - Upload toàn bộ nội dung trong thư mục `dist` lên bucket:
     ```powershell
     gcloud storage cp -r dist/* gs://admin.spendingdiary.com/
     ```
4. **Cấu hình HTTPS**:
   - Dựng một **External Application Load Balancer** trên GCP.
   - Trỏ Backend Bucket vào Bucket GCS vừa tạo và kích hoạt **Cloud CDN** để tối ưu hóa tốc độ.
   - Cấu hình DNS miền trỏ về IP của Load Balancer, Google sẽ tự động cung cấp chứng chỉ SSL Managed miễn phí.

---

### Phương Án 3: Cloud Run + Docker Nginx (Đóng gói đồng nhất)
Nếu bạn muốn quản lý mọi dịch vụ (BE, AI, Admin) đồng nhất dưới dạng Docker Containers trên Cloud Run.

1. **Viết cấu hình Nginx** (`nginx.conf`) trong thư mục root của web-admin:
   ```nginx
   # nginx.conf
   server {
       listen 8080;
       server_name localhost;

       location / {
           root /usr/share/nginx/html;
           index index.html index.htm;
           try_files $uri $uri/ /index.html; # Khắc phục lỗi 404 React Router
       }

       # Cấu hình cache cho tệp tĩnh
       location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc)$ {
           root /usr/share/nginx/html;
           expires 1M;
           access_log off;
           add_header Cache-Control "public";
       }
   }
   ```
2. **Viết Dockerfile** trong thư mục root của web-admin:
   ```dockerfile
   # Dockerfile
   # Stage 1: Build ứng dụng React
   FROM node:20-alpine AS builder
   WORKDIR /app
   COPY package*.json ./
   RUN npm install
   COPY . .
   RUN npm run build

   # Stage 2: Serve bằng Nginx
   FROM nginx:alpine
   COPY --from=builder /app/dist /usr/share/nginx/html
   COPY nginx.conf /etc/nginx/conf.d/default.conf
   EXPOSE 8080
   CMD ["nginx", "-g", "daemon off;"]
   ```
3. **Build và Deploy lên Cloud Run**:
   ```powershell
   # 1. Build image trên Cloud Build và đẩy lên Artifact Registry
   gcloud builds submit --tag gcr.io/[PROJECT_ID]/web-admin:latest
   
   # 2. Deploy lên Cloud Run
   gcloud run deploy web-admin \
     --image gcr.io/[PROJECT_ID]/web-admin:latest \
     --platform managed \
     --region asia-east1 \
     --allow-unauthenticated \
     --port 8080
   ```

---

## 6. Cấu Hình Tên Miền (Custom Domains) & Chứng Chỉ Bảo Mật (SSL)

Khi đưa ứng dụng lên chạy chính thức (Production), chúng ta cần cấu hình hệ thống tên miền phụ (subdomains) để các dịch vụ giao tiếp trơn tru.

### 6.1. Thiết lập Cấu trúc Tên Miền Phân Bản (Subdomain Strategy)
* **Frontend Web App (Client)**: `https://spendingdiary.com` hoặc `https://app.spendingdiary.com`
* **Web Admin (Quản trị)**: `https://admin.spendingdiary.com`
* **Node.js Backend (API)**: `https://api.spendingdiary.com`
* **FastAPI AI Service**: `https://ai.internal.spendingdiary.com` (Hoặc gọi qua mạng nội bộ VPC của GCP thay vì public internet).

---

### 6.2. Hướng dẫn Trỏ Tên Miền và Cấp Phát SSL Tự Động (Free)

Tùy vào phương án triển khai ở **Mục 5**, cách trỏ DNS và nhận SSL sẽ khác nhau:

#### 1. Nếu dùng Firebase Hosting (Web Admin)
- Vào **Firebase Console** -> **Hosting** -> Nhấp nút **Connect Domain**.
- Điền tên miền của bạn (ví dụ: `admin.spendingdiary.com`).
- Firebase sẽ hiển thị 2 bản ghi cần cấu hình tại nhà đăng ký tên miền (Cloudflare, GoDaddy, Mắt Bão...):
  - **TXT Record**: Dùng để xác minh quyền sở hữu tên miền (Verification).
  - **A Record**: Trỏ IP của tên miền về cụm IP đích của Google CDN (ví dụ: `199.36.158.100`).
- **SSL/TLS**: Firebase tự động kích hoạt và gia hạn chứng chỉ bảo mật của **Let's Encrypt** hoàn toàn miễn phí. Quá trình kích hoạt mất từ 1 giờ - 24 giờ sau khi trỏ DNS thành công.

#### 2. Nếu dùng Cloud Run (Node.js Backend & Web Admin Option 3)
* **Cách 1: Custom domain mapping trực tiếp (Đơn giản nhất)**:
  - Vào GCP Console -> **Cloud Run** -> Chọn service cần map (ví dụ: `web-admin` hoặc `backend`).
  - Chọn tab **Integrations** hoặc click **Manage Custom Domains** ở thanh trên cùng.
  - Nhấp **Add Mapping**, điền tên miền (`api.spendingdiary.com`).
  - Lấy bản ghi **CNAME** mà Google cung cấp (ví dụ: `ghs.googlehosted.com.`) trỏ tại DNS của bạn.
  - GCP tự động cấp chứng chỉ SSL miễn phí thông qua CA của Google.
* **Cách 2: Thông qua HTTPS Load Balancer (Chuyên nghiệp & Bảo mật)**:
  - Định cấu hình **Serverless Network Endpoint Groups (NEGs)** để kết nối Cloud Run với Load Balancer.
  - Tạo một **Google-managed SSL Certificate** trên Load Balancer.
  - Trỏ bản ghi **A Record** của tên miền phụ (`api.spendingdiary.com`) về IP WAN tĩnh của Load Balancer. Chứng chỉ SSL sẽ tự động chuyển sang trạng thái Active sau 30 phút.

---

### 6.3. Quy Tắc Chia Sẻ Cookie & Tránh Lỗi Phân Quyền CORS chéo Subdomain

Do frontend Web Admin chạy trên `admin.spendingdiary.com` và Node.js Backend chạy trên `api.spendingdiary.com`, chúng được coi là hai nguồn khác nhau (**Cross-Origin**).

#### 1. Cấu hình CORS ở Node.js Backend:
Trong file cấu hình CORS của Backend, bắt buộc phải khai báo nguồn tin cậy và cho phép truyền cookie/chứng thực:
```javascript
// app/backend/src/app.js hoặc config/cors.js
const corsOptions = {
  origin: [
    'https://spendingdiary.com',
    'https://admin.spendingdiary.com',
    'http://localhost:5173' // Dành cho dev cục bộ
  ],
  credentials: true, // Bắt buộc để truyền cookie
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};
app.use(cors(corsOptions));
```

#### 2. Cấu hình Cookie Phiên Làm Việc (Session Cookies):
Khi ghi token (JWT) vào Cookie từ Backend, để trình duyệt trên tên miền `admin.spendingdiary.com` có thể nhận và gửi ngược lại lên `api.spendingdiary.com`, cấu hình cookie phải sử dụng domain dùng chung:
```javascript
res.cookie('token', jwtToken, {
  httpOnly: true,
  secure: true,                // Bắt buộc trên môi trường GCP (chạy HTTPS)
  sameSite: 'lax',             // Cho phép cookie truyền chéo subdomain qua liên kết điều hướng
  domain: '.spendingdiary.com',// Dấu chấm đầu giúp cookie được chia sẻ giữa api, admin, và root domain
  maxAge: 7 * 24 * 60 * 60 * 1000 // 7 ngày
});
```
> [!WARNING]
> Nếu bạn đặt `domain: 'api.spendingdiary.com'` (không có dấu chấm và chỉ định đích danh API), trình duyệt của Web Admin (`admin.spendingdiary.com`) sẽ từ chối lưu trữ và không gửi cookie này đi trong các request tiếp theo, khiến Admin luôn bị lỗi chưa đăng nhập (Unauthorized).

---

### 6.4. Quy Trình Cấu Hình Sử Dụng Tên Miền Miễn Phí của Google (Lựa chọn tối ưu cho Luận văn)

Nếu bạn không muốn tốn chi phí mua tên miền và muốn tận dụng các tên miền mặc định do Google cấp, hãy thực hiện theo quy trình liên kết chéo 4 bước sau:

#### Bước 1: Deploy Node.js Backend lên Cloud Run trước để lấy API URL
* Deploy dịch vụ backend của bạn lên Cloud Run.
* Google sẽ cấp cho bạn một endpoint HTTPS cố định miễn phí, ví dụ:
  `https://spendingdiary-backend-123456-as.a.run.app`

#### Bước 2: Biên dịch Web Admin tĩnh trỏ về API URL đó
* Trước khi chạy build trên Web Admin, bạn phải cập nhật biến môi trường chỉ hướng API của React trỏ sang URL Backend vừa nhận được ở Bước 1.
* Chạy lệnh build tại thư mục `app/frontend/web-admin`:
  ```powershell
  # Windows Powershell
  $env:VITE_API_BASE_URL="https://spendingdiary-backend-123456-as.a.run.app"
  npm run build
  ```
  *(Thư mục `dist` được tạo ra lúc này sẽ chứa toàn bộ mã nguồn React được biên dịch cứng địa chỉ backend Cloud Run)*.

#### Bước 3: Triển khai Frontend lên Firebase Hosting để nhận Admin URL
* Chạy lệnh deploy:
  ```powershell
  firebase deploy --only hosting
  ```
* Firebase sẽ cấp cho bạn URL Admin miễn phí, ví dụ:
  `https://spendingdiary-admin.web.app`

#### Bước 4: Thiết lập biến môi trường CORS_ORIGINS trên Cloud Run Backend
* Do Web Admin (`.web.app`) và Cloud Run Backend (`.a.run.app`) là **2 tên miền hoàn toàn khác biệt**, trình duyệt sẽ chặn cuộc gọi API nếu không được cấu hình CORS.
* Lên **Google Cloud Console** -> **Cloud Run** -> Chọn service Backend -> Chọn **Edit & Deploy New Revision**.
* Trong mục **Variables** (Biến môi trường), thêm/cập nhật biến `CORS_ORIGINS` chứa URL Admin nhận được ở Bước 3:
  ```bash
  CORS_ORIGINS=https://spendingdiary-admin.web.app,https://spendingdiary-admin.firebaseapp.com
  ```
* Bấm **Deploy**. Lúc này, Web Admin đã có thể gọi API Backend ngầm thành công mà không gặp bất kỳ lỗi bảo mật CORS nào của trình duyệt.

---

## 7. Khảo Sát: Có Nên Chuyển Retrain (NLU & PICK KIE) Từ Kaggle Về GCP VM?

Dưới đây là phân tích chi tiết về việc giữ nguyên cơ chế retrain hiện tại hay chuyển dịch toàn bộ về chạy trên máy ảo (VM) của Google Cloud.

### 7.1. Phân loại hai tác vụ huấn luyện
1. **Huấn luyện NLU (Local VM)**:
   - *Đặc điểm*: Các mô hình NLU (Intent, Category, Record Type) sử dụng học máy truyền thống (TF-IDF, SVM, Logistic Regression) có kích thước dữ liệu huấn luyện rất nhỏ (vài nghìn mẫu).
   - *Thời gian chạy*: Chạy trên CPU thông thường chỉ mất **3 đến 15 giây** để hoàn thành qua script `retrain_all.py`.
   - *Khuyến nghị*: **NÊN chạy trực tiếp trên VM / Container** của AI Service. Không cần GPU hay bên thứ ba.
2. **Huấn luyện KIE PICK (Deep Learning)**:
   - *Đặc điểm*: Mô hình Graph Transformer kết hợp tích hợp giữa văn bản, vị trí (Layout) và đồ thị cấu trúc (PICK KIE). Yêu cầu tài nguyên tính toán lớn (GPU VRAM >= 16GB).
   - *Thời gian chạy*: Từ **30 phút đến vài giờ** tùy theo dung lượng dataset hóa đơn được duyệt.

---

### 7.2. So sánh chi tiết các phương án huấn luyện PICK KIE

| Tiêu chí | Sử dụng Kaggle API (Hiện tại) | Tự chạy trên GCP VM có GPU |
| :--- | :--- | :--- |
| **Chi phí phần cứng** | **Hoàn toàn miễn phí** (Kaggle tặng 30 giờ GPU NVIDIA T4 hàng tuần). | **Rất đắt đỏ** (Mướn VM GPU L4/T4 chạy liên tục tiêu tốn khoảng $100 - $200+ / tháng). |
| **Bảo mật dữ liệu** | **Trung bình** (Ảnh hóa đơn và nhãn phải được đóng gói tải lên Kaggle dưới dạng dataset). | **Tuyệt đối** (Dữ liệu không rời khỏi mạng nội bộ VPC của doanh nghiệp). |
| **Độ trễ kích hoạt** | **Chậm** (Mất 5-10 phút để Kaggle khởi tạo môi trường kernel, xếp hàng và bắt đầu chạy). | **Nhanh** (Worker cục bộ nhận lệnh là chạy ngay lập tức). |
| **Độ phức tạp DevOps** | **Thấp** (Chỉ cần setup Kaggle API Token và gọi API trigger kernel có sẵn). | **Rất cao** (Cần viết script tự khởi động VM GPU khi cần huấn luyện, chạy xong tự tắt VM để tránh phát sinh chi phí). |

---

### 7.3. Đề xuất phương án thực hiện

#### 1. Dành cho Luận văn Tốt nghiệp / Dự án Demo (Khuyến nghị):
> [!IMPORTANT]
> **Giữ nguyên cơ cấu kết hợp (NLU chạy VM - PICK KIE chạy Kaggle)**:
> - Tận dụng tối đa tài nguyên miễn phí của Kaggle để tiết kiệm chi phí cá nhân.
> - Sử dụng tài khoản Kaggle của riêng bạn làm backend tính toán ngầm, người dùng Web Admin vẫn ấn nút và nhận kết quả bình thường mà không hề biết quá trình đó đang chạy nhờ Kaggle.

#### 2. Dành cho hệ thống Doanh nghiệp / Thương mại thực tế:
> [!IMPORTANT]
> **Chuyển hoàn toàn về Google Cloud (sử dụng VM GPU Spot hoặc Vertex AI)**:
> - Vì dữ liệu hóa đơn của khách hàng chứa thông tin nhạy cảm (Tên, địa chỉ, số điện thoại, giá tiền), doanh nghiệp không được phép đẩy dữ liệu ra bên ngoài như Kaggle.
> - **Cách triển khai tối ưu chi phí trên GCP**:
>   1. Tạo một máy ảo VM chạy GPU ở chế độ **Spot VM** (GCP giảm giá tới 70% đối với VM có thể bị thu hồi).
>   2. Khi Admin bấm nút Retrain trên Web Admin, Node.js gọi GCP API để bật máy ảo GPU lên (`gcloud compute instances start`).
>   3. Máy ảo GPU khởi động, chạy script train, lưu file model mới vào Google Cloud Storage (GCS).
>   4. Chạy xong, script gửi webhook báo thành công cho Backend và tự động tắt máy ảo (`sudo poweroff`) để dừng tính tiền.

---

### 7.4. Kiến Trúc 2 Máy Ảo (2 VMs): Tách Biệt Serving Và Training (Chuẩn Sản Xuất)

Để đảm bảo hệ thống hoạt động liên tục không bị gián đoạn, việc phân tách thành **2 máy ảo (VM)** riêng biệt là giải pháp tối ưu và là tiêu chuẩn thiết kế hệ thống AI trong thực tế:

```mermaid
graph TD
    subgraph GCP VPC Network
        subgraph Serving VM (VM 1 - Chạy 24/7)
            AI[ai-service / inference] -- 5. Reload Model --> W[Model Weights]
        end
        
        subgraph Training VM (VM 2 - Chỉ bật khi train)
            T[retrain script / PyTorch] -- 3. Export weights --> GCS[(Cloud Storage)]
        end
    end
    
    Admin[Web Admin Client] -- 1. Trigger Retrain --> BE[Backend Cloud Run]
    BE -- 2. Start VM (GCP API) --> VM2[Start VM 2]
    GCS -- 4. Webhook Notify --> BE
    BE -- 4.1. Download Weight Command --> AI
```

#### 1. Máy ảo 1: Serving VM (Máy chủ phục vụ - Chạy 24/7)
* **Cấu hình đề xuất**: `n1-standard-2` hoặc `n1-standard-4` có gắn 1 **GPU NVIDIA T4 (16GB)** hoặc tối ưu hóa chạy hoàn toàn trên CPU bằng **ONNX Runtime**.
* **Nhiệm vụ**: Nhận ảnh hóa đơn từ người dùng, chạy OCR, KIE (PICK) và trả kết quả NLU/Story ngay lập tức.
* **Tại sao không nên train trên máy này?**
  - Quá trình huấn luyện lại (Retrain PICK KIE) sẽ chiếm dụng **100% CPU và VRAM GPU** trong vài giờ liên tục.
  - Nếu chạy chung, người dùng chụp ảnh hóa đơn gửi lên sẽ bị **lỗi 504 Timeout** hoặc ứng dụng ai-service bị crash hoàn toàn vì lỗi thiếu bộ nhớ (Out of Memory).

#### 2. Máy ảo 2: Training VM (Máy chủ huấn luyện - Chỉ bật khi có yêu cầu)
* **Cấu hình đề xuất**: `g2-standard-4` gắn **GPU NVIDIA L4 (24GB)** hoặc máy ảo GPU mạnh hơn để tăng tốc độ train.
* **Trạng thái mặc định**: **Tắt (Stopped)** để không phát sinh chi phí.
* **Quy trình hoạt động phối hợp**:
  1. Admin bấm nút "Huấn luyện lại" trên Web Admin.
  2. Node.js Backend gọi API của GCP để kích hoạt bật máy ảo VM 2 lên.
  3. VM 2 khởi động tự động, kéo tập dữ liệu huấn luyện mới nhất từ GCS/Database về, chạy script huấn luyện.
  4. Sau khi hoàn thành, VM 2 đẩy file weights mới (`model_best.pth`) lên bucket GCS và gửi một webhook báo hoàn tất cho Backend Node.js.
  5. Script trên VM 2 tự động gọi lệnh shutdown hệ điều hành (`sudo poweroff`) để tắt máy ảo ngay lập tức.
  6. Backend Node.js gửi lệnh thông báo cho **Serving VM (VM 1)** tải file weights mới từ GCS về và kích hoạt cơ chế nạp nóng (hot-reload) mô hình mới mà không cần restart service (không gây downtime cho người dùng).

