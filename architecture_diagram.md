# Sơ đồ Kiến trúc Hệ thống 4 Tầng

Sơ đồ kiến trúc được thiết kế theo dạng phân tầng (Top-Down) để thể hiện rõ luồng dữ liệu từ người dùng qua Client, Backend và tới các dịch vụ lưu trữ cùng AI.

```mermaid
flowchart TD
    %% Định nghĩa các lớp màu sắc để sơ đồ đẹp hơn
    classDef actor fill:#ffffff,stroke:#cccccc,color:#000000,font-weight:bold
    classDef client fill:#e3f2fd,stroke:#1e88e5,stroke-width:2px,color:#0d47a1,font-weight:bold
    classDef backend fill:#e8f5e9,stroke:#43a047,stroke-width:2px,color:#1b5e20,font-weight:bold
    classDef ai fill:#fff8e1,stroke:#ffb300,stroke-width:2px,color:#ff6f00,font-weight:bold
    classDef db fill:#fce4ec,stroke:#d81b60,stroke-width:2px,color:#880e4f,font-weight:bold

    subgraph Tầng_Người_Dùng [Tầng Người Dùng]
        direction LR
        User_Mobile["👤 Người dùng di động\n(Users)"]:::actor
        User_Admin["👥 Quản trị viên\n(Admin)"]:::actor
    end

    subgraph Tầng_Client [Tầng Client]
        direction LR
        App["📱 Ứng dụng di động\n[Flutter]"]:::client
        Web["💻 Cổng quản trị Web\n[React]"]:::client
    end

    subgraph Tầng_Backend [Tầng Backend]
        API["⚙️ Máy chủ trung tâm\n[Node.js + Socket.io]"]:::backend
    end

    subgraph Tầng_Dich_Vu_Va_Luu_Tru [Tầng Dịch Vụ & Lưu Trữ]
        direction LR
        subgraph Dịch_Vụ_AI [Cụm Dịch vụ AI]
            direction TB
            Modal["☁️ Modal Server\n[FastAPI]"]:::ai
            OCR["👁️ Dịch vụ OCR"]:::ai
            NLU["🧠 Dịch vụ NLU"]:::ai
            Modal --- OCR
            Modal --- NLU
        end
        DB["🗄️ Cơ sở dữ liệu\n[CockroachDB]"]:::db
    end

    %% ---- CÁC LUỒNG KẾT NỐI ----
    User_Mobile <-->|"Ghi chép, quét hóa đơn\n& Nhận kết quả"| App
    User_Admin <-->|"Kiểm duyệt, theo dõi\n& Xem báo cáo"| Web

    App <-->|"Yêu cầu & Phản hồi (API)"| API
    Web <-->|"Yêu cầu & Phản hồi (API)"| API

    API <-->|"Gửi dữ liệu\nNhận kết quả bóc tách"| Modal
    API <-->|"Truy vấn & Lưu trữ\ndữ liệu giao dịch"| DB
```

### Cách sử dụng
Bạn copy đoạn code bên trong và dán vào [Mermaid Live Editor](https://mermaid.live/) để xuất ra ảnh. Bố cục này đã giống y đúc sơ đồ ảnh cũ của bạn!
