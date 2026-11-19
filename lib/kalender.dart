import 'package:flutter/material.dart';

import 'agenda.dart';
import 'api.dart';
import 'format.dart';
import 'theme.dart';

/// Baris agenda: Material 3 list item. Bagian yang menentukan langkah berikutnya
/// (judul dan status) paling depan, keterangan pendukung di bawahnya.
class BarisAgenda extends StatelessWidget {
  final Agenda agenda;
  final VoidCallback onTap;
  const BarisAgenda({super.key, required this.agenda, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tipografi = Theme.of(context).textTheme;
    final waktu = rentangWaktu(agenda.mulai, agenda.selesai);
    final tempat = agenda.tempat ?? 'Tempat belum ditentukan';
    final sumber = agenda.pejabatLain
        ? 'Agenda ${agenda.dibuatOleh ?? 'pejabat lain'} · baca saja'
        : agenda.sumber == 'surat masuk'
            ? 'Dari surat ${agenda.nomorSurat ?? '-'}'
            : 'Agenda kamu';

    return Card(
      key: ValueKey('agenda-${agenda.id}'),
      child: ListTile(
        onTap: onTap,
        leading: _KotakTanggal(agenda: agenda),
        title: Text(agenda.judul, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$waktu • $tempat', maxLines: 2, overflow: TextOverflow.ellipsis),
            if (agenda.peserta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Diikuti ${daftarNama(agenda.peserta)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tipografi.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 2),
            Text(sumber, style: tipografi.bodySmall),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lencana(label: agenda.statusLabel, kode: agenda.status),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

/// Penanda tanggal pada pinggir baris: angka hari + bulan, bukan warna.
class _KotakTanggal extends StatelessWidget {
  final Agenda agenda;
  const _KotakTanggal({required this.agenda});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tipografi = Theme.of(context).textTheme;
    // Tanggal dibaca sebagai waktu setempat perangkat (WIB), bukan sebagai UTC dari jawaban server.
    final tanggal = agenda.mulai.toLocal();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: skema.surfaceContainerHigh,
        borderRadius: bentuk(kecil),
        border: Border.all(color: skema.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tanggal.day.toString(),
            style: tipografi.titleMedium?.copyWith(color: skema.onSurface),
          ),
          Text(
            namaBulan(tanggal).substring(0, 3),
            style: tipografi.labelSmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Keadaan kosong: menyebut apa yang kosong dan satu tindakan yang mengisinya.
class KartuKosong extends StatelessWidget {
  final String judul;
  final String panduan;
  final String? aksiLabel;
  final IconData? aksiIkon;
  final VoidCallback? onTap;
  /// Gambar besar tanpa kotak (mis. logo Bidang Aset untuk lonceng); bila null pakai ikon dalam kotak.
  final String? gambar;
  const KartuKosong({
    super.key,
    required this.judul,
    required this.panduan,
    this.aksiLabel,
    this.aksiIkon,
    this.onTap,
    this.gambar,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tipografi = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          gambar == null
              ? Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: skema.secondaryContainer,
                    borderRadius: bentuk(besar),
                  ),
                  child: Icon(Icons.event_busy_outlined, size: 28, color: skema.onSecondaryContainer),
                )
              : Image.asset(gambar!, width: 76, height: 76),
          const SizedBox(height: 16),
          Text(judul, style: tipografi.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(panduan, textAlign: TextAlign.center, style: tipografi.bodyMedium),
          if (aksiLabel != null && onTap != null) ...[
            const SizedBox(height: 16),
            TombolUtama(label: aksiLabel!, ikon: aksiIkon ?? Icons.add, sekunder: true, onTap: onTap),
          ],
        ],
      ),
    );
  }
}

/// Keadaan gagal: sebabnya apa, tindakan berikutnya apa.
class KartuGagal extends StatelessWidget {
  final String pesan;
  final VoidCallback cobaLagi;
  const KartuGagal({super.key, required this.pesan, required this.cobaLagi});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tipografi = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: skema.errorContainer,
                  borderRadius: bentuk(kecil),
                ),
                child: Icon(Icons.wifi_off_rounded, size: 22, color: skema.onErrorContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pesan.length > 120 ? 'Koneksi ke server gagal' : pesan,
                  style: tipografi.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Periksa jaringan HP kamu lalu coba lagi. Agenda terakhir masih tersimpan di HP ini.',
            style: tipografi.bodyMedium,
          ),
          const SizedBox(height: 14),
          TombolUtama(label: 'Coba lagi', ikon: Icons.refresh_rounded, onTap: cobaLagi),
        ],
      ),
    );
  }
}

/// Baris bayangan selagi daftar agenda dimuat.
class BayanganAgenda extends StatelessWidget {
  const BayanganAgenda({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    Widget batang(double lebar) => Container(
          width: lebar,
          height: 12,
          decoration: BoxDecoration(
            color: skema.surfaceContainerHighest,
            borderRadius: bentuk(ekstraKecil),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: skema.surfaceContainerHighest,
              borderRadius: bentuk(kecil),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                batang(220),
                const SizedBox(height: 10),
                batang(140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pembaca kalender: satu halaman untuk hari ini, satu untuk hari mendatang.
class PembacaKalender {
  final Api api;
  PembacaKalender(this.api);

  Future<List<Agenda>> hariIni() => api.kalender(hari: tanggalApi(DateTime.now()));

  Future<List<Agenda>> mendatang({int hari = 30}) {
    final sekarang = DateTime.now();
    return api.kalender(mulai: tanggalApi(sekarang), selesai: tanggalApi(sekarang.add(Duration(days: hari))));
  }

  /// Agenda dalam rentang tanggal pilihan user (inklusif), untuk menu rentang custom.
  Future<List<Agenda>> rentang(DateTime mulai, DateTime selesai) =>
      api.kalender(mulai: tanggalApi(mulai), selesai: tanggalApi(selesai));
}
