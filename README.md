<div align="center">
  <img src="imgs/logo.png" width="140" alt="Logo Bidang Aset" />
  <h1>Agenda Bidang Aset — aplikasi Android (Flutter)</h1>
</div>

<p align="center">
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" /></a>
  <a href="https://github.com/forceware680/bidang-aset-web"><img alt="Web companion" src="https://img.shields.io/badge/Web_companion-bidang--aset--web-F97316?style=flat-square" /></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/forceware680/bidang-aset-android-public?style=flat-square" /></a>
</p>

Aplikasi Android pendamping **Agenda Surat dan Jadwal Rapat** Bidang Aset BPKAD Kota Magelang, pasangan dari
aplikasi web [`forceware680/bidang-aset-web`](https://github.com/forceware680/bidang-aset-web). Keduanya memakai
API yang sama (`app/api/*` di repo web); requirement, database, dan panduan deploy aplikasi web ada di README repo itu.

## Batas pemakaian
Aplikasi ini sengaja kecil. Petugas, pegawai, dan pimpinan hanya bisa:

- membaca kalender agenda bidang (semua agenda, bukan hanya miliknya),
- membaca siapa saja yang hadir di sebuah agenda (nama peserta dari daftar pegawai bidang, terbaca di
  daftar maupun layar detail),
- membuat, mengubah, dan menghapus **agenda miliknya sendiri**,
- mengubah status agenda miliknya (belum / berjalan / selesai),
- memasang atau mematikan pengingat alarm untuk agenda miliknya,
- mengubah kata sandi sendiri dan keluar.

Tidak ada surat masuk, disposisi, lampiran, rekap, atau pengaturan di sini — itu kerjaan aplikasi web.

## Server
Alamat server **tidak** ditempel tetap: build harus memberi `--dart-define=BASE_URL=https://domain-kamu`
(`lib/konfigurasi.dart` hanya punya placeholder bila tidak diberikan). Untuk uji dengan server web di laptop:
`adb reverse tcp:3000 tcp:3000`, lalu build debug dengan `--dart-define=BASE_URL=http://localhost:3000`.

Login memakai akun yang sama dengan aplikasi web. Token masuk disimpan di `SharedPreferences` dan dikirim sebagai
`Authorization: *** server menyimpan hash SHA-256-nya di tabel `api_token` dan mencabutnya saat Keluar.

## Pengingat
Alarm dipasang di perangkat pada jam **WIB** (`Asia/Jakarta`), `menit` menit sebelum waktu mulai agenda: preset
0/5/15/30/60/120 menit atau angka sendiri 0–1440, tersimpan per agenda.

Nada alarm dibunyikan sendiri oleh kode Kotlin (`MainActivity.kt` + `AlarmReceiver.kt`, memakai
`android/app/src/main/res/raw/agenda_alarm.wav`) di jalur suara alarm HP. Notifikasi alarm juga diposting dari
`AlarmReceiver` sendiri (receiver bawaan paket sering diblok MIUI) dengan tombol **Hentikan nada**; klik
notifikasi menghentikan nada lalu membuka agendanya. Kanal notifikasi dibuat tanpa suara karena
MIUI selalu memakai nada notifikasi bawaannya untuk notifikasi aplikasi. Alarm bunyi disimpan di
`SharedPreferences` native dan dipasang ulang setelah HP dinyalakan kembali (`ACTION_BOOT_COMPLETED`). Tombol
**Coba bunyi alarm** di tab Akun membunyikannya sekarang. Bila HP memblokir notifikasi aplikasi ini, aplikasi
mendeteksinya dan menawarkan **Izinkan notifikasi**.

## Yang harus terpasang di komputer
| kebutuhan | versi sekarang | catatan |
|---|---|---|
| Flutter stable | 3.47.x (Dart 3.13) | tambahkan ke PATH, lalu `flutter config --android-sdk <SDK>` |
| JDK | OpenJDK 17 | Gradle butuh Java 17; set `JAVA_HOME` |
| Android SDK | platform-tools, `platforms;android-37`, `build-tools;36.0.0` | `sdkmanager` di atas, set `ANDROID_HOME` |
| Gradle | lewat wrapper | diunduh otomatis ke `~/.gradle` pada build pertama |
| adb | dari platform-tools | untuk `adb install -r` APK debug di HP uji |

`flutter doctor` harus bersih sebelum build (Flutter, JDK, Android SDK, lisensi diterima).

## Dependency Dart (`pubspec.yaml`)
| paket | kenapa dibutuhkan |
|---|---|
| `http` | panggilan API REST ke server (`/api/masuk`, `/api/kalender`, `/api/agenda`, `/api/agenda/<id>`, `/api/sandi`, `/api/sesi`) |
| `shared_preferences` | token Bearer, menit pengingat per agenda, tanda kanal nada sudah dibuat |
| `flutter_local_notifications` ^23 | alarm `setExactAndAllowWhileIdle` + notifikasi; inilah yang memaksa compileSdk 37 dan desugaring |
| `timezone` | acuan waktu alarm `Asia/Jakarta` (bawaan paket ini UTC, diubah di `lib/pengingat.dart`) |
| `intl` | format tanggal Indonesia (`Senin, 9 November 2026`) |
| `flutter_localizations` (SDK) | tanggal/jam picker berbahasa Indonesia |
| `wakelock_plus` | layar tahan menyala **hanya** di mode debug (`kDebugMode`), tidak di APK release |
| `cupertino_icons` | ikon Cupertino bawaan Flutter |
| `flutter_lints` (dev) | `flutter analyze` bersih |

## Konfigurasi Android yang wajib (bukan pilihan)
- `compileSdk = 37` di `android/app/build.gradle.kts` — plugin notifikasi butuh API 37 (`flutter.compileSdkVersion` masih 36).
- `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` — plugin memakai `java.time`.
- `sourceCompatibility = JavaVersion.VERSION_17`.
- `minSdk 24`, `targetSdk 36` (bawaan Flutter 3.47).
- izin `INTERNET` **wajib** di `android/app/src/main/AndroidManifest.xml` — manifest bawaan Flutter hanya
  memakainya di varian debug, jadi APK release tanpa izin ini tidak bisa konek sama sekali
  (cek: `aapt dump permissions build/app/outputs/flutter-apk/app-release.apk`).
- izin lain di manifest kita: `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`; `VIBRATE` dan
  `POST_NOTIFICATIONS` datang dari manifest plugin.
- receiver: dua receiver plugin (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`) dan
  `id.go.magelang.agenda_aset.AlarmReceiver` untuk bunyi alarm serta pasang ulang alarm setelah HP dinyalakan.

## Build dan uji
```bash
flutter pub get
flutter analyze            # harus "No issues found"
flutter test               # 25 uji
flutter build apk --release --dart-define=BASE_URL=https://domain-kamu   # APK produksi
flutter build apk --debug  # untuk diuji di HP lewat adb
flutter build apk --debug --dart-define=BASE_URL=http://localhost:3000   # server dev di laptop (adb reverse dulu)
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Uji otomatis: `test/skema_test.dart` menguji kontras (≥ 4.5 teks, ≥ 3 elemen bentuk), ukuran teks (≥ 11 sp),
target sentuh (≥ 48 dp), skala bentuk; `test/pengingat_menit_test.dart` menguji pemilih menit alarm;
`test/agenda_peserta_test.dart` menguat nama yang hadir dibaca sebagai daftar (nama dengan koma tidak dipecah)
dan daftar panjang dipotong; `test/tls_akar_test.dart` menguji akar TLS tambahan; `test/widget_test.dart`
menguat perangkat tanpa token tetap minta masuk.

### Uji alur di HP (integration test)
Uji ini menggerakkan aplikasi sungguhan di HP: masuk → daftar agenda 30 hari → buka satu agenda → membaca nama
yang hadir. Kredensial dikirim lewat `--dart-define` supaya kata sandi tidak masuk ke git.
```bash
adb -s <serial-hp> reverse tcp:3000 tcp:3000    # hanya bila memakai server dev di laptop
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/alur_login_kalender_test.dart -d <serial-hp> \
  --dart-define=BASE_URL=<alamat-server> \
  --dart-define=UJI_EMAIL=<email-petugas> --dart-define=UJI_SANDI=<kata-sandi-petugas>
```
Hasil ditulis ke `build/integration_results.json`. Uji memakai kunci widget (`email`, `sandi`, `masuk`,
`agenda-<id>`, `peserta`) di `lib/layar_masuk.dart`, `lib/kalender.dart`, `lib/layar_detail.dart`.

### Kalau login di HP gagal padahal situs hidup
Penyebab yang sudah ditemukan dan diperbaiki di kode ini — jangan sampai hilang lagi:

- **Izin `INTERNET` di manifest** (lihat bagian Konfigurasi wajib).
- **Rantai sertifikat server berakar "ISRG Root YR"** (Let's Encrypt baru). Daftar CA Android 14 hanya berisi
  ISRG Root X1 dan X2, jadi TLS aplikasi bisa menolak sertifikat server sementara peramban menerima. Aplikasi
  memuat akar itu tambahan (`lib/root_yr.dart`, dipakai di `lib/api.dart`). Lebih bersih bila server memakai
  rantai berakar ISRG Root X1; setelah itu `lib/root_yr.dart` bisa dihapus.
- Dialog izin notifikasi Android 13/14 tidak ditunggu saat aplikasi dibuka (izin diminta ketika alarm dipasang),
  dan inisialisasi notifikasi diberi batas 10 detik, supaya layar masuk tidak menggantung.

## Setup dari nol (komputer baru)
```bash
git clone https://github.com/forceware680/bidang-aset-android-public.git
cd bidang-aset-android-public
flutter pub get
flutter doctor            # bersihkan sampai semua centang
flutter analyze
flutter test
flutter build apk --release --dart-define=BASE_URL=https://domain-kamu
```

## Lisensi
MIT — lihat berkas `LICENSE`.
