import 'package:intl/intl.dart';

final _hari = DateFormat('EEEE, d MMMM yyyy', 'id');
final _hariPendek = DateFormat('EEEE, d MMM', 'id');
final _jam = DateFormat('HH.mm', 'id');
final _bulan = DateFormat('MMMM', 'id');

/// Nama bulan dalam bahasa Indonesia: "November".
String namaBulan(DateTime waktu) => _bulan.format(waktu.toLocal());

/// Tanggal seperti pada kalender web: "Jumat, 14 November 2026".
String tanggalIndo(DateTime waktu) => _hari.format(waktu.toLocal());

/// Tanggal pendek untuk judul kelompok hari: "Jumat, 14 Nov".
String tanggalPendek(DateTime waktu) => _hariPendek.format(waktu.toLocal());

/// Jam saja, memakai titik seperti tulisan di aplikasi web: "09.00".
/// Waktu dari API ber-offset +07:00; diubah ke waktu lokal perangkat sebelum diformat.
String jamIndo(DateTime waktu) => _jam.format(waktu.toLocal());

/// Rentang waktu agenda: "09.00 – 11.30 WIB" atau "09.00 WIB" bila tidak ada waktu selesai.
String rentangWaktu(DateTime mulai, DateTime? selesai) {
  final awal = jamIndo(mulai);
  if (selesai == null) return '$awal WIB';
  return '$awal – ${jamIndo(selesai)} WIB';
}

/// Daftar nama yang hadir. Yang panjang dipotong supaya baris kalender tetap terbaca di HP.
String daftarNama(List<String> nama, {int batas = 2}) {
  if (nama.isEmpty) return '';
  if (nama.length <= batas) return nama.join(', ');
  return '${nama.take(batas).join(', ')} +${nama.length - batas} lainnya';
}

/// Tanggal yyyy-mm-dd untuk param API, dihitung pada waktu lokal perangkat (WIB).
String tanggalApi(DateTime waktu) => DateFormat('yyyy-MM-dd').format(waktu);

/// Waktu untuk `tanggal_mulai` API, selalu ber-offset +07:00 seperti jawaban server.
String waktuApi(DateTime waktu) => '${DateFormat('yyyy-MM-dd').format(waktu)}T${DateFormat('HH:mm').format(waktu)}:00+07:00';
