import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agenda.dart';
import 'konfigurasi.dart';

/// Yang disimpan di perangkat: token, identitas akun, dan pengaturan pengingat.
/// Alamat server tidak disimpan lagi: alamat produksi terpasang tetap di `konfigurasi.dart`.
class Simpan {
  static const _kunciToken = 'token';
  static const _kunciNama = 'nama';
  static const _kunciEmail = 'email';
  static const _kunciPeran = 'peran';
  static const _kunciPengingat = 'pengingat_aktif';
  static const _kunciMenitBawaan = 'pengingat_menit_bawaan';
  static const _kunciKanalNada = 'kanal_nada_alarm_v3';
  static const _kunciPejabatLain = 'tampilkan_pejabat_lain';
  static const _kunciLihatPemberitahuan = 'lihat_pemberitahuan';
  static const _kunciBel = 'bel_pemberitahuan';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ambil() async => _prefs ??= await SharedPreferences.getInstance();

  Future<String?> token() async => (await _ambil()).getString(_kunciToken);
  Future<String> nama() async => (await _ambil()).getString(_kunciNama) ?? '';
  Future<String> email() async => (await _ambil()).getString(_kunciEmail) ?? '';
  Future<String> peran() async => (await _ambil()).getString(_kunciPeran) ?? '';
  Future<bool> pengingatAktif() async => (await _ambil()).getBool(_kunciPengingat) ?? true;

  /// Menit pengingat untuk satu agenda; belum pernah dipilih berarti memakai pilihan bawaan perangkat.
  Future<int> pengingatMenit(String agendaId) async =>
      (await _ambil()).getInt('$_kunciMenitBawaan:$agendaId') ?? await pengingatMenitBawaan();

  /// Pilihan terakhir dipakai sebagai bawaan untuk agenda berikutnya.
  Future<int> pengingatMenitBawaan() async => (await _ambil()).getInt(_kunciMenitBawaan) ?? menitPengingatBawaan;

  Future<void> simpanPengingatMenit(String agendaId, int menit) async {
    final p = await _ambil();
    await p.setInt('$_kunciMenitBawaan:$agendaId', menit);
    await p.setInt(_kunciMenitBawaan, menit);
  }

  Future<void> simpanSesi({required String token, required String nama, required String email, required String peran}) async {
    final p = await _ambil();
    await p.setString(_kunciToken, token);
    await p.setString(_kunciNama, nama);
    await p.setString(_kunciEmail, email);
    await p.setString(_kunciPeran, peran);
  }

  Future<void> simpanPengingat(bool aktif) async => (await _ambil()).setBool(_kunciPengingat, aktif);

  /// Apakah agenda pejabat lain (yang akun ini bukan peserta maupun pembuat) boleh ikut ditampilkan.
  Future<bool> tampilkanPejabatLain() async => (await _ambil()).getBool(_kunciPejabatLain) ?? false;
  Future<void> simpanTampilkanPejabatLain(bool aktif) async => (await _ambil()).setBool(_kunciPejabatLain, aktif);

  /// Terakhir kali bel pemberitahuan peserta menyari; penyarian berikutnya hanya mengambil peristiwa lebih baru.
  Future<DateTime?> lihatPemberitahuan() async {
    final teks = (await _ambil()).getString(_kunciLihatPemberitahuan);
    return DateTime.tryParse(teks ?? '');
  }
  Future<void> simpanLihatPemberitahuan(DateTime waktu) async => (await _ambil()).setString(_kunciLihatPemberitahuan, waktu.toUtc().toIso8601String());

  /// Isi lonceng pemberitahuan yang belum dibaca. Disimpan di perangkat supaya lonceng tetap
  /// menunjukkan yang tertunda setelah aplikasi ditutup dan dibuka lagi; yang paling baru 50 saja.
  Future<List<Pemberitahuan>> ambilBel() async {
    final teks = (await _ambil()).getString(_kunciBel);
    if (teks == null) return const <Pemberitahuan>[];
    try {
      final daftar = jsonDecode(teks);
      if (daftar is! List) return const <Pemberitahuan>[];
      return daftar.whereType<Map<String, dynamic>>().map(Pemberitahuan.dariJson).toList();
    } catch (_) {
      return const <Pemberitahuan>[];
    }
  }

  Future<void> simpanBel(List<Pemberitahuan> daftar) async {
    final batas = daftar.length > 50 ? daftar.sublist(daftar.length - 50) : daftar;
    await (await _ambil()).setString(_kunciBel, jsonEncode(batas.map((p) => {
      'id': p.id,
      'rapat_id': p.rapatId,
      'oleh': p.oleh,
      'agenda_rapat': p.agenda,
      'mulai': p.mulai.toIso8601String(),
      'pada_utc': p.padaUtc.toIso8601String(),
    }).toList()));
  }

  /// Apakah kanal alarm sudah dibuat dengan nada alarm aplikasi (nada kanal tidak bisa diubah setelah kanal dibuat).
  Future<bool> kanalNadaAlarmSiap() async => (await _ambil()).getBool(_kunciKanalNada) ?? false;
  Future<void> simpanKanalNadaAlarmSiap() async => (await _ambil()).setBool(_kunciKanalNada, true);

  Future<void> keluar() async {
    final p = await _ambil();
    await p.remove(_kunciToken);
  }
}
