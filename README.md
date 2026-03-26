# <p align="center"><img src="assets/images/grillpos/logo_full.png" alt="GrillPOS Logo" width="400"></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.6.1-02569B?logo=flutter&logoColor=white" alt="Flutter Badge">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart Badge">
  <img src="https://img.shields.io/badge/SQLite-Offline--First-003B57?logo=sqlite&logoColor=white" alt="SQLite Badge">
  <img src="https://img.shields.io/badge/Platform-Windows%20|%20Android%20|%20iOS-orange?style=flat-square" alt="Platform Badge">
  <img src="https://img.shields.io/badge/SaaS-Ready-green?style=flat-square" alt="SaaS Badge">
</p>

---

**GrillPOS** is a high-performance, modern SaaS-ready Point of Sale system specifically tailored for grill restaurants and high-traffic food establishments. Built with Flutter, it offers a seamless, premium experience across desktop and mobile devices with a focus on speed, reliability, and rich aesthetics.

## ✨ Key Features

### 🏢 Advanced Point of Sale
*   **Intuitive Interface**: Large, touch-friendly food cards with quick-action buttons.
*   **Dynamic Filtering**: Smooth horizontal category scrolling with full mouse and touch support.
*   **Real-time Cart**: Instant subtotal calculations, tax handling, and weight-based quantity support (e.g., 0.5kg).
*   **Arabic/English Support**: Full RTL (Right-to-Left) support with localized category and item management.

### 📊 Powerful Dashboard & Business Intelligence
*   **Pinned Summaries**: Fixed statistics cards (Revenue, Orders, Occupancy) that stay in view while scrolling through recent operations.
*   **Responsive Layout**: Adaptive 4-column grid for desktop views, optimized for 1080p and higher resolutions.
*   **Advanced Analytics**: Visualize sales trends, top-selling items, and peak hours using interactive `FL Charts`.
*   **Custom Reporting**: Powerful date-range filtering with a premium, rounded modal interface.

### 🪑 Table & Order Management
*   **Visual Table Grid**: Real-time status monitoring (Available, Occupied, Reserved, Cleaning).
*   **Order Lifecycle**: Track orders from "Pending" to "Served" and "Completed".
*   **Localized Table ID**: Unified Arabic labeling ("طاولة") across the system.

### 🛠️ Technical Excellence
*   **Architecture**: Robust implementation using **BLoC/Cubit** for state management and **GetIt** for dependency injection.
*   **Offline-First**: Reliable SQLite persistence ensuring your business never stops, even without internet.
*   **Clean Code**: Decoupled features following standard Clean Architecture patterns.
*   **SaaS Ready**: Designed with multi-tenancy and restaurant ID isolation in mind.

---

## 🎨 Professional Aesthetics

GrillPOS isn't just a tool; it's a visual statement.
*   **Dark Mode**: Sleek Charcoal and Surface Dark themes for eye-comfort in low-light restaurant environments.
*   **Vibrant Branding**: Warm Orange and Ember accents that reflect the energy of a grill-based kitchen.
*   **Micro-animations**: Smooth transitions and hover effects for a premium software feel.

---

## 🚀 Tech Stack

*   **Framework**: [Flutter](https://flutter.dev) (Desktop & Mobile)
*   **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc)
*   **Database**: [SQLite](https://www.sqlite.org) (via `sqflite_common_ffi`)
*   **UI Icons**: [Lucide Icons](https://lucideicons.com)
*   **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
*   **PDF/Printing**: [pdf](https://pub.dev/packages/pdf) & [printing](https://pub.dev/packages/printing)

---

## 📂 Project Structure

```text
lib/
├── core/
│   ├── components/       # Reusable UI widgets (Stat Cards, Headers, etc.)
│   ├── constants/        # Design system tokens (Colors, Spacing)
│   ├── data/             # Core services (SQLite, Persistence)
│   └── di/               # Dependency Injection setup
├── features/
│   ├── dashboard/        # Pinned stats & recent operations
│   ├── pos/             # Core sales interface
│   ├── menu/            # Localized category & item control
│   ├── reports/         # BI tools & custom date filtering
│   └── orders/          # Lifecycle tracking
└── main.dart
```

---

## ⚙️ Installation & Development

### Prerequisites
*   Flutter SDK (^3.6.1)
*   Desktop development tools for Windows/macOS/Linux
*   SQLite library installed on the target system

### Run Locally
```bash
# Clone the repository
git clone https://github.com/yourusername/grill_pos.git

# Install dependencies
flutter pub get

# Run the app
flutter run -d windows # or android/ios
```

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#top">back to top</a>)</p>
