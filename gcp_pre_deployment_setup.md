# Hướng Dẫn Cấu Hình Google Cloud Platform (GCP) Trước Khi Triển Khai

Tài liệu này hướng dẫn chi tiết các bước chuẩn bị tài nguyên, kích hoạt dịch vụ, cấu hình bảo mật IAM và hạ tầng mạng VPC trên Google Cloud Platform (GCP) trước khi bắt đầu deploy hệ thống Spending Diary.

---

## 1. Các Dịch Vụ GCP Cần Kích Hoạt (Enabling APIs)

Trước tiên, cần truy cập **GCP Console** -> **API & Services** -> **Library** và kích hoạt các API sau:

| Tên dịch vụ | Tên API định danh (CLI) | Mục đích sử dụng |
| :--- | :--- | :--- |
| **Compute Engine** | `compute.googleapis.com` | Chạy máy ảo Serving VM (AI Service) và Training VM |
| **Cloud Run** | `run.googleapis.com` | Chạy Node.js Backend dạng Serverless container |
| **Secret Manager** | `secretmanager.googleapis.com` | Quản lý API Key, mật khẩu DB bảo mật |
| **Cloud SQL Admin** | `sqladmin.googleapis.com` | Quản lý database PostgreSQL |
| **Google Cloud Storage** | `storage.googleapis.com` | Lưu trữ ảnh hóa đơn thô và tệp weights mô hình |
| **Serverless VPC Access** | `vpcaccess.googleapis.com` | Cho phép Cloud Run giao tiếp nội bộ với DB/Redis trong VPC |
| **Memorystore for Redis** | `redis.googleapis.com` | Quản lý Cache và Hàng đợi (Message Queue) |

* **Lệnh kích hoạt nhanh bằng gcloud CLI**:
  ```bash
  gcloud services enable \
    compute.googleapis.com \
    run.googleapis.com \
    secretmanager.googleapis.com \
    sqladmin.googleapis.com \
    storage.googleapis.com \
    vpcaccess.googleapis.com \
    redis.googleapis.com
  ```

---

## 2. Cấu Hình IAM & Service Accounts (Phân Quyền Bảo Mật)

Áp dụng nguyên tắc quyền hạn tối thiểu (Principle of Least Privilege) bằng cách tạo 2 Service Account riêng biệt cho Backend và AI Service:

### 2.1. Service Account cho Node.js Backend (`spending-diary-backend-sa`)
1. **Tạo tài khoản**:
   - Truy cập **IAM & Admin** -> **Service Accounts** -> Chọn **Create Service Account**.
   - Đặt tên: `spending-diary-backend-sa`.
2. **Gán các Role sau**:
   - `Secret Manager Secret Accessor` (`roles/secretmanager.secretAccessor`): Đọc password DB, Gemini API Key từ Secret Manager.
   - `Cloud SQL Client` (`roles/cloudsql.client`): Kết nối bảo mật vào PostgreSQL.
   - `Storage Object Admin` (`roles/storage.objectAdmin`): Upload và xóa ảnh hóa đơn của người dùng trên Cloud Storage Bucket.

### 2.2. Service Account cho AI Service (`spending-diary-ai-sa`)
1. **Tạo tài khoản**:
   - Đặt tên: `spending-diary-ai-sa`.
2. **Gán các Role sau**:
   - `Secret Manager Secret Accessor` (`roles/secretmanager.secretAccessor`): Đọc Kaggle API Key.
   - `Storage Object Viewer` (`roles/storage.objectViewer`): Tải file weights mô hình từ Storage Bucket khi khởi động.
   - `Compute Instance Admin` (Chỉ cần nếu dùng mô hình Tự động Bật/Tắt VM 2 ở VM 1): Cho phép bật/tắt VM huấn luyện.

---

## 3. Thiết Lập Hạ Tầng Mạng VPC (Virtual Private Cloud)

Để đảm bảo an toàn thông tin, toàn bộ dữ liệu giao dịch và giao tiếp giữa Backend, AI VM, Database, Cache phải diễn ra trong mạng nội bộ VPC, không công khai ra ngoài internet.

```mermaid
graph LR
    subgraph Internet Public
        User[Mobile Client / Web Admin]
    end
    
    subgraph VPC Network (10.0.0.0/16)
        subgraph Public Subnet
            CR[Cloud Run Backend]
        end
        subgraph Private Subnet
            VM1[Serving VM: AI Service]
            DB[(Cloud SQL: Postgres)]
            Redis[(Memorystore: Redis)]
        end
        
        VPC_Conn[Serverless VPC Connector] <--> CR
    end
    
    User -- HTTPS --> CR
    CR -- Internal IP --> VM1
    CR -- Private Service Connect --> DB
    CR -- Internal IP --> Redis
```

### 3.1. Tạo VPC Network & Subnets
- Tạo một VPC network tên `spending-diary-vpc` với chế độ Custom subnet.
- Tạo subnet:
  - `subnet-serving` (Region: `asia-east1`, dải IP: `10.0.1.0/24`) cho Serving VM.
  - `subnet-db` (Region: `asia-east1`, dải IP: `10.0.2.0/24`) cho Cloud SQL.

### 3.2. Cấu hình Serverless VPC Access Connector
Dịch vụ Cloud Run chạy serverless cần một VPC Connector để chọc vào mạng nội bộ:
- Truy cập **Serverless VPC access** -> **Create Connector**.
- Đặt tên: `vpc-run-connector`.
- Region: `asia-east1`.
- Network: `spending-diary-vpc`.
- Dải IP dành riêng cho Connector: `10.8.0.0/28` (không được trùng với các dải subnet hiện có).

### 3.3. Private Services Access cho Cloud SQL & Redis
- Vào **VPC Network** -> **Private Service Connection**.
- Chọn **Allocate IP Range** -> Tạo dải `10.10.0.0/16` dành cho các dịch vụ Google Managed.
- Bấm **Create Connection** -> Liên kết dải này với dịch vụ Cloud SQL và Redis. Khi đó, database PostgreSQL và Redis sẽ nhận IP nội bộ (ví dụ: `10.10.0.5`) giúp Backend kết nối trực tiếp không qua IP Public.

---

## 4. Cấu Hình Máy Chủ Compute Engine (Serving VM / Training VM)

### 4.1. Máy ảo 1: Serving VM (Inference - Chạy 24/7)
* **Cấu hình**: `g2-standard-4` (4 vCPUs, 16GB RAM) kèm **1 GPU NVIDIA L4** (nếu chạy real OCR) hoặc `e2-standard-2` (2 vCPUs, 8GB RAM) chạy CPU hoàn toàn (nếu biên dịch ONNX / chạy mock fallback).
* **Mạng**: 
  - Gán vào Subnet `subnet-serving` của `spending-diary-vpc`.
  - **Tắt External IP** (Ephemeral -> None) để tránh hacker tấn công trực tiếp. Chỉ cho phép nhận request nội bộ từ Cloud Run Backend thông qua IP nội bộ `10.0.1.x`.
* **Firewall Rules**:
  - Tạo Firewall rule `allow-backend-to-ai`: Cho phép cổng `8000` (FastAPI) nhận các gói tin từ IP của VPC Connector (`10.8.0.0/28`) và Subnet Backend.

### 4.2. Máy ảo 2: Training VM (Spot VM - Chỉ bật khi huấn luyện)
* **Cấu hình**: `g2-standard-4` kèm **1 GPU NVIDIA L4 (24GB VRAM)**.
* **Spot VM (Preemptible)**: Kích hoạt chế độ Spot trong mục *VM Provisioning Model*. Giá Spot VM rẻ hơn 70-80% so với thông thường.
* **Mạng**: Gán vào subnet `subnet-serving` không có IP Public. Kết nối ra internet để tải thư viện qua **Cloud NAT** của VPC.

---

## 5. Cài Đặt Cloud Run (Node.js Backend)

Khi deploy Node.js Backend lên Cloud Run, hãy thiết lập các cấu hình tối ưu sau:

1. **Kết nối mạng (Networking)**:
   - Trong mục **VPC Connection** -> Chọn **Route all traffic through the VPC connector** và chọn `vpc-run-connector`. Điều này buộc mọi cuộc gọi đến Database, Redis và AI Service phải đi qua đường ống nội bộ an toàn.
2. **Bộ nhớ và RAM**:
   - Đặt dung lượng tối thiểu 1 vCPU và 512MB RAM.
   - Bật giới hạn số lượng instance (ví dụ: Min: 0, Max: 10) để kiểm soát chi phí.
3. **Liên kết Secret Manager**:
   - Thay vì truyền mật khẩu và API Key dạng văn bản thường trong tab Environment Variables, hãy chọn **Reference a Secret** từ Secret Manager:
     - `DATABASE_URL` -> Tham chiếu tới secret `PG_DB_URL`.
     - `GEMINI_API_KEY` -> Tham chiếu tới secret `GEMINI_KEY`.
     - `KAGGLE_KEY` -> Tham chiếu tới secret `KAGGLE_KEY`.
