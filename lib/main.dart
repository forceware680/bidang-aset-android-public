import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'api.dart';
import 'gerakan.dart';
import 'kalender.dart';
import 'layar_detail.dart';
import 'layar_kalender.dart';
import 'layar_masuk.dart';
import 'konfigurasi.dart';
import 'pengingat.dart';
import 'simpan.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Data tanggal bahasa Indonesia dipakai semua tulisan tanggal di aplikasi.
  initializeDateFormatting('id');
  // Pada build uji layar HP dibiarkan menyala supaya pengujian lewat adb tidak terjebak kunci layar.
  if (kDebugMode) WakelockPlus.enable();
  runApp(Aplikasi());
}

/// Aplikasi agenda untuk petugas bidang aset.
/// Bila perangkat sudah punya token, aplikasi langsung membuka kalender; bila tidak, layar masuk.
/// Dipasang di layar Masuk saat aplikasi dikeluarkan otomatis oleh server.
const _pesanKeluarOtomatis =
    'Akun kamu keluar otomatis — token perangkat dicabut Administrator atau sudah kedaluwarsa. Masuk lagi untuk memakai aplikasi.';

class Aplikasi extends StatefulWidget {
  const Aplikasi({super.key});

  @override
  State<Aplikasi> createState() => _AplikasiState();
}

class _AplikasiState extends State<Aplikasi> {
  final Pengingat _pengingat = Pengingat();
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  Api? _api;
  bool _bootSelesai = false;
  String? _pesanKeluar;

  @override
  void initState() {
    super.initState();
    _jalankan();
  }

  Future<void> _jalankan() async {
    try {
      // Inisialisasi notifikasi tidak boleh menahan aplikasi; kalau HP menolak, kalender tetap terbuka.
      await _pengingat.siap(saatDiketuk: _bukaDariPengingat).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Perangkat tanpa layanan notifikasi (misal uji otomatis) tetap bisa memakai aplikasi.
    }
    // Token ditolak kapan pun di tengah sesi: keluar senyap ke layar masuk tanpa pesan galat
    // di tengah layar — sama seperti saat Administrator mencabut dari web.
    Api.padaDitolak = () async {
      if (_api == null) return;
      _api = null;
      _pesanKeluar = _pesanKeluarOtomatis;
      await Simpan().keluar();
      await _pengingat.batalSemua();
      setState(() {});
    };
    final token = await Simpan().token();
    if (token != null) {
      final api = Api(baseUrl: baseUrl, token: token);
      try {
        await api.sesi();
        _api = api;
      } on Galat catch (g) {
        // 401: token kedaluwarsa atau dicabut, perangkat harus masuk lagi.
        if (g.status == 401) {
          await Simpan().keluar();
          _pesanKeluar = _pesanKeluarOtomatis;
        }
      }
      if (_api != null) await _sinkronAlarm(api);
    }
    setState(() => _bootSelesai = true);
  }

  /// Jadwal ulang alarm mengikuti daftar agenda: alarm untuk agenda yang akun ini bukan peserta
  /// maupun pembuat dibuang, supaya rapat surat tidak lagi maksa berbunyi di semua HP. Untuk
  /// agenda yang akun ini ikut, alarm dipasang menurut nyala/mati toggle pengingat HP ini.
  Future<void> _sinkronAlarm(Api api) async {
    try {
      final daftar = await PembacaKalender(api).mendatang(hari: 30);
      final pengingatNyala = await Simpan().pengingatAktif();
      for (final a in daftar) {
        if (!a.ikut) {
          await _pengingat.batal(a.id);
        } else if (pengingatNyala) {
          await _pengingat.pasang(a, true, await Simpan().pengingatMenit(a.id));
        }
      }
    } catch (_) {
      // Server diam: alarm lama tetap, sinkron coba lagi saat aplikasi dibuka berikutnya.
    }
  }

  /// Alarm yang diketuk membuka detail agenda terkait.
  Future<void> _bukaDariPengingat(String payload) async {
    final api = _api;
    if (api == null || payload.isEmpty) return;
    try {
      final agenda = await api.agenda(payload);
      final konteks = _navigator.currentContext;
      if (konteks == null || !konteks.mounted) return;
      await Navigator.of(konteks).push(rutePudarLewat(konteks, LayarDetailAgenda(api: api, pengingat: _pengingat, agenda: agenda, padaBerubah: () {})));
    } on Galat catch (_) {
      // Agenda sudah dihapus atau server sedang tidak menjawab; alarm dilewati.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Bidang Aset',
      navigatorKey: _navigator,
      theme: temaAplikasi(),
      debugShowCheckedModeBanner: false,
      // Penanggalan Indonesia, termasuk pilihan tanggal/jam bawaan Material.
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: !_bootSelesai
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) => Text(
                        'Mengambil agenda...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _api == null
              ? LayarMasuk(pesanKeluar: _pesanKeluar, padaMasuk: (api, sesi) {
                  setState(() => _api = api);
                })
              : LayarKalender(
                  api: _api!,
                  pengingat: _pengingat,
                  padaKeluar: () {
                    setState(() => _api = null);
                  },
                ),
    );
  }
}
