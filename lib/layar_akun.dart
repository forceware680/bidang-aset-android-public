import 'package:flutter/material.dart';

import 'dart:async';

import 'agenda.dart';
import 'api.dart';
import 'kalender.dart';
import 'format.dart';
import 'gerakan.dart';
import 'lebar_konten.dart';
import 'layar_sandi.dart';
import 'pengingat.dart';
import 'simpan.dart';
import 'theme.dart';

/// Akun petugas: identitas, perangkat yang dipakai, pengingat, kata sandi, keluar.
class LayarAkun extends StatefulWidget {
  final Api api;
  final Pengingat pengingat;
  final VoidCallback padaKeluar;
  const LayarAkun({super.key, required this.api, required this.pengingat, required this.padaKeluar});

  @override
  State<LayarAkun> createState() => _LayarAkunState();
}

class _LayarAkunState extends State<LayarAkun> {
  Sesi? _sesi;
  bool _pengingatAktif = true;
  bool _bolehNotif = true;
  String? _pesan;
  bool _gagal = false;
  bool _bunyiAktif = false;
  bool _tampilPejabatLain = false;
  Timer? _pollBunyi;

  @override
  void initState() {
    super.initState();
    _muat();
    // Baris bunyi dinamis: status playback dibaca dari native tiap setengah detik,
    // supaya alarm yang datang dari latar juga mengubah tombol jadi "Hentikan".
    _pollBunyi = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final aktif = await widget.pengingat.bunyiAktif();
      if (mounted && aktif != _bunyiAktif) setState(() => _bunyiAktif = aktif);
    });
  }

  @override
  void dispose() {
    _pollBunyi?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final sesi = await widget.api.sesi();
      final aktif = await Simpan().pengingatAktif();
      final tampilLain = await Simpan().tampilkanPejabatLain();
      bool boleh = true;
      try {
        boleh = await widget.pengingat.bolehNotifikasi();
      } catch (_) {
        // Perangkat tanpa layanan notifikasi tetap bisa dipakai.
      }
      if (!mounted) return;
      setState(() {
        _sesi = sesi;
        _pengingatAktif = aktif;
        _tampilPejabatLain = tampilLain;
        _bolehNotif = boleh;
        _pesan = null;
        _gagal = false;
      });
    } on Galat catch (g) {
      if (!mounted) return;
      setState(() {
        _gagal = true;
        _pesan = g.pesan;
      });
    }
  }

  void _umpan(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ubahPengingat(bool aktif) async {
    await Simpan().simpanPengingat(aktif);
    if (!mounted) return;
    setState(() => _pengingatAktif = aktif);
    if (!aktif) await widget.pengingat.batalSemua();
    _umpan(aktif ? 'Pengingat agenda di HP ini dinyalakan.' : 'Pengingat agenda di HP ini dimatikan.');
  }

  Future<void> _ubahPejabatLain(bool aktif) async {
    await Simpan().simpanTampilkanPejabatLain(aktif);
    if (!mounted) return;
    setState(() => _tampilPejabatLain = aktif);
    _umpan(aktif
        ? 'Agenda pejabat lain sekarang ikut tampil di kalender.'
        : 'Agenda pejabat lain disembunyikan — hanya agenda yang kamu ikut sebagai peserta.');
  }

  Future<void> _ujiBunyi() async {
    final galat = await widget.pengingat.cobaBunyi();
    if (!mounted) return;
    if (galat == null) setState(() => _bunyiAktif = true);
    _umpan(galat ?? 'Alarm dibunyikan di HP ini. Kalau tidak terdengar, izinkan notifikasi aplikasi ini.');
  }

  Future<void> _stopBunyi() async {
    final dihentikan = await widget.pengingat.stopBunyi();
    if (!mounted) return;
    setState(() => _bunyiAktif = false);
    _umpan(dihentikan ? 'Nada alarm dihentikan.' : 'Tidak ada nada alarm yang sedang berbunyi.');
  }

  Future<void> _keluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari HP ini?'),
        content: const Text('Token perangkat dicabut. Alarm pengingat agenda ikut berhenti.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Theme.of(dialogContext).colorScheme.error)),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await widget.api.keluar();
    } on Galat catch (_) {
      // Token yang sudah kedaluwarsa tidak perlu dicabut lagi.
    }
    await Simpan().keluar();
    await widget.pengingat.batalSemua();
    widget.padaKeluar();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tipografi = Theme.of(context).textTheme;
    final sesi = _sesi;
    final inisial = sesi == null
        ? '?'
        : sesi.nama.trim().split(' ').take(2).map((k) => k.isEmpty ? '' : k[0].toUpperCase()).join();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Akun'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(tooltip: 'Keluar dari HP ini', onPressed: _keluar, icon: const Icon(Icons.logout_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: LebarKonten(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
            children: [
              if (_gagal && _pesan != null) KartuGagal(pesan: _pesan!, cobaLagi: _muat),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: skema.primaryContainer,
                      borderRadius: bentuk(kecil),
                    ),
                    child: Text(
                      inisial,
                      style: tipografi.titleMedium?.copyWith(color: skema.onPrimaryContainer),
                    ),
                  ),
                  title: Text(sesi?.nama ?? 'Memuat akun...'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(sesi?.email ?? '', style: tipografi.bodyMedium),
                      if (sesi != null) Text(peranLabel(sesi.peran), style: tipografi.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Perangkat ini', style: tipografi.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone_android_outlined),
                      title: const Text('HP ini'),
                      subtitle: sesi == null
                          ? const Text('Menunggu jawaban server')
                          : Text('Token berlaku sampai ${tanggalIndo(sesi.kedaluwarsa)}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Pengingat agenda di HP ini'),
                      subtitle: const Text('Alarm dibunyikan nada alarm HP sebelum waktu mulai agenda'),
                      trailing: Switch(value: _pengingatAktif, onChanged: _ubahPengingat),
                      onTap: () => _ubahPeng(!_pengingatAktif),
                    ),
                    const Divider(),
                    ListTile(
                      key: const ValueKey('pejabat-lain'),
                      leading: const Icon(Icons.people_outline),
                      title: const Text('Tampilkan agenda pejabat lain'),
                      subtitle: const Text('Jika kamu aktifkan toggle ini maka agenda pejabat lain akan tampil di akunmu'),
                      trailing: Switch(value: _tampilPejabatLain, onChanged: _ubahPejabatLain),
                      onTap: () => _ubahPejabatLain(!_tampilPejabatLain),
                    ),
                    const Divider(),
                    // Satu baris dinamis: play saat diam, stop saat berbunyi — bukan dua baris paralel.
                    ListTile(
                      key: const ValueKey('bunyi-alarm'),
                      leading: Icon(_bunyiAktif ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                      title: Text(_bunyiAktif ? 'Hentikan nada alarm' : 'Coba bunyi alarm'),
                      subtitle: Text(_bunyiAktif
                          ? 'Alarm sedang berbunyi di HP ini — ketuk untuk berhenti'
                          : 'Bunyikan alarm sekarang di HP ini'),
                      onTap: _bunyiAktif ? _stopBunyi : _ujiBunyi,
                    ),
                  ],
                ),
              ),
              if (!_bolehNotif) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: skema.errorContainer,
                    borderRadius: bentuk(kecil),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 20, color: skema.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pesanNotifikasiDiblokir,
                              style: tipografi.bodyMedium?.copyWith(color: skema.onErrorContainer),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => widget.pengingat.bukaPengaturanNotifikasi(),
                              style: ButtonStyle(foregroundColor: WidgetStateProperty.all(skema.onErrorContainer)),
                              child: const Text('Izinkan notifikasi'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  key: const ValueKey('ubah-sandi'),
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Ubah kata sandi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(rutePudarLewat(context, LayarSandi(api: widget.api))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ubahPeng(bool aktif) async => _ubahPengingat(aktif);
}

/// Nama peran seperti yang dipakai petugas pada aplikasi web.
String peranLabel(String peran) {
  switch (peran) {
    case 'Administrator':
      return 'Pengelola aplikasi';
    case 'Petugas Agenda':
      return 'Petugas bidang aset';
    case 'Pembaca/Pimpinan':
      return 'Pimpinan bidang aset';
    default:
      return peran;
  }
}
