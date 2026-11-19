import 'package:flutter/material.dart';

import 'agenda.dart';
import 'api.dart';
import 'format.dart';
import 'gerakan.dart';
import 'konfigurasi.dart';
import 'layar_agenda_baru.dart';
import 'lebar_konten.dart';
import 'pengingat.dart';
import 'pengingat_menit.dart';
import 'simpan.dart';
import 'theme.dart';

/// Detail satu agenda. Yang bisa diubah hanya agenda buatan sendiri.
class LayarDetailAgenda extends StatefulWidget {
  final Api api;
  final Pengingat pengingat;
  final Agenda agenda;
  /// Dipanggil setiap kali agenda berubah di layar ini, supaya daftar kalender ikut diperbarui.
  final void Function() padaBerubah;
  const LayarDetailAgenda({
    super.key,
    required this.api,
    required this.pengingat,
    required this.agenda,
    required this.padaBerubah,
  });

  @override
  State<LayarDetailAgenda> createState() => _LayarDetailAgendaState();
}

class _LayarDetailAgendaState extends State<LayarDetailAgenda> {
  late Agenda _agenda = widget.agenda;
  bool _pengingatAktif = true;
  int _menit = menitPengingatBawaan;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    _pengingatAktif = await Simpan().pengingatAktif();
    _menit = await Simpan().pengingatMenit(widget.agenda.id);
    setState(() {});
  }

  void _umpan(String pesan, {bool gagal = false, String labelAksi = 'Coba lagi', VoidCallback? cobaLagi}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(gagal ? Icons.error_outline : Icons.check_circle_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(pesan)),
          ],
        ),
        action: cobaLagi == null ? null : SnackBarAction(label: labelAksi, onPressed: cobaLagi),
      ),
    );
  }

  Future<void> _gantiStatus(String status) async {
    setState(() => _menyimpan = true);
    try {
      await widget.api.ubahAgenda(_agenda.id, {'status_rapat': status});
      final terbaru = await widget.api.agenda(_agenda.id);
      if (!mounted) return;
      setState(() => _agenda = terbaru);
      widget.padaBerubah();
      _umpan('Status agenda diubah menjadi ${terbaru.statusLabel}.');
    } on Galat catch (g) {
      if (!mounted) return;
      _umpan(g.pesan, gagal: true, cobaLagi: () => _gantiStatus(status));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _ubahPengingat(bool aktif) async {
    setState(() => _menyimpan = true);
    await Simpan().simpanPengingat(aktif);
    final galat = await widget.pengingat
        .pasang(_agenda, aktif, _menit)
        .timeout(const Duration(seconds: 10), onTimeout: () => 'Pengingat belum bisa dijadwalkan.');
    if (!mounted) return;
    setState(() {
      _pengingatAktif = aktif;
      _menyimpan = false;
    });
    if (galat != null) {
      if (galat == pesanNotifikasiDiblokir) {
        _umpan(galat, gagal: true, labelAksi: 'Izinkan notifikasi',
            cobaLagi: () => widget.pengingat.bukaPengaturanNotifikasi());
        return;
      }
      _umpan(galat, gagal: true, cobaLagi: () => _ubahPengingat(aktif));
    } else {
      _umpan(aktif ? 'Pengingat dipasang untuk agenda ini.' : 'Pengingat agenda ini dimatikan.');
    }
  }

  Future<void> _hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus agenda ini?'),
        content: Text(
          'Agenda ${_agenda.judul} hilang dari kalender bidang. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(Theme.of(dialogContext).colorScheme.error),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await widget.api.hapusAgenda(_agenda.id);
      await widget.pengingat.batal(_agenda.id);
      if (!mounted) return;
      Navigator.of(context).pop('hapus');
    } on Galat catch (g) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(g.pesan)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipografi = Theme.of(context).textTheme;
    final milikSendiri = _agenda.milikSendiri;
    final sumber = milikSendiri
        ? 'Agenda kamu · bisa diubah dari HP ini'
        : _agenda.sumber == 'surat masuk'
            ? 'Dari surat ${_agenda.nomorSurat ?? '-'} · hanya bisa diubah dari aplikasi web'
            : 'Dibuat oleh ${_agenda.dibuatOleh ?? 'petugas lain'} · hanya terbaca dari HP ini';

    return Scaffold(
      appBar: AppBar(
        title: Text(_agenda.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Kembali ke kalender',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Ubah agenda',
            onPressed: milikSendiri ? _bukaUbah : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Hapus agenda',
            onPressed: milikSendiri ? _hapus : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: LebarKonten(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text(sumber, style: tipografi.bodyMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _BarisMeta(Icons.calendar_today_outlined, tanggalIndo(_agenda.mulai)),
                    _BarisMeta(Icons.access_time_outlined, rentangWaktu(_agenda.mulai, _agenda.selesai)),
                    _BarisMeta(Icons.place_outlined, _agenda.tempat ?? 'Tempat belum ditentukan'),
                    _BarisMeta(Icons.groups_outlined, _agenda.penyelenggara ?? 'Penyelenggara belum ditentukan'),
                    // Nama yang hadir dibaca lengkap di layar detail — di daftar kalender hanya dua nama yang ditampilkan.
                    _BarisMeta(
                      Icons.people_outline,
                      _agenda.peserta.isEmpty ? 'Peserta belum dicatat' : _agenda.peserta.join(', '),
                      key: const ValueKey('peserta'),
                    ),
                    if (_agenda.perihal != null) _BarisMeta(Icons.description_outlined, _agenda.perihal!),
                    if (_agenda.catatan != null && _agenda.catatan!.isNotEmpty) _BarisMeta(Icons.note_outlined, _agenda.catatan!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Status agenda', style: tipografi.titleSmall),
                        const Spacer(),
                        if (_menyimpan)
                          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Lencana(label: _agenda.statusLabel, kode: _agenda.status),
                    if (milikSendiri) ...[
                      const SizedBox(height: 14),
                      Text('Ubah status', style: tipografi.bodySmall),
                      const SizedBox(height: 8),
                      if (statusOtomatis.contains(_agenda.status))
                        // "Berjalan" dan "Selesai" diberikan server menurut waktu agenda, tidak dipilih dari HP.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status ${_agenda.statusLabel} berubah sendiri menurut waktu agenda. Kalau rapatnya berganti waktu, gunakan tombol ubah di atas.',
                              style: tipografi.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _menyimpan || _agenda.status == 'dibatalkan' ? null : () => _gantiStatus('dibatalkan'),
                              child: const Text('Batalkan agenda'),
                            ),
                          ],
                        )
                      else
                        Semantics(
                          label: 'Status agenda',
                          child: PilihStatusAgenda(
                            status: _agenda.status,
                            statusLabel: _agenda.statusLabel,
                            segmen: segmenStatus(_agenda),
                            dikirim: _menyimpan,
                            onPilih: _gantiStatus,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Alarm hanya untuk agenda yang akun ini ikut sebagai peserta/pembuat. Agenda pejabat
            // lain (tampil lewat toggle) tidak pernah dibunyikan di HP ini.
            if (_agenda.ikut)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(_pengingatAktif ? 'Pengingat alarm menyala' : 'Pengingat alarm mati'),
                      subtitle: Text(milikSendiri
                          ? 'Alarm pada HP ini · ${labelMenitPengingat(_menit)}'
                          : 'Kamu tercatat sebagai peserta — alarm dibunyikan di HP ini sebelum waktu mulai'),
                      trailing: Switch(value: _pengingatAktif, onChanged: _ubahPengingat),
                      onTap: () => _ubahPeng(!_pengingatAktif),
                    ),
                    if (_pengingatAktif)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PilihMenitPengingat(menit: _menit, onChanged: _ubahMenit),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Ganti berapa menit sebelum waktu mulai alarm dibunyikan, lalu pasang ulang alarmnya.
  Future<void> _ubahMenit(int menit) async {
    await Simpan().simpanPengingatMenit(_agenda.id, menit);
    if (!mounted) return;
    setState(() => _menit = menit);
    if (!_pengingatAktif) {
      _umpan('Alarm dipilih ${labelMenitPengingat(menit)}. Nyalakan pengingat untuk memasangnya.');
      return;
    }
    final galat = await widget.pengingat.pasang(_agenda, true, menit);
    if (!mounted) return;
    if (galat != null) {
      if (galat == pesanNotifikasiDiblokir) {
        _umpan(galat, gagal: true, labelAksi: 'Izinkan notifikasi',
            cobaLagi: () => widget.pengingat.bukaPengaturanNotifikasi());
        return;
      }
      _umpan(galat, gagal: true, cobaLagi: () => _ubahMenit(menit));
      return;
    }
    _umpan('Alarm dipasang ${labelMenitPengingat(menit)}.');
  }

  Future<void> _ubahPeng(bool aktif) async => _ubahPengingat(aktif);

  Future<void> _bukaUbah() async {
    final hasil = await Navigator.of(context).push<String>(
      rutePudarLewat(
        context,
        LayarAgendaBaru(
          api: widget.api,
          pengingat: widget.pengingat,
          agenda: _agenda,
          padaGalatPengingat: (pesan) {
            if (mounted) umpanPengingat(context, widget.pengingat, pesan);
          },
        ),
      ),
    );
    if (hasil == 'ubah') {
      final terbaru = await widget.api.agenda(_agenda.id);
      if (mounted) {
        setState(() => _agenda = terbaru);
        widget.padaBerubah();
      }
    }
  }
}

/// Keterangan agenda: ikon + teks, tanpa batas warna yang berarti.
class _BarisMeta extends StatelessWidget {
  final IconData ikon;
  final String teks;
  const _BarisMeta(this.ikon, this.teks, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(ikon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(teks, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Status yang berubah sendiri menurut waktu di server dan tidak dipilih dari HP.
const statusOtomatis = <String>{'berlangsung'};

/// Pilihan status manual untuk agenda ini: "Selesai" boleh dipilih sendiri sekaligus diberikan otomatis,
/// hanya "Berjalan" yang tidak ada di pilihan. Sebelum waktunya masih bisa "Belum"; waktu yang digeser
/// ditandai "dijadwalkan ulang" oleh server, jadi pilihan itu tetap ada untuk agenda yang sudah lewat.
List<ButtonSegment<String>> segmenStatus(Agenda a) {
  final segmen = <ButtonSegment<String>>[];
  if (a.mulai.isAfter(DateTime.now())) {
    segmen.add(ButtonSegment(value: 'terjadwal', label: const Text('Belum'), icon: const Icon(Icons.event_outlined)));
  }
  segmen.add(ButtonSegment(value: 'selesai', label: const Text('Selesai'), icon: const Icon(Icons.task_alt)));
  segmen.add(ButtonSegment(value: 'dijadwalkan_ulang', label: const Text('Jadwal ulang'), icon: const Icon(Icons.event_repeat)));
  segmen.add(ButtonSegment(value: 'dibatalkan', label: const Text('Batal'), icon: const Icon(Icons.event_busy_outlined)));
  return segmen;
}

/// Dropdown status agenda: pemicunya satu baris berisi status sekarang, pilihannya di dalam menu —
/// bentuk yang sama dengan dropdown menit pengingat. SegmentedButton tidak dipakai karena segmennya
/// dibagi sama rata dan memotong kata pada layar HP.
class PilihStatusAgenda extends StatelessWidget {
  final String status;
  final String statusLabel;
  final List<ButtonSegment<String>> segmen;
  final bool dikirim;
  final ValueChanged<String> onPilih;

  const PilihStatusAgenda({
    super.key,
    required this.status,
    required this.statusLabel,
    required this.segmen,
    required this.dikirim,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        for (final s in segmen)
          MenuItemButton(
            onPressed: dikirim ? null : () => onPilih(s.value),
            leadingIcon: status == s.value
                ? Icon(Icons.check, size: 18, color: skema.onSecondaryContainer)
                : (s.icon is Icon ? Icon((s.icon as Icon).icon, size: 18) : null),
            child: Text(s.label is Text ? ((s.label as Text).data ?? '') : ''),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        label: 'Ubah status agenda: $statusLabel',
        button: true,
        child: OutlinedButton(
          key: const ValueKey('status-rapat'),
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            foregroundColor: skema.onSurface,
            side: BorderSide(color: skema.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_outlined, size: 18, color: skema.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(child: Text(statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, color: skema.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
