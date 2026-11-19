import 'dart:async';

import 'package:flutter/material.dart';

import 'agenda.dart';
import 'api.dart';
import 'format.dart';
import 'gerakan.dart';
import 'kalender.dart';
import 'lebar_konten.dart';
import 'layar_agenda_baru.dart';
import 'layar_akun.dart';
import 'layar_detail.dart';
import 'layar_pemberitahuan.dart';
import 'pengingat.dart';
import 'simpan.dart';
import 'theme.dart';

class LayarKalender extends StatefulWidget {
  final Api api;
  final Pengingat pengingat;
  final VoidCallback padaKeluar;
  const LayarKalender({super.key, required this.api, required this.pengingat, required this.padaKeluar});

  @override
  State<LayarKalender> createState() => _LayarKalenderState();
}

class _LayarKalenderState extends State<LayarKalender> {
  int _tab = 0;
  int _versi = 0;
  int _jumlahHariIni = 0;
  List<Pemberitahuan> _bel = const [];
  Timer? _detakBel;

  @override
  void initState() {
    super.initState();
    _mulaiDetakBel();
  }

  @override
  void dispose() {
    _detakBel?.cancel();
    super.dispose();
  }

  /// Penyarian pemberitahuan peserta tiap menit selagi aplikasi hidup, dari layar utama:
  /// yang baru dibunyikan sebagai notifikasi HP dan dimasukkan ke lonceng sampai dibaca.
  void _mulaiDetakBel() {
    _detakBel = Timer.periodic(const Duration(seconds: 60), (_) => _cekPemberitahuan());
    unawaited(_cekPemberitahuan());
  }

  Future<void> _cekPemberitahuan() async {
    try {
      final lihat = await Simpan().lihatPemberitahuan();
      final daftar = await widget.api.pemberitahuan(sejak: lihat?.toUtc().toIso8601String());
      DateTime palingBaru = lihat ?? DateTime.now().toUtc();
      final masuk = <Pemberitahuan>[];
      for (final p in daftar) {
        if (p.padaUtc.isAfter(palingBaru)) palingBaru = p.padaUtc;
        // Pertama kali: peristiwa lama hanya menjadi titik awal, tidak dibunyikan dan tidak masuk lonceng.
        if (lihat == null) continue;
        masuk.add(p);
      }
      if (masuk.isNotEmpty) {
        for (final p in masuk) {
          await widget.pengingat.tampilkanPeserta(
            idNotif: p.id,
            oleh: p.oleh,
            agenda: p.agenda,
            isi: '${tanggalPendek(p.mulai)} ${jamIndo(p.mulai)}',
            payload: p.rapatId,
          );
        }
        final lama = await Simpan().ambilBel();
        final sudah = {for (final p in lama) p.id};
        final gabungan = [...lama, ...masuk.where((p) => !sudah.contains(p.id))];
        await Simpan().simpanBel(gabungan);
        if (mounted) setState(() => _bel = gabungan);
      }
      await Simpan().simpanLihatPemberitahuan(palingBaru);
    } catch (e) {
      // Server diam atau jaringan putus: dicoba lagi pada penyarian berikutnya.
      debugPrint('Penyarian pemberitahuan gagal: $e');
    }
  }

  /// Lonceng dengan lencana jumlah yang belum dibaca, dipasang di header kedua halaman kalender.
  Widget _lonceng() => Semantics(
        label: _bel.isEmpty
            ? 'Pemberitahuan peserta, belum ada yang belum dibaca'
            : 'Pemberitahuan peserta, ${_bel.length} belum dibaca',
        child: IconButton(
          icon: Badge(
            isLabelVisible: _bel.isNotEmpty,
            label: Text('${_bel.length}'),
            child: const Icon(Icons.notifications_none),
          ),
          tooltip: _bel.isEmpty ? 'Belum ada pemberitahuan peserta' : '${_bel.length} pemberitahuan peserta belum dibaca',
          onPressed: _bukaLonceng,
        ),
      );

  void _bukaLonceng() {
    Navigator.of(context).push(
      rutePudarLewat(
        context,
        LayarPemberitahuan(
          daftar: _bel,
          padaBukaItem: (p) async {
            await _tandaiDibaca(p);
            try {
              final agenda = await widget.api.agenda(p.rapatId);
              await _bukaAgenda(agenda);
            } catch (_) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agenda itu sudah dihapus.')));
            }
          },
          padaBacaSemua: () async {
            await Simpan().simpanBel(const <Pemberitahuan>[]);
            if (mounted) setState(() => _bel = const []);
          },
        ),
      ),
    );
  }

  Future<void> _tandaiDibaca(Pemberitahuan p) async {
    final sisa = _bel.where((x) => x.id != p.id).toList();
    await Simpan().simpanBel(sisa);
    if (mounted) setState(() => _bel = sisa);
  }

  Future<void> _bukaAgenda(Agenda agenda) async {
    bool berubah = false;
    final hasil = await Navigator.of(context).push<String>(
      rutePudarLewat(
        context,
        LayarDetailAgenda(
          api: widget.api,
          pengingat: widget.pengingat,
          agenda: agenda,
          padaBerubah: () => berubah = true,
        ),
      ),
    );
    if (hasil == 'hapus' || berubah) setState(() => _versi++);
  }

  Future<void> _agendaBaru() async {
    final hasil = await Navigator.of(context).push<String>(
      rutePudarLewat(
        context,
        LayarAgendaBaru(
          api: widget.api,
          pengingat: widget.pengingat,
          padaGalatPengingat: (pesan) {
            if (mounted) umpanPengingat(context, widget.pengingat, pesan);
          },
        ),
      ),
    );
    if (hasil == 'buat') setState(() => _versi++);
  }

  /// Satu FAB per layar: tindakan utama menulis agenda baru, mengapung di atas bilah navigasi.
  Widget _fab() => FloatingActionButton.extended(
        onPressed: _agendaBaru,
        tooltip: 'Tulis agenda baru',
        icon: const Icon(Icons.event_outlined),
        label: const Text('Agenda baru'),
      );

  @override
  Widget build(BuildContext context) {
    final pembaca = PembacaKalender(widget.api);
    final isi = switch (_tab) {
      0 => HalamanHariIni(
        pembaca: pembaca,
        pengingat: widget.pengingat,
        padaBuka: _bukaAgenda,
        padaJumlah: (n) { if (mounted) setState(() => _jumlahHariIni = n); },
        lonceng: _lonceng(),
      ),
      1 => HalamanMendatang(pembaca: pembaca, pengingat: widget.pengingat, padaBuka: _bukaAgenda, lonceng: _lonceng()),
      _ => LayarAkun(api: widget.api, pengingat: widget.pengingat, padaKeluar: widget.padaKeluar),
    };
    return Scaffold(
      // FAB hanya pada layar kalender; pada tab Akun ia tidak mewakili tindakan apa pun.
      floatingActionButton: _tab == 2 ? null : _fab(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BilahNavigasi(tab: _tab, jumlahHariIni: _jumlahHariIni, padaPilih: (i) => setState(() => _tab = i)),
      ),
      body: SafeArea(
        top: false,
        child: KeyedSubtree(key: ValueKey(_versi), child: isi),
      ),
    );
  }
}

/// Bilah navigasi Material 3: label selalu terlihat, ikon terisi untuk yang aktif.
class BilahNavigasi extends StatelessWidget {
  final int tab;
  final int jumlahHariIni;
  final ValueChanged<int> padaPilih;
  const BilahNavigasi({super.key, required this.tab, required this.jumlahHariIni, required this.padaPilih});

  static const _tujuan = <(String, String, IconData, IconData)>[
    ('Hari ini', 'agenda hari ini', Icons.event, Icons.event_outlined),
    ('Mendatang', 'agenda beberapa hari ke depan', Icons.schedule, Icons.schedule_outlined),
    ('Akun', 'akun dan perangkat', Icons.person, Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: padaPilih,
      destinations: List.generate(_tujuan.length, (i) {
        final (nama, keterangan, terisi, garis) = _tujuan[i];
        return NavigationDestination(
          // Lencana Material 3 pada ikon: jumlah agenda hari ini terlihat tanpa membuka tab.
          icon: i == 0
              ? Badge(
                  isLabelVisible: jumlahHariIni > 0,
                  label: Text('$jumlahHariIni'),
                  child: Icon(garis),
                )
              : Icon(garis),
          selectedIcon: Icon(terisi),
          label: nama,
          tooltip: keterangan,
        );
      }),
    );
  }
}

/// Daftar agenda dengan empat keadaan nyata: dimuat, kosong, gagal, terisi.
class _Daftar extends StatelessWidget {
  final Future<List<Agenda>>? muat;
  final Widget kosong;
  final VoidCallback cobaLagi;
  final void Function(Agenda) padaBuka;
  final ValueChanged<int>? padaJumlah;
  final bool tampilPejabatLain;
  const _Daftar({
    required this.muat,
    required this.kosong,
    required this.cobaLagi,
    required this.padaBuka,
    this.padaJumlah,
    this.tampilPejabatLain = false,
  });

  @override
  Widget build(BuildContext context) {
    final durasi = durasiGerakan(context);
    final tipografi = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    return FutureBuilder<List<Agenda>>(
      future: muat,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnimatedSwitcher(
            duration: durasi,
            child: KeyedSubtree(
              // Kunci mengikuti fetch yang sedang berjalan; dua fetch berbeda tidak boleh
              // memakai kunci sama, kalau sama AnimatedSwitcher menyimpan dua anak sekaligus.
              key: ValueKey('muat-${identityHashCode(muat)}'),
              child: const Column(children: [BayanganAgenda(), BayanganAgenda(), BayanganAgenda()]),
            ),
          );
        }
        if (snapshot.hasError) {
          return AnimatedSwitcher(
            duration: durasi,
            child: KartuGagal(
              key: const ValueKey('gagal'),
              pesan: snapshot.error is Galat ? (snapshot.error as Galat).pesan : 'Koneksi ke server gagal.',
              cobaLagi: cobaLagi,
            ),
          );
        }
        final semua = snapshot.data ?? const <Agenda>[];
        // Agenda sendiri/participant tampil biasa; agenda pejabat lain hanya kalau togglenya nyala.
        final punya = semua.where((a) => a.ikut).toList();
        final lain = tampilPejabatLain ? semua.where((a) => !a.ikut).toList() : const <Agenda>[];
        // Jumlah dilaporkan ke bilah navigasi setelah build selesai, supaya tidak setState di tengah build.
        final lapor = padaJumlah;
        if (lapor != null) {
          final jumlah = punya.length;
          WidgetsBinding.instance.addPostFrameCallback((_) => lapor(jumlah));
        }
        if (punya.isEmpty && lain.isEmpty) {
          return AnimatedSwitcher(duration: durasi, child: KeyedSubtree(key: const ValueKey('kosong'), child: kosong));
        }
        return AnimatedSwitcher(
          duration: durasi,
          child: Column(
            key: ValueKey('daftar ${punya.length + lain.length}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in punya)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: BarisAgenda(agenda: a, onTap: () => padaBuka(a))),
              if (lain.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text('Agenda pejabat lain',
                      style: tipografi.titleSmall?.copyWith(color: skema.onSurfaceVariant)),
                ),
                for (final a in lain)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: BarisAgenda(agenda: a, onTap: () => padaBuka(a))),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Daftar mendatang, dikelompokkan per hari supaya mudah dibaca.
class _DaftarMendatang extends StatelessWidget {
  final Future<List<Agenda>>? muat;
  final Widget kosong;
  final VoidCallback cobaLagi;
  final void Function(Agenda) padaBuka;
  final bool tampilPejabatLain;
  const _DaftarMendatang({
    required this.muat,
    required this.kosong,
    required this.cobaLagi,
    required this.padaBuka,
    this.tampilPejabatLain = false,
  });

  @override
  Widget build(BuildContext context) {
    final tipografi = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final durasi = durasiGerakan(context);
    return FutureBuilder<List<Agenda>>(
      future: muat,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnimatedSwitcher(
            duration: durasi,
            child: KeyedSubtree(
              key: ValueKey('muat-${identityHashCode(muat)}'),
              child: const Column(children: [BayanganAgenda(), BayanganAgenda()]),
            ),
          );
        }
        if (snapshot.hasError) {
          return AnimatedSwitcher(
            duration: durasi,
            child: KartuGagal(
              key: const ValueKey('gagal'),
              pesan: snapshot.error is Galat ? (snapshot.error as Galat).pesan : 'Koneksi ke server gagal.',
              cobaLagi: cobaLagi,
            ),
          );
        }
        final semua = snapshot.data ?? const <Agenda>[];
        final punya = semua.where((a) => a.ikut).toList();
        final lain = tampilPejabatLain ? semua.where((a) => !a.ikut).toList() : const <Agenda>[];
        if (punya.isEmpty && lain.isEmpty) {
          return AnimatedSwitcher(duration: durasi, child: KeyedSubtree(key: const ValueKey('kosong'), child: kosong));
        }
        return AnimatedSwitcher(
          duration: durasi,
          child: Column(
            key: ValueKey('daftar ${punya.length + lain.length}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final hari in _kelompokPerHari(punya)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(hari.key, style: tipografi.titleSmall),
                ),
                for (final a in hari.value)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: BarisAgenda(agenda: a, onTap: () => padaBuka(a))),
              ],
              if (lain.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text('Agenda pejabat lain',
                      style: tipografi.titleSmall?.copyWith(color: skema.onSurfaceVariant)),
                ),
                for (final hari in _kelompokPerHari(lain)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(hari.key, style: tipografi.bodySmall?.copyWith(color: skema.onSurfaceVariant)),
                  ),
                  for (final a in hari.value)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: BarisAgenda(agenda: a, onTap: () => padaBuka(a))),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  static List<MapEntry<String, List<Agenda>>> _kelompokPerHari(List<Agenda> daftar) {
    final kelompok = <String, List<Agenda>>{};
    for (final a in daftar) {
      kelompok[tanggalPendek(a.mulai)] = [...(kelompok[tanggalPendek(a.mulai)] ?? const []), a];
    }
    return kelompok.entries.toList();
  }
}

/// Halaman agenda hari ini.
class HalamanHariIni extends StatefulWidget {
  final PembacaKalender pembaca;
  final Pengingat pengingat;
  final void Function(Agenda) padaBuka;
  final ValueChanged<int>? padaJumlah;
  final Widget? lonceng;
  const HalamanHariIni({
    super.key,
    required this.pembaca,
    required this.pengingat,
    required this.padaBuka,
    this.padaJumlah,
    this.lonceng,
  });

  @override
  State<HalamanHariIni> createState() => _HalamanHariIniState();
}

class _HalamanHariIniState extends State<HalamanHariIni> {
  Future<List<Agenda>>? _muat;
  bool _tampilLain = false;

  @override
  void initState() {
    super.initState();
    _muat = widget.pembaca.hariIni();
    _bacaToggle();
  }

  Future<void> _bacaToggle() async {
    final aktif = await Simpan().tampilkanPejabatLain();
    if (mounted) setState(() => _tampilLain = aktif);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tanggalPendek(DateTime.now())),
        automaticallyImplyLeading: false,
        actions: [if (widget.lonceng != null) widget.lonceng!],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _bacaToggle();
          setState(() => _muat = widget.pembaca.hariIni());
        },
        child: LebarKonten(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
            children: [
              Text('Agenda hari ini', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              _Daftar(
                muat: _muat,
                kosong: const KartuKosong(
                  judul: 'Belum ada agenda hari ini.',
                  panduan: 'Gunakan tombol Agenda baru untuk menulis agenda hari ini, atau cek tab Mendatang.',
                ),
                cobaLagi: () => setState(() => _muat = widget.pembaca.hariIni()),
                padaBuka: widget.padaBuka,
                padaJumlah: widget.padaJumlah,
                tampilPejabatLain: _tampilLain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman agenda beberapa hari ke depan.
class HalamanMendatang extends StatefulWidget {
  final PembacaKalender pembaca;
  final Pengingat pengingat;
  final void Function(Agenda) padaBuka;
  final Widget? lonceng;
  const HalamanMendatang({super.key, required this.pembaca, required this.pengingat, required this.padaBuka, this.lonceng});

  @override
  State<HalamanMendatang> createState() => _HalamanMendatangState();
}

class _HalamanMendatangState extends State<HalamanMendatang> {
  String? _preset = '7';
  DateTime? _mulai;
  DateTime? _selesai;
  Future<List<Agenda>>? _muat;
  bool _tampilLain = false;

  @override
  void initState() {
    super.initState();
    _muat = widget.pembaca.mendatang(hari: 7);
    _bacaToggle();
  }

  Future<void> _bacaToggle() async {
    final aktif = await Simpan().tampilkanPejabatLain();
    if (mounted) setState(() => _tampilLain = aktif);
  }

  /// Rentang aktif untuk judul subtitle dan kartu kosong.
  String get _judulRentang => _preset != null
      ? '$_preset hari ke depan'
      : '${tanggalPendek(_mulai!)} – ${tanggalPendek(_selesai!)}';

  Future<List<Agenda>> _muatRentang() => _preset != null
      ? widget.pembaca.mendatang(hari: int.parse(_preset!))
      : widget.pembaca.rentang(_mulai!, _selesai!);

  void _pilihPreset(String hari) => setState(() {
    _preset = hari;
    _mulai = null;
    _selesai = null;
    _muat = widget.pembaca.mendatang(hari: int.parse(hari));
  });

  Future<void> _rentangTanggal() async {
    final hariIni = DateTime.now();
    final dipilih = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hariIni.year, hariIni.month, hariIni.day),
      lastDate: hariIni.add(const Duration(days: 365)),
      initialDateRange: _preset == null
          ? DateTimeRange(start: _mulai!, end: _selesai!)
          : DateTimeRange(start: hariIni, end: hariIni.add(const Duration(days: 7))),
    );
    if (dipilih == null || !mounted) return;
    setState(() {
      _preset = null;
      _mulai = dipilih.start;
      _selesai = dipilih.end;
      _muat = widget.pembaca.rentang(dipilih.start, dipilih.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Judul + rentang aktif dalam satu kolom: subtitle parameter belum ada di Flutter versi ini.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agenda mendatang'),
            Text(_judulRentang, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        automaticallyImplyLeading: false,
        // Titik tiga, bukan tiga pil: pilihan rentang jarang diubah, jadi cukup menu
        // yang juga membuka picker rentang tanggal bebas.
        actions: [
          if (widget.lonceng != null) widget.lonceng!,
          Semantics(
            label: 'Pilih rentang yang ditampilkan',
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                for (final hari in const ['7', '14', '30'])
                  PopupMenuItem(
                    value: hari,
                    child: _ItemRentang(teks: '$hari hari ke depan', terpilih: _preset == hari),
                  ),
                const PopupMenuItem(
                  value: 'rentang',
                  child: _ItemRentang(teks: 'Rentang tanggal…', terpilih: false),
                ),
              ],
              onSelected: (nilai) => nilai == 'rentang' ? _rentangTanggal() : _pilihPreset(nilai),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _bacaToggle();
          setState(() => _muat = _muatRentang());
        },
        child: LebarKonten(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
            children: [
              _DaftarMendatang(
                muat: _muat,
                kosong: KartuKosong(
                  key: ValueKey('kosong $_judulRentang'),
                  judul: _preset != null
                      ? 'Belum ada agenda tercatat dalam $_judulRentang.'
                      : 'Belum ada agenda tercatat pada rentang $_judulRentang.',
                  panduan: 'Tulis agenda baru dengan tombol Agenda baru, atau cek kalender web Bidang Aset untuk agenda dari surat.',
                ),
                cobaLagi: () => setState(() => _muat = _muatRentang()),
                padaBuka: widget.padaBuka,
                tampilPejabatLain: _tampilLain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item menu rentang: centang kecil menandai pilihan aktif, jadi user tahu sedang lihat yang mana.
class _ItemRentang extends StatelessWidget {
  final String teks;
  final bool terpilih;
  const _ItemRentang({required this.teks, required this.terpilih});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(teks),
        if (terpilih) Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}
