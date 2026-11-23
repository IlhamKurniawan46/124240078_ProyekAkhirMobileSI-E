# HoloDex v2 (Edisi Praktikum) — Katalog Pokémon TCG & Marketplace Kolektor P2P (Rekber COD)

[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.1%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Local Storage](https://img.shields.io/badge/Database-100%25%20Hive%20(10%20Boxes)-FFA000?logo=databricks&logoColor=white)](#-arsitektur-penyimpanan-lokal-10-hive-box)
[![State Management](https://img.shields.io/badge/State-StatefulWidget%20%2B%20setState-02569B?logo=flutter&logoColor=white)](#-peta-modul-praktikum-ke-fitur--file-kode)

**HoloDex v2 (Edisi Praktikum)** adalah aplikasi mobile berbasis Flutter untuk kolektor kartu Pokémon TCG di Indonesia yang mengintegrasikan katalog kartu multi-set berharga internasional, konverter kurs 4 mata uang real-time, simulasi efek kartu holografik 3D berbasis sensor gyroscope, pengingat rilis set & turnamen, serta marketplace *peer-to-peer* (P2P) dengan mekanisme **Rekber COD (Escrow 72 Jam)** dan **Peta Penjual Terdekat (LBS OpenStreetMap)**.

Proyek ini dirancang khusus sebagai **Proyek Akhir Praktikum Pemrograman Aplikasi Mobile** yang memenuhi seluruh ketentuan **Modul 1 s/d Modul 8 + LBS**, dengan arsitektur **100% Local Storage menggunakan Hive**, **State Management bawaan Flutter (`StatefulWidget` + `setState()`)**, dan **Navigasi Imperatif bawaan Flutter (`Navigator.push` / `pop`)** — **tanpa perlu konfigurasi `.env` atau server eksternal**.

---

## 📑 Daftar Isi
1. [Keunggulan Arsitektur Edisi Praktikum](#-keunggulan-arsitektur-edisi-praktikum)
2. [Peta Modul Praktikum ke Fitur & File Kode](#-peta-modul-praktikum-ke-fitur--file-kode)
3. [Operasi CRUD Lengkap & Otorisasi Kepemilikan](#-operasi-crud-lengkap--otorisasi-kepemilikan)
4. [Arsitektur Penyimpanan Lokal (10 Hive Box)](#-arsitektur-penyimpanan-lokal-10-hive-box)
5. [Integrasi Web Service / REST API Publik](#-integrasi-web-service--rest-api-publik)
6. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
7. [Panduan Instalasi & Menjalankan Proyek (Zero-Config)](#-panduan-instalasi--menjalankan-proyek-zero-config)
8. [Akun Demo Siap Uji & Skenario Pengujian](#-akun-demo-siap-uji--skenario-pengujian)
9. [Pengujian Otomatis (Unit & Widget Tests)](#-pengujian-otomatis-unit--widget-tests)

---

## ✨ Keunggulan Arsitektur Edisi Praktikum

- **Zero Configuration (Tanpa `.env` & Tanpa Server Cloud):** Seluruh data disimpan secara lokal menggunakan **Hive (`hive_flutter`)** dan otomatis diisi data awal (*auto-seeding*) saat aplikasi pertama kali dijalankan. Asisten/penguji cukup menjalankan `flutter pub get && flutter run`.
- **100% Sesuai Kurikulum Praktikum:**
  - **Tanpa Riverpod / GetX / Provider:** Seluruh state layar dikelola dengan `StatelessWidget`, `StatefulWidget`, `setState()`, `TextEditingController`, serta 2 `ValueNotifier` global ringan di `AppState.instance` (`currentUser` & `selectedCurrency`).
  - **Tanpa GoRouter:** Seluruh perpindahan halaman menggunakan `Navigator.push`, `Navigator.pop`, `Navigator.pushReplacement`, `Navigator.pushAndRemoveUntil`, pengiriman data lewat constructor, dan `BottomNavigationBar` 3 tab (`Dex`, `Pasar`, `Profil`) berbasis `IndexedStack`.
  - **Tanpa Code Generation (`build_runner`):** Seluruh model Dart mengimplementasikan kontrak OOP `abstract class BaseEntity` dengan serialisasi `toMap()` dan `fromMap()` manual.

---

## 🗺️ Peta Modul Praktikum ke Fitur & File Kode

Tabel berikut memetakan setiap modul praktikum langsung ke implementasi nyata di dalam kode sumber HoloDex v2:

| Modul Praktikum | Konsep yang Diimplementasikan | Implementasi di HoloDex v2 | File Kode Utama |
|---|---|---|---|
| **Modul 1: Setup & Konfigurasi Flutter** | Struktur proyek modular *Feature-First*, konfigurasi `pubspec.yaml`, izin Android (`INTERNET`, `ACCESS_FINE_LOCATION`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`), inisialisasi asynchronous di `main()`. | Setup 10 Hive Box, Timezone perangkat, Local Notification, dan Auto-Seeder di `main.dart`. | `pubspec.yaml`<br>`android/app/src/main/AndroidManifest.xml`<br>`lib/main.dart`<br>`lib/app/app.dart` |
| **Modul 2: OOP & Pemrograman Dart** | `abstract class`, `implements`, *Polymorphism*, *Encapsulation*, *Enhanced Enum* (`AppCurrency`, `OrderStatus`, `EventFilter`), *Custom Exception* (`AuthFailure`, `MarketplaceFailure`, `OrderFailure`), serialisasi manual `toMap()`/`fromMap()`. | Kontrak `BaseEntity` (`id`, `toMap()`) yang diimplementasikan oleh 8 model utama aplikasi. | `lib/core/models/base_entity.dart`<br>`lib/core/models/card_model.dart`<br>`lib/core/models/listing_model.dart`<br>`lib/core/models/order_model.dart`<br>`lib/core/models/user_model.dart` |
| **Modul 3: Widget, Layout & State Management** | Material 3 Dark Theme, `StatefulWidget`, `setState()`, `TextEditingController`, `ValueListenableBuilder`, `LayoutBuilder`, `GridView`, `Wrap`, isolasi rebuild sensor 60fps & countdown timer, anti-overflow pada layar `320dp` (`textScaleFactor: 1.3`). | Katalog Grid Kartu, Mode Multi-Select, Filter Bottom Sheet, Konverter Mata Uang, dan Isolasi `HoloCardWidget` / `ClockTicker`. | `lib/app/app_state.dart`<br>`lib/app/theme.dart`<br>`lib/features/dex/screens/dex_screen.dart`<br>`lib/features/dex/widgets/holo_card_widget.dart`<br>`lib/features/converter/screens/converter_screen.dart` |
| **Modul 4: Navigasi & Routing** | `Navigator.push`, `Navigator.pop(context, true)` (refresh induk setelah tambah/edit/hapus), `Navigator.pushReplacement`, `Navigator.pushAndRemoveUntil`, constructor data passing, `BottomNavigationBar` 3 Tab + `IndexedStack`, `GlobalKey<NavigatorState>` untuk deep-link notifikasi. | Shell 3 Tab (`Dex`, `Pasar`, `Profil`), alur Auth (`Splash` -> `Login` -> `BottomNavShell`), pengiriman objek `CardModel` & `ListingModel` via constructor. | `lib/shared/widgets/bottom_nav_shell.dart`<br>`lib/app/navigation_keys.dart`<br>`lib/features/auth/screens/splash_screen.dart`<br>`lib/features/marketplace/screens/listing_detail_screen.dart` |
| **Modul 5 / 6: HTTP Request & Web Service (REST API)** | Permintaan HTTP `GET` asynchronous menggunakan `package:http`, parsing JSON, error handling, dan sinkronisasi ke database lokal. | 1. **TCGdex REST API:** Sinkronisasi katalog set & harga pasar kartu Pokémon TCG.<br>2. **Frankfurter ECB REST API:** Kurs mata uang real-time (`USD`, `IDR`, `EUR`, `JPY`). | `lib/core/repositories/card_repository.dart`<br>`lib/core/services/currency_service.dart`<br>`lib/core/utils/card_price_calculator.dart` |
| **Modul 6 / 7: Penyimpanan Lokal (Hive Database & CRUD)** | Penyimpanan NoSQL lokal berbasis key-value (`hive` + `hive_flutter`) dengan 10 Box terstruktur, auto-seeding data awal, serta operasi **Create, Read, Update, Delete (CRUD)** penuh. | Manajemen 10 Hive Box, Seeder 24 kartu + 10 penjual + 15 listing + 3 event, CRUD Listing Pasar (termasuk **Edit Listing**), CRUD Watchlist, dan Rekber COD. | `lib/core/database/hive_database.dart`<br>`lib/core/database/initial_data_seeder.dart`<br>`lib/core/services/marketplace_repository.dart`<br>`lib/core/services/collection_repository.dart`<br>`lib/core/services/order_repository.dart` |
| **Autentikasi, Session & Otorisasi** | Hashing kata sandi SHA-256 (`crypto`), persistent session di `holodex_session` box, proteksi aksi berdasarkan kepemilikan data (`sellerId == currentUser.id`), dan privasi nomor WhatsApp COD. | Login, Register, Auto-Login saat aplikasi dibuka kembali, Logout, tombol **Edit/Batalkan Listing** khusus pemilik, serta pencairan Rekber khusus pembeli. | `lib/core/services/auth_service.dart`<br>`lib/features/auth/screens/login_screen.dart`<br>`lib/features/auth/screens/register_screen.dart`<br>`lib/features/profile/screens/profile_screen.dart` |
| **Modul 7 / 8: Notifikasi Lokal & Zona Waktu Perangkat** | Inisialisasi `flutter_local_notifications`, sinkronisasi timezone lokal perangkat (`flutter_timezone` + `tz.local`), penjadwalan `zonedSchedule`, notifikasi instan transaksi & harga turun Watchlist. | Pengingat H-1 rilis set/turnamen, tombol simulasi notifikasi 5 detik, notifikasi saat harga kartu menyentuh target Watchlist, dan notifikasi pesanan Rekber. | `lib/core/services/notification_service.dart`<br>`lib/features/converter/screens/calendar_screen.dart` |
| **Modul 8 / Bonus: Location-Based Service (LBS) & Sensor Fisik** | Peta interaktif OpenStreetMap (`flutter_map`), pembacaan GPS (`geolocator`), perhitungan jarak Haversine (`latlong2`), filter radius km, serta sensor `gyroscopeEventStream` (`sensors_plus`). | Peta Penjual Terdekat di 10 kota Indonesia, penanda titik temu COD pesanan, dan efek kilau kartu 3D Holofoil saat ponsel dimiringkan. | `lib/core/services/location_service.dart`<br>`lib/features/marketplace/screens/map_screen.dart`<br>`lib/features/dex/widgets/holo_card_widget.dart` |

---

## 🔄 Operasi CRUD Lengkap & Otorisasi Kepemilikan

HoloDex v2 mengimplementasikan siklus **Create, Read, Update, Delete (CRUD)** secara lengkap di penyimpanan lokal Hive disertai pemeriksaan otorisasi pengguna aktif:

### 1. CRUD Listing Marketplace (`MarketplaceRepository`)
- **Create (`createListing`):** Penjual membuat listing penjualan kartu baru di `CreateListingScreen` (memilih kartu dari katalog, menentukan harga IDR, kondisi fisik, deskripsi, dan koordinat GPS titik COD).
- **Read (`fetchActiveListings` & `getListingDetail`):** Menampilkan daftar kartu aktif di `MarketplaceScreen`, detail listing di `ListingDetailScreen`, serta marker lokasi penjual di `MapScreen`.
- **Update (`updateListing` — Fitur Edit Listing):** Penjual pemilik listing (`listing.sellerId == currentUser.id && listing.status == 'active'`) dapat menekan tombol **"Edit Listing"** pada `ListingDetailScreen` untuk membuka `CreateListingScreen(existingListing: listing)` dan memperbarui harga, kondisi fisik, deskripsi, maupun titik koordinat COD.
- **Delete (`cancelListing`):** Penjual pemilik listing dapat membatalkan/menghapus listing aktif miliknya dari pasar.

### 2. CRUD Watchlist & Target Harga (`CollectionRepository`)
- **Create (`addToWatchlist`):** Menambahkan kartu ke daftar incaran dari `CardDetailScreen` atau melalui mode *Multi-Select* di `DexScreen`.
- **Read (`getWatchlist`):** Menampilkan daftar kartu incaran beserta indikator **"Target Tercapai"** di `WatchlistScreen`.
- **Update (`updateWatchlistAlertPrice`):** Mengubah nominal target harga pengingat (IDR) pada setiap kartu di Watchlist.
- **Delete (`removeFromWatchlist`):** Menghapus kartu dari Watchlist.

### 3. Siklus Transaksi Rekber COD 72 Jam (`OrderRepository`)
- **Reserve (Tahan Saldo Escrow):** Pembeli memesan kartu -> saldo pembeli dipotong dan ditahan di Rekber selama 72 jam -> status listing berubah menjadi `reserved`.
- **Koordinasi WhatsApp Privasi Terjaga (`getOrderContact`):** Nomor WhatsApp lawan transaksi hanya dibuka untuk pasangan pembeli & penjual pada pesanan berstatus `reserved` dan terhubung langsung ke `wa.me` dengan template pesan COD otomatis.
- **Confirm Receipt (Serah Terima Selesai):** Saat bertemu COD, pembeli menekan **"Sudah Kuterima"** -> dana Rekber diteruskan ke saldo penjual -> kartu otomatis masuk ke **Binder Koleksi Fisik (`holodex_collections`)** pembeli -> tercatat di **Riwayat Transaksi (`holodex_transactions`)**.
- **Cancel / Expire (Refund 100%):** Jika dibatalkan atau melewati 72 jam, saldo pembeli dikembalikan 100% secara utuh dan listing kembali aktif.

---

## 🗄️ Arsitektur Penyimpanan Lokal (10 Hive Box)

Seluruh persistensi data dikelola oleh `HiveDatabase` (`lib/core/database/hive_database.dart`) yang membuka 10 Hive Box berbasis `Map<String, dynamic>`:

| No | Nama Hive Box | Fungsi & Data yang Disimpan |
|---|---|---|
| 1 | `holodex_settings` | Flag `is_seeded`, preferensi mata uang (`IDR`/`USD`/`EUR`/`JPY`), dan status notifikasi pesanan. |
| 2 | `holodex_session` | Menyimpan `active_user_id` dan `logged_in_at` untuk fitur *Persistent Session* (Auto-Login). |
| 3 | `holodex_users` | Data akun pengguna (`UserModel` dengan password hash SHA-256, foto profil, saldo IDR, nomor WhatsApp). |
| 4 | `holodex_cards` | Katalog kartu Pokémon TCG (`CardModel`) beserta harga USD (TCGplayer), EUR (Cardmarket), dan IDR. |
| 5 | `holodex_currency` | Cache kurs mata uang dari Frankfurter ECB API (`IDR`, `EUR`, `JPY` terhadap `USD`) dengan TTL 24 jam. |
| 6 | `holodex_listings` | Daftar listing penjualan kartu di Pasar P2P (`ListingModel`) lengkap dengan koordinat GPS (`lat`, `lng`). |
| 7 | `holodex_orders` | Pesanan Rekber COD (`OrderModel`: `reserved`, `completed`, `cancelled`, `expired`). |
| 8 | `holodex_transactions` | Riwayat mutasi pembelian dan penjualan kartu yang telah selesai (`TransactionModel`). |
| 9 | `holodex_collections` | Binder koleksi kartu fisik milik pengguna yang diperoleh dari transaksi pembelian pasar. |
| 10 | `holodex_watchlist` | Daftar kartu incaran pengguna beserta batas harga notifikasi (`alert_price_idr`). |

---

## 🌐 Integrasi Web Service / REST API Publik

1. **TCGdex REST API (`https://api.tcgdex.net/v2/en/`)**
   - Mengambil daftar kartu per set (`GET /v2/en/sets/{setId}`) untuk set populer (`swsh7` Evolving Skies, `swsh3` Darkness Ablaze, `sv01` Scarlet & Violet, `sv05` Temporal Forces).
   - Mengambil detail kartu beserta harga pasar internasional (`GET /v2/en/cards/{cardId}`) dari **TCGplayer (USD)** dan **Cardmarket (EUR)**, lalu menyimpannya ke `holodex_cards` box.
   - Dapat dipicu langsung dari tombol **Sinkronisasi TCGdex API** (ikon awan) di pojok kanan atas layar **Dex**.

2. **Frankfurter European Central Bank API (`https://api.frankfurter.dev/v1/latest?from=USD&to=EUR,IDR,JPY`)**
   - Mengambil nilai tukar resmi ECB secara gratis tanpa API key.
   - Digunakan untuk mengonversi harga seluruh katalog kartu dan portofolio binder secara instan ke **IDR, USD, EUR, atau JPY**.

---

## 📁 Struktur Direktori Proyek

```text
lib/
├── main.dart                          # Inisialisasi Hive, Timezone, Notification, Seeder & runApp
├── app/
│   ├── app.dart                       # MaterialApp + rootNavigatorKey + SplashScreen
│   ├── app_state.dart                 # Singleton 2 ValueNotifier (currentUser & selectedCurrency)
│   ├── navigation_keys.dart           # GlobalKey<NavigatorState> untuk deep-link notifikasi
│   └── theme.dart                     # Material 3 Dark Theme + aturan tombol anti-overflow
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Konstanta endpoint REST API & nama 10 Hive Box
│   ├── database/
│   │   ├── hive_database.dart         # Pengelola 10 Hive Box
│   │   └── initial_data_seeder.dart   # Seeder otomatis (akun demo, 10 seller, 24 kartu, 15 listing, 3 event)
│   ├── models/
│   │   ├── base_entity.dart           # Abstract class BaseEntity (kontrak OOP id & toMap)
│   │   ├── card_model.dart
│   │   ├── collection_item_model.dart
│   │   ├── listing_model.dart
│   │   ├── order_model.dart
│   │   ├── release_event_model.dart
│   │   ├── transaction_model.dart
│   │   ├── user_model.dart
│   │   └── watchlist_item_model.dart
│   ├── repositories/
│   │   └── card_repository.dart       # Query katalog Hive & sinkronisasi HTTP REST TCGdex API
│   ├── services/
│   │   ├── auth_service.dart          # Login/Register SHA-256, Persistent Session, Top Up & Profil
│   │   ├── collection_repository.dart # Binder Koleksi Fisik & CRUD Watchlist Hive
│   │   ├── currency_service.dart      # HTTP GET Frankfurter ECB API & konversi 4 mata uang
│   │   ├── location_service.dart      # GPS Geolocator & kalkulasi jarak Haversine (km)
│   │   ├── marketplace_repository.dart# CRUD Listing Pasar (Create, Read, Update/Edit, Delete)
│   │   ├── notification_service.dart  # Local Notifications + timezone perangkat (tz.local)
│   │   └── order_repository.dart      # Rekber COD 72 jam & otorisasi kontak WhatsApp
│   └── utils/
│       ├── card_price_calculator.dart # Kalkulator harga kartu multi-mata uang
│       ├── price_formatter.dart       # Formatter mata uang & waktu relatif
│       └── whatsapp_helper.dart       # Validasi, normalisasi 628xx, masking & deep-link wa.me
├── features/
│   ├── auth/                          # SplashScreen, LoginScreen (pintasan akun demo), RegisterScreen
│   ├── dex/                           # DexScreen, SearchScreen, CardDetailScreen (Gyroscope Holo 3D)
│   ├── converter/                     # ConverterScreen (4 mata uang) & CalendarScreen (Event & Pengingat)
│   ├── marketplace/                   # MarketplaceScreen, ListingDetailScreen, CreateListingScreen (Buat/Edit),
│   │                                  # MyOrdersScreen (Rekber & WA), MapScreen (LBS OSM), TransactionHistoryScreen
│   └── profile/                       # ProfileScreen, CollectionScreen (Binder), WatchlistScreen, WhatsAppDialog
└── shared/
    └── widgets/
        ├── bottom_nav_shell.dart      # BottomNavigationBar 3 Tab (Dex, Pasar, Profil) dengan IndexedStack
        ├── app_network_image.dart
        └── loading_widget.dart
```

---

## 🛠️ Panduan Instalasi & Menjalankan Proyek (Zero-Config)

Aplikasi ini **tidak memerlukan file `.env`** atau konfigurasi database eksternal.

```bash
# 1. Masuk ke direktori proyek & unduh paket dependensi
flutter pub get

# 2. Jalankan aplikasi di emulator / perangkat Android
flutter run

# 3. (Opsional) Build APK Debug
flutter build apk --debug
```

---

## 🎮 Akun Demo Siap Uji & Skenario Pengujian

Saat aplikasi pertama kali dijalankan, `InitialDataSeeder` otomatis menyiapkan akun demo beserta ekosistem pasar siap pakai:

| Kredensial Akun Demo | Nilai |
|---|---|
| **Username** | `trainer_ash` *(tersedia tombol 1-klik **"Isi Akun Demo"** di layar Login)* |
| **Password** | `password123` |
| **Saldo Virtual Awal** | `Rp 2.500.000` (dapat ditambah kapan saja lewat tombol **Top Up** di tab Profil) |
| **Nomor WhatsApp COD** | `6281234567890` |
| **Listing Milik Sendiri** | `Charizard V (Darkness Ablaze)` seharga `Rp 185.000` (siap diuji untuk fitur **Edit Listing**) |

### Skenario Uji Cepat untuk Penilaian Praktikum:
1. **Login & Persistent Session:** Pada layar Login, ketuk tombol **"Isi Akun Demo (trainer_ash)"** lalu ketuk **Masuk**. Tutup dan buka kembali aplikasi untuk membuktikan sesi tetap tersimpan otomatis.
2. **Katalog Dex, Multi-Currency & Gyroscope 3D:** Di tab **Dex**, ganti chip mata uang (`IDR` / `USD` / `EUR` / `JPY`) untuk melihat harga kartu berubah real-time. Ketuk kartu **Umbreon VMAX** lalu miringkan ponsel untuk melihat efek pelangi **3D Holofoil Gyroscope**.
3. **Event & Pengingat Notifikasi Lokal:** Dari beranda Dex, buka tile **Event & Pengingat**, ketuk **"Pasang Pengingat Notifikasi"** -> pilih **"Tes Notifikasi Sekarang (Simulasi 5 Detik)"** untuk melihat notifikasi lokal muncul mengikuti jam perangkat.
4. **CRUD Pasar & Fitur Edit Listing (`Update`):** Buka tab **Pasar**, pilih listing **Charizard V** milik `@trainer_ash`. Ketuk tombol **"Edit Listing"**, ubah harga atau kondisi fisik, lalu simpan.
5. **Rekber COD, Peta LBS & WhatsApp:** Pilih listing kartu milik penjual lain di tab **Pasar**, ketuk **Pesan** (saldo ditahan di Rekber). Buka tab **Pesanan Saya**, ketuk **"Hubungi via WhatsApp"** atau **"Titik COD"** di peta OpenStreetMap, lalu ketuk **"Sudah Kuterima"** untuk menyelesaikan transaksi dan memasukkan kartu ke **Binder Koleksi Saya**.

---

## 🧪 Pengujian Otomatis (Unit & Widget Tests)

Seluruh lapisan model OOP, repository Hive, konversi mata uang, kalkulasi jarak LBS Haversine, otorisasi CRUD & Rekber COD, hingga ketahanan antarmuka pada layar sempit `320dp` (`textScaleFactor: 1.3`) diverifikasi dengan rangkaian pengujian otomatis:

```bash
# Analisis statis kode Dart
flutter analyze

# Jalankan seluruh Unit Test & Widget Test
flutter test
```
