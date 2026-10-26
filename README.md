# 📱 Quản Lý Chi Tiêu Cá Nhân (Personal Expense Tracker)

Ứng dụng quản lý thu chi cá nhân hiện đại, tốc độ cao, hoạt động **100% ngoại tuyến (Offline-First)** được xây dựng bằng **Flutter**, **SQLite** và **Riverpod**.

---

## 🌟 Tính Năng Nổi Bật (Key Features)

- ⚡ **Nhập liệu thần tốc (< 3 giây)**: Form thêm giao dịch thông minh với các phím tắt cộng tiền nhanh (`+10k`, `+50k`, `+100k`, `+500k`, `+1Tr`).
- 💵 **Tổng quan tài chính tức thì**: Theo dõi Số dư khả dụng, Tổng thu nhập và Tổng chi tiêu theo từng tháng ngay tại Trang chủ.
- 🗂️ **Hệ thống danh mục trực quan**: Bộ danh mục chuẩn đời sống Việt Nam (Ăn uống 🍜, Di chuyển 🛵, Hóa đơn 🏠, Lương 💼, Đầu tư 📈...) kèm mã màu và icon riêng biệt.
- 🔍 **Lịch sử & Bộ lọc đa năng**: Lọc linh hoạt theo mốc thời gian (Tháng này, Tháng trước, Tùy chọn ngày), theo Danh mục hoặc theo Loại giao dịch (Chỉ thu / Chỉ chi).
- 🎯 **Quản lý Ngân sách & Cảnh báo**: Thiết lập hạn mức chi tiêu cho từng danh mục hoặc cả tháng. Tự động đổi màu cảnh báo trực quan:
  - 🟢 **An toàn (< 70%)**: Kiểm soát tốt chi tiêu.
  - 🟡 **Cảnh báo (70% - 90%)**: Tiệm cận hạn mức ngân sách.
  - 🔴 **Báo động (> 90% hoặc quá 100%)**: Cảnh báo nguy cơ bội chi.
- 📊 **Biểu đồ thống kê thông minh (`fl_chart`)**:
  - **Biểu đồ tròn Donut**: Phân tích cơ cấu chi tiêu theo danh mục, hỗ trợ chạm phóng to lát cắt và thẻ chú giải xếp hạng.
  - **Biểu đồ cột đôi**: So sánh biến động Thu - Chi qua các tháng giúp theo dõi xu hướng tiết kiệm.
- 🚀 **Tối ưu hóa hiệu năng cực cao (Zero-Jank / 60-120 FPS)**:
  - Tầng SQLite được đánh chỉ mục (**INDEX**) trên các trường `date`, `category_id`, `type`.
  - Tính toán số dư và tổng hợp trực tiếp bằng các câu lệnh SQL Aggregate (`SUM()`, `GROUP BY`) ở tầng C engine, không tính trong vòng lặp Dart.
  - Sử dụng Riverpod quản lý state phân mảnh mịn, chỉ render lại đúng widget cần cập nhật.
- 🔒 **Bảo mật & Quyền riêng tư**: 100% dữ liệu tài chính được lưu trữ cục bộ trong thiết bị qua SQLite, không gửi dữ liệu ra ngoài Internet.

---

## 🛠️ Công Nghệ Sử Dụng (Tech Stack)

| Công nghệ | Vai trò |
| :--- | :--- |
| **Flutter & Dart** | Nền tảng phát triển ứng dụng di động đa nền tảng |
| **SQLite (`sqflite`)** | Cơ sở dữ liệu quan hệ cục bộ, truy vấn tốc độ cao |
| **Flutter Riverpod** | Quản lý trạng thái (State Management) reactive và testable |
| **`fl_chart`** | Thư viện biểu đồ tài chính tương tác cao (Donut & Bar chart) |
| **`intl`** | Định dạng tiền tệ VND (`150.000 ₫`) và ngày tháng tiếng Việt |
| **`uuid`** | Định danh UUID v4 duy nhất cho các bản ghi |

---

## 📂 Cấu Trúc Thư Mục (Project Structure)

```
lib/
├── core/
│   ├── database/          # SQLite Database helper & migrations
│   ├── theme/             # Material 3 Theme (Màu sắc, Dark/Light mode)
│   └── utils/             # Format tiền tệ VND và ngày tháng
├── data/
│   ├── models/            # Category, Transaction, Budget models
│   └── repositories/      # SQLite CRUD & Aggregate queries
├── presentation/
│   ├── providers/         # Riverpod State Notifiers & Providers
│   └── screens/
│       ├── home/          # Trang chủ Dashboard & Thẻ số dư
│       ├── history/       # Lịch sử & Bộ lọc giao dịch
│       ├── transaction_form/ # Thêm / Sửa giao dịch nhanh
│       ├── budget/        # Quản lý hạn mức ngân sách & cảnh báo
│       ├── statistics/    # Báo cáo biểu đồ Donut & Bar chart
│       └── main_screen.dart # Thanh điều hướng chính (Bottom Navigation)
└── main.dart
```

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy (Getting Started)

### Yêu cầu tiên quyết
- Đã cài đặt Flutter SDK (khuyến nghị Flutter 3.19+ / Dart 3.3+).
- Thiết bị giả lập (Android Emulator / iOS Simulator) hoặc máy thật / Windows Desktop.

### Các bước thực hiện

1. **Clone repository về máy:**
   ```bash
   git clone https://github.com/username/personal_expense_tracker.git
   cd personal_expense_tracker
   ```

2. **Cài đặt các gói phụ thuộc:**
   ```bash
   flutter pub get
   ```

3. **Chạy ứng dụng:**
   ```bash
   flutter run
   ```

---

## 📝 Giấy Phép (License)

Dự án này được phát hành dưới giấy phép [MIT License](LICENSE).
