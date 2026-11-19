/// Alamat aplikasi web Bidang Aset. Build release harus memberi alamat server lewat
/// `--dart-define=BASE_URL=https://<domain>`; build uji bisa diarahkan ke server dev lewat
/// `--dart-define=BASE_URL=http://localhost:3000` (dengan `adb reverse`).
const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://domain-kamu (set via --dart-define=BASE_URL)');

/// Menit pengingat yang dipakai bila perangkat belum pernah memilih sendiri.
const menitPengingatBawaan = 15;

/// Versi aplikasi — persis `version:` di pubspec.yaml, termasuk angka build setelah `+`.
const versiApp = '1.0.0+1';
