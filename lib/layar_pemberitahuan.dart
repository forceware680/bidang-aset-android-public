import 'package:flutter/material.dart';

import 'agenda.dart';
import 'format.dart';
import 'kalender.dart';
import 'lebar_konten.dart';

/// Lonceng header: daftar pemberitahuan peserta yang belum dibaca. Setiap baris menyebut siapa
/// yang menambahkan, agenda apa, dan jam agendanya; baris yang diketuk membuka detail agendanya
/// dan dianggap dibaca. Pemberitahuan yang sama juga dibunyikan sebagai notifikasi HP.
class LayarPemberitahuan extends StatelessWidget {
  final List<Pemberitahuan> daftar;
  final void Function(Pemberitahuan) padaBukaItem;
  final VoidCallback padaBacaSemua;
  const LayarPemberitahuan({super.key, required this.daftar, required this.padaBukaItem, required this.padaBacaSemua});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final isi = daftar.isEmpty
        ? const KartuKosong(
            gambar: 'assets/logo.png',
            judul: 'Belum ada pemberitahuan peserta.',
            panduan: 'Kalau seseorang menambahkan kamu sebagai peserta sebuah agenda dari web, pemberitahuannya muncul di sini dan di notifikasi HP.',
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Menunggu dibaca', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: skema.onSurfaceVariant)),
              ),
              for (final p in daftar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BarisPemberitahuan(pemberitahuan: p, padaBuka: () => padaBukaItem(p)),
                ),
            ],
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemberitahuan peserta'),
        actions: [
          if (daftar.isNotEmpty)
            TextButton(onPressed: padaBacaSemua, child: const Text('Tandai semua dibaca')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LebarKonten(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [isi],
          ),
        ),
      ),
    );
  }
}

/// Satu pemberitahuan sebagai kartu: judul singkat, keterangan lengkap siapa–apa–kapan.
class _BarisPemberitahuan extends StatelessWidget {
  final Pemberitahuan pemberitahuan;
  final VoidCallback padaBuka;
  const _BarisPemberitahuan({required this.pemberitahuan, required this.padaBuka});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1_outlined),
        title: Text('Ditambahkan sebagai peserta', style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          '${pemberitahuan.oleh} menambahkan kamu pada agenda ${pemberitahuan.agenda}\n${tanggalPendek(pemberitahuan.mulai)} ${jamIndo(pemberitahuan.mulai)}',
        ),
        trailing: Text(
          'ditambah ${jamIndo(pemberitahuan.padaUtc.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
        onTap: padaBuka,
      ),
    );
  }
}
