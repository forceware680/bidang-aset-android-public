import 'dart:async';

import 'package:flutter/material.dart';

import 'agenda.dart';
import 'api.dart';
import 'format.dart';
import 'konfigurasi.dart';
import 'lebar_konten.dart';
import 'pengingat.dart';
import 'pengingat_menit.dart';
import 'simpan.dart';
import 'theme.dart';

/// Tulis agenda baru atau ubah agenda milik sendiri.
class LayarAgendaBaru extends StatefulWidget {
  final Api api;
  final Pengingat pengingat;
  final Agenda? agenda;
  /// Dipanggil layar sebelumnya kalau alarm pengingat gagal dijadwalkan (misal izin notifikasi belum diberikan).
  final void Function(String pesan)? padaGalatPengingat;
  const LayarAgendaBaru({
    super.key,
    required this.api,
    required this.pengingat,
    this.agenda,
    this.padaGalatPengingat,
  });

  @override
  State<LayarAgendaBaru> createState() => _LayarAgendaBaruState();
}

class _LayarAgendaBaruState extends State<LayarAgendaBaru> {
  final _judul = TextEditingController();
  final _tempat = TextEditingController();
  final _penyelenggara = TextEditingController();
  final _catatan = TextEditingController();

  DateTime _tanggal = DateTime.now();
  TimeOfDay _jam = TimeOfDay.now();
  DateTime? _tanggalSelesai;
  TimeOfDay? _jamSelesai;
  bool _pengingatAktif = true;
  int _menit = menitPengingatBawaan;

  bool _menyimpan = false;
  bool _sudahSimpan = false;
  bool _judulKosong = false;

  bool get _kotor =>
      widget.agenda == null
          ? _judul.text.isNotEmpty || _tempat.text.isNotEmpty || _penyelenggara.text.isNotEmpty || _catatan.text.isNotEmpty
          : true;

  @override
  void initState() {
    super.initState();
    final a = widget.agenda;
    if (a != null) {
      _judul.text = a.judul;
      _tempat.text = a.tempat ?? '';
      _penyelenggara.text = a.penyelenggara ?? '';
      _catatan.text = a.catatan ?? '';
      // Isian diisi sesuai waktu setempat perangkat, bukan UTC jawaban server.
      final mulaiLokal = a.mulai.toLocal();
      _tanggal = DateTime(mulaiLokal.year, mulaiLokal.month, mulaiLokal.day);
      _jam = TimeOfDay.fromDateTime(mulaiLokal);
      if (a.selesai != null) {
        final selesaiLokal = a.selesai!.toLocal();
        _tanggalSelesai = DateTime(selesaiLokal.year, selesaiLokal.month, selesaiLokal.day);
        _jamSelesai = TimeOfDay.fromDateTime(selesaiLokal);
      }
    }
    _muatPengingat();
  }

  @override
  void dispose() {
    _judul.dispose();
    _tempat.dispose();
    _penyelenggara.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muatPengingat() async {
    final aktif = await Simpan().pengingatAktif();
    final menit = widget.agenda == null
        ? await Simpan().pengingatMenitBawaan()
        : await Simpan().pengingatMenit(widget.agenda!.id);
    setState(() {
      _pengingatAktif = aktif;
      _menit = menit;
    });
  }

  /// Agenda untuk keperluan alarm, dibuat dari isian yang sedang di layar.
  Agenda _agendaIsian(String id, String judul) => Agenda(
        id: id,
        judul: judul,
        mulai: _mulai,
        selesai: _selesai,
        status: widget.agenda?.status ?? 'terjadwal',
        statusLabel: widget.agenda?.statusLabel ?? 'Terjadwal',
        sumber: 'agenda sendiri',
        dapatDiubah: true,
        dapatDihapus: true,
        tempat: _tempat.text.trim(),
      );

  DateTime get _mulai => DateTime(_tanggal.year, _tanggal.month, _tanggal.day, _jam.hour, _jam.minute);
  DateTime? get _selesai => _tanggalSelesai == null || _jamSelesai == null
      ? null
      : DateTime(_tanggalSelesai!.year, _tanggalSelesai!.month, _tanggalSelesai!.day, _jamSelesai!.hour, _jamSelesai!.minute);

  Future<void> _ambilTanggal(bool selesai) async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: selesai ? (_tanggalSelesai ?? _mulai) : _mulai,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (dipilih != null) setState(() => selesai ? _tanggalSelesai = dipilih : _tanggal = dipilih);
  }

  Future<void> _ambilJam(bool selesai) async {
    final dipilih = await showTimePicker(context: context, initialTime: selesai ? (_jamSelesai ?? _jam) : _jam);
    if (dipilih != null) setState(() => selesai ? _jamSelesai = dipilih : _jam = dipilih);
  }

  /// Keluar dari layar; bila ada isian yang belum disimpan, tanya dulu.
  Future<void> _batal() async {
    if (!_kotor || _menyimpan) {
      Navigator.of(context).pop();
      return;
    }
    final buang = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.agenda == null ? 'Buang agenda yang belum disimpan?' : 'Buang perubahan yang belum disimpan?'),
        content: Text('Isian yang sudah kamu tulis tidak akan tersimpan di kalender bidang.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Tetap di sini')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Buang')),
        ],
      ),
    );
    if (buang == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _simpan() async {
    final judul = _judul.text.trim();
    if (judul.isEmpty) {
      setState(() => _judulKosong = true);
      return;
    }
    setState(() {
      _menyimpan = true;
      _judulKosong = false;
    });
    try {
      final perubahan = <String, dynamic>{
        'agenda_rapat': judul,
        'tempat': _tempat.text.trim(),
        'penyelenggara': _penyelenggara.text.trim(),
        'catatan': _catatan.text.trim(),
        'tanggal_mulai': waktuApi(_mulai),
        if (_selesai != null) 'tanggal_selesai': waktuApi(_selesai!),
      };
      String? agendaId;
      if (widget.agenda == null) {
        final hasil = await widget.api.buatAgenda(
          judul: judul,
          mulai: waktuApi(_mulai),
          selesai: _selesai == null ? null : waktuApi(_selesai!),
          tempat: _tempat.text.trim(),
          penyelenggara: _penyelenggara.text.trim(),
          catatan: _catatan.text.trim(),
        );
        agendaId = hasil.id;
      } else {
        await widget.api.ubahAgenda(widget.agenda!.id, perubahan);
        agendaId = widget.agenda!.id;
      }
      if (!mounted) return;
      // Agenda sudah tersimpan — layar kembali dulu. Penjadwalan alarm dijalankan setelahnya, jadi layar
      // tidak menggantung berputar-putar kalau alarmnya lambat atau izin notifikasi belum diberikan.
      // `PopScope` di bawah membaca tanda ini supaya kembali setelah simpan tidak dianggap "batal".
      _sudahSimpan = true;
      Navigator.of(context).pop(widget.agenda == null ? 'buat' : 'ubah');
      if (agendaId == null) {
        widget.padaGalatPengingat?.call('Agenda tersimpan, tapi id tidak terbaca dari jawaban server — pengingat belum dijadwalkan.');
      } else {
        unawaited(_pasangPengingatSetelahKembali(agendaId, judul));
      }
    } on Galat catch (g) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(g.pesan),
          action: SnackBarAction(label: 'Coba lagi', onPressed: _simpan),
        ),
      );
    } catch (e) {
      // Kesalahan tak terduga (misal jawaban server berubah bentuk) tidak boleh menggantung spinner.
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menyimpan agenda gagal: $e'),
          action: SnackBarAction(label: 'Coba lagi', onPressed: _simpan),
        ),
      );
    }
  }

  /// Dijalankan setelah layar kembali: simpan pilihan pengingat dan pasang alarmnya. Kalau alarm lambat atau
  /// izin notifikasi belum diberikan, kegagalan dilaporkan ke layar sebelumnya — agenda sudah tersimpan.
  Future<void> _pasangPengingatSetelahKembali(String agendaId, String judul) async {
    await Simpan().simpanPengingat(_pengingatAktif);
    await Simpan().simpanPengingatMenit(agendaId, _menit);
    String? galat;
    try {
      galat = await widget.pengingat
          .pasang(_agendaIsian(agendaId, judul), _pengingatAktif, _menit)
          .timeout(const Duration(seconds: 10), onTimeout: () => 'Pengingat belum bisa dijadwalkan.');
    } catch (_) {
      galat = 'Pengingat belum bisa dijadwalkan.';
    }
    if (galat != null) widget.padaGalatPengingat?.call(galat);
  }

  @override
  Widget build(BuildContext context) {
    final tipografi = Theme.of(context).textTheme;
    final judulLayar = widget.agenda == null ? 'Agenda baru' : 'Ubah agenda';
    return PopScope(
      canPop: _sudahSimpan,
      onPopInvokedWithResult: (sudahPop, _) {
        if (!sudahPop && !_sudahSimpan) _batal();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(judulLayar),
          leading: IconButton(
            tooltip: 'Batal, kembali ke daftar agenda',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: LebarKonten(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                key: const ValueKey('judul-agenda'),
                controller: _judul,
                decoration: InputDecoration(
                  labelText: 'Nama agenda',
                  errorText: _judulKosong ? 'Nama agenda wajib diisi.' : null,
                ),
              ),
              const SizedBox(height: 16),
              Text('Waktu mulai', style: tipografi.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TombolUtama(
                      key: const ValueKey('tanggal-mulai'),
                      label: tanggalPendek(_mulai),
                      ikon: Icons.calendar_today_outlined,
                      garis: true,
                      onTap: () => _ambilTanggal(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TombolUtama(
                      key: const ValueKey('waktu-mulai'),
                      label: jamIndo(_mulai),
                      ikon: Icons.access_time_outlined,
                      garis: true,
                      onTap: () => _ambilJam(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Waktu selesai (boleh kosong)', style: tipografi.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TombolUtama(
                      key: const ValueKey('tanggal-selesai'),
                      label: _tanggalSelesai == null ? 'Tanggal' : tanggalPendek(_tanggalSelesai!),
                      ikon: Icons.calendar_today_outlined,
                      garis: true,
                      onTap: () => _ambilTanggal(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TombolUtama(
                      key: const ValueKey('waktu-selesai'),
                      label: _jamSelesai == null ? 'Tidak ada' : jamIndo(_selesai!),
                      ikon: Icons.access_time_outlined,
                      garis: true,
                      onTap: () => _ambilJam(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tempat,
                decoration: const InputDecoration(
                  labelText: 'Tempat',
                  hintText: 'misal: Ruang Rapat A',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _penyelenggara,
                decoration: const InputDecoration(labelText: 'Penyelenggara'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _catatan,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Catatan', alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(_pengingatAktif ? 'Pengingat alarm menyala' : 'Pengingat alarm mati'),
                      subtitle: Text('Alarm pada HP ini · ${labelMenitPengingat(_menit)}'),
                      trailing: Switch(
                        value: _pengingatAktif,
                        onChanged: (v) => setState(() => _pengingatAktif = v),
                      ),
                      onTap: () => setState(() => _pengingatAktif = !_pengingatAktif),
                    ),
                    if (_pengingatAktif)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PilihMenitPengingat(
                            menit: _menit,
                            onChanged: (menit) => setState(() => _menit = menit),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomSheet: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: LebarKonten(
              child: Row(
                children: [
                  TextButton(onPressed: _menyimpan ? null : _batal, child: const Text('Batal')),
                  const Spacer(),
                  TombolUtama(
                    key: const ValueKey('simpan-agenda'),
                    label: widget.agenda == null ? 'Simpan agenda' : 'Simpan perubahan',
                    labelMemuat: widget.agenda == null ? 'Menyimpan agenda…' : 'Menyimpan perubahan…',
                    ikon: Icons.check_circle_outline,
                    sedangMemuat: _menyimpan,
                    onTap: _simpan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
