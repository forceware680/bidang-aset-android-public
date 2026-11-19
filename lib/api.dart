import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'agenda.dart';
import 'root_yr.dart';

/// Batas tunggu permintaan API. Bila server diam, aplikasi menampilkan gagal muat daripada menggantung.
const _batasWaktu = Duration(seconds: 15);

/// Daftar CA HP belum mengenal akar Let's Encrypt "ISRG Root YR" yang dipakai sertifikat
/// server produksi ini, jadi akar itu dimuat tambahan. Daftar CA bawaan HP tetap dipakai.
SecurityContext _konteksTLS() {
  final konteks = SecurityContext(withTrustedRoots: true);
  try {
    // Android dan iOS menerima sertifikat berakar sebagai DER; desktop menerima bentuk PEM.
    konteks.setTrustedCertificatesBytes(Platform.isAndroid || Platform.isIOS ? akarYrDer() : utf8.encode(sertifikatAkarYr));
  } catch (_) {
    // Bila akar tambahan tidak bisa dimuat, daftar CA bawaan HP tetap dipakai.
  }
  return konteks;
}

/// Klien HTTP dengan akar TLS tambahan.
http.Client _klienTLS() => IOClient(HttpClient(context: _konteksTLS()));

/// Nama server dalam pesan galat, supaya petugas tahu alamat yang dicoba kalau koneksi gagal.
String _namaServer(String baseUrl) => Uri.parse(baseUrl).host;

/// Galat dari API: pesannya sudah berbahasa petugas, jadi ditampilkan apa adanya.
class Galat implements Exception {
  final int status;
  final String pesan;
  Galat(this.status, this.pesan);
  @override
  String toString() => pesan;
}

/// Pembawa token dan alamat server. Semua alamat API dipanggil lewat kelas ini.
class Api {
  final String baseUrl;
  final String token;
  final http.Client _klien;

  /// Dipanggil saat server menolak 401 di tengah sesi (token dicabut dari web atau kedaluwarsa):
  /// aplikasi keluar senyap dan kembali ke layar masuk, bukan memamerkan pesan "tidak dikenali".
  static void Function()? padaDitolak;

  Api({required this.baseUrl, required this.token, http.Client? klien}) : _klien = klien ?? _klienTLS();

  Uri _uri(String jalur) => Uri.parse('$baseUrl$jalur');

  Future<Map<String, dynamic>> _kirim(String metode, String jalur, {Map<String, dynamic>? isi, Map<String, String>? query}) async {
    final uri = _uri(jalur);
    final url = (query == null || query.isEmpty)
        ? uri
        : uri.replace(query: query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&'));
    final header = {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
    late http.Response respon;
    try {
      switch (metode) {
        case 'GET':
          respon = await _klien.get(url, headers: header).timeout(_batasWaktu);
        case 'POST':
          respon = await _klien.post(url, headers: {...header, 'Content-Type': 'application/json'}, body: jsonEncode(isi ?? {})).timeout(_batasWaktu);
        case 'PATCH':
          respon = await _klien.patch(url, headers: {...header, 'Content-Type': 'application/json'}, body: jsonEncode(isi ?? {})).timeout(_batasWaktu);
        case 'DELETE':
          respon = await _klien.delete(url, headers: header).timeout(_batasWaktu);
        default:
          throw Galat(0, 'Cara permintaan tidak dikenali.');
      }
    } catch (_) {
      throw Galat(0, 'Koneksi ke server ${_namaServer(baseUrl)} gagal. Periksa jaringan HP kamu lalu coba lagi.');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(respon.body) as Map<String, dynamic>;
    } catch (_) {
      throw Galat(respon.statusCode, 'Server menjawab bukan dalam bentuk yang dikenali (${respon.statusCode}).');
    }
    if (respon.statusCode == 401) padaDitolak?.call();
    if (respon.statusCode >= 400) throw Galat(respon.statusCode, json['pesan'] as String? ?? 'Permintaan ditolak server.');
    return json;
  }

  /// Masuk tanpa token: menjawab token pembawa yang dipakai pada semua alamat berikutnya.
  /// Nama perangkat ikut dikirim supaya administrator bisa melihat HP mana yang dipakai masuk.
  static Future<Map<String, dynamic>> masuk({required String baseUrl, required String email, required String password, String? perangkat, http.Client? klien}) async {
    final klienAktif = klien ?? _klienTLS();
    late http.Response respon;
    try {
      respon = await klienAktif
          .post(
            Uri.parse('$baseUrl/api/masuk'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'email': email, 'password': password, if (perangkat != null && perangkat.isNotEmpty) 'perangkat': perangkat}),
          )
          .timeout(_batasWaktu);
    } catch (_) {
      throw Galat(0, 'Koneksi ke server ${_namaServer(baseUrl)} gagal. Periksa jaringan HP kamu lalu coba lagi.');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(respon.body) as Map<String, dynamic>;
    } catch (_) {
      throw Galat(respon.statusCode, 'Server menjawab bukan dalam bentuk yang dikenali (${respon.statusCode}).');
    }
    if (respon.statusCode >= 400) throw Galat(respon.statusCode, json['pesan'] as String? ?? 'Email atau kata sandi tidak cocok.');
    return json;
  }

  /// Pemeriksaan token saat aplikasi dibuka. 401 berarti perangkat harus masuk lagi.
  Future<Sesi> sesi() async => Sesi.dariJson(await _kirim('GET', '/api/sesi'));

  /// Kalender pada rentang tanggal (yyyy-mm-dd). `sejak` dipakai untuk menyinkronkan alarm.
  Future<List<Agenda>> kalender({String? hari, String? mulai, String? selesai, String? status, String? sejak}) async {
    final query = <String, String>{};
    if (hari != null) query['hari'] = hari;
    if (mulai != null) query['mulai'] = mulai;
    if (selesai != null) query['selesai'] = selesai;
    if (status != null) query['status'] = status;
    if (sejak != null) query['sejak'] = sejak;
    final json = await _kirim('GET', '/api/kalender', query: query.isEmpty ? null : query);
    final daftar = json['agenda'] as List<dynamic>? ?? const [];
    return daftar.map((e) => Agenda.dariJson(e as Map<String, dynamic>)).toList();
  }

  Future<Agenda> agenda(String id) async => Agenda.dariJson((await _kirim('GET', '/api/agenda/$id'))['agenda'] as Map<String, dynamic>);

  /// Pemberitahuan peserta yang belum disari: hanya peristiwa setelah `sejak` (UTC ISO). Bel notifikasi menyari ini berkala.
  Future<List<Pemberitahuan>> pemberitahuan({String? sejak}) async {
    final json = await _kirim('GET', '/api/pemberitahuan', query: sejak == null ? null : {'sejak': sejak});
    final daftar = json['pemberitahuan'] as List<dynamic>? ?? const [];
    return daftar.whereType<Map<String, dynamic>>().map(Pemberitahuan.dariJson).toList();
  }

  Future<({String? id, String pesan})> buatAgenda({required String judul, required String mulai, String? selesai, String? tempat, String? penyelenggara, String? catatan}) async {
    final json = await _kirim('POST', '/api/agenda', isi: {
      'agenda_rapat': judul,
      'tanggal_mulai': mulai,
      'tanggal_selesai': ?selesai,
      'tempat': ?(tempat?.isEmpty ?? true ? null : tempat),
      'penyelenggara': ?(penyelenggara?.isEmpty ?? true ? null : penyelenggara),
      'catatan': ?(catatan?.isEmpty ?? true ? null : catatan),
    });
    // Jawaban API menaruh agenda di `agenda`; id tidak di tingkat atas.
    final agenda = json['agenda'] as Map<String, dynamic>?;
    return (
      id: agenda?['id'] as String?,
      pesan: json['pesan'] as String? ?? 'Agenda tersimpan.',
    );
  }

  Future<String> ubahAgenda(String id, Map<String, dynamic> perubahan) async {
    final json = await _kirim('PATCH', '/api/agenda/$id', isi: perubahan);
    return json['pesan'] as String? ?? 'Agenda diperbarui.';
  }

  Future<String> hapusAgenda(String id) async {
    final json = await _kirim('DELETE', '/api/agenda/$id');
    return json['pesan'] as String? ?? 'Agenda dihapus.';
  }

  Future<String> gantiSandi({required String lama, required String baru, required String konfirmasi}) async {
    final json = await _kirim('POST', '/api/sandi', isi: {'password_lama': lama, 'password_baru': baru, 'password_konfirmasi': konfirmasi});
    return json['pesan'] as String? ?? 'Kata sandi berhasil diganti.';
  }

  /// Cabut token perangkat saat keluar dari aplikasi.
  Future<void> keluar() async => _kirim('POST', '/api/keluar');
}
