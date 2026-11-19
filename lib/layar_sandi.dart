import 'package:flutter/material.dart';

import 'api.dart';
import 'lebar_konten.dart';
import 'theme.dart';

/// Ganti kata sandi akun. Aturan sama dengan aplikasi web: minimal 8 karakter dan dikonfirmasi.
class LayarSandi extends StatefulWidget {
  final Api api;
  const LayarSandi({super.key, required this.api});

  @override
  State<LayarSandi> createState() => _LayarSandiState();
}

class _LayarSandiState extends State<LayarSandi> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _dilihat = false;
  bool _menyimpan = false;
  String? _galatBaru;
  String? _galatKonfirmasi;
  String? _galatLama;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final lama = _lama.text;
    final baru = _baru.text;
    final konfirmasi = _konfirmasi.text;
    setState(() {
      _galatLama = lama.isEmpty ? 'Kata sandi sekarang harus diisi.' : null;
      _galatBaru = baru.length < 8 ? 'Kata sandi baru minimal 8 karakter.' : null;
      _galatKonfirmasi = baru != konfirmasi ? 'Konfirmasi harus sama dengan kata sandi baru.' : null;
    });
    if (_galatLama != null || _galatBaru != null || _galatKonfirmasi != null) return;

    setState(() => _menyimpan = true);
    try {
      final pesan = await widget.api.gantiSandi(lama: lama, baru: baru, konfirmasi: konfirmasi);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      Navigator.of(context).pop();
    } on Galat catch (g) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      if (g.pesan.toLowerCase().contains('sandi lama')) {
        setState(() => _galatLama = g.pesan);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(g.pesan), action: SnackBarAction(label: 'Coba lagi', onPressed: _simpan)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubah kata sandi'),
        leading: IconButton(
          tooltip: 'Batal, kembali ke akun',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LebarKonten(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Card(
              color: skema.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: skema.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kata sandi baru minimal 8 karakter.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: skema.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _IsianSandi(
              key: const ValueKey('sandi-lama'),
              controller: _lama,
              label: 'Kata sandi sekarang',
              dilihat: _dilihat,
              galat: _galatLama,
              padaUbah: () => setState(() => _galatLama = null),
              padaToggle: () => setState(() => _dilihat = !_dilihat),
            ),
            const SizedBox(height: 16),
            _IsianSandi(
              key: const ValueKey('sandi-baru'),
              controller: _baru,
              label: 'Kata sandi baru',
              dilihat: _dilihat,
              galat: _galatBaru,
              padaUbah: () => setState(() => _galatBaru = null),
              padaToggle: () => setState(() => _dilihat = !_dilihat),
            ),
            const SizedBox(height: 16),
            _IsianSandi(
              key: const ValueKey('sandi-konfirmasi'),
              controller: _konfirmasi,
              label: 'Konfirmasi kata sandi baru',
              dilihat: _dilihat,
              galat: _galatKonfirmasi,
              padaUbah: () => setState(() => _galatKonfirmasi = null),
              padaToggle: () => setState(() => _dilihat = !_dilihat),
            ),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: skema.surfaceContainerLow,
            border: Border(top: BorderSide(color: skema.outlineVariant)),
          ),
          child: LebarKonten(
            child: Row(
              children: [
                TextButton(onPressed: _menyimpan ? null : () => Navigator.of(context).pop(), child: const Text('Batal')),
                const Spacer(),
                TombolUtama(
                  key: const ValueKey('simpan-sandi'),
                  label: 'Simpan',
                  labelMemuat: 'Mengubah sandi…',
                  ikon: Icons.check_circle_outline,
                  sedangMemuat: _menyimpan,
                  onTap: _simpan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IsianSandi extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool dilihat;
  final String? galat;
  final VoidCallback padaUbah;
  final VoidCallback padaToggle;
  const _IsianSandi({
    super.key,
    required this.controller,
    required this.label,
    required this.dilihat,
    required this.galat,
    required this.padaUbah,
    required this.padaToggle,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: !dilihat,
      onChanged: (_) => padaUbah(),
      decoration: InputDecoration(
        labelText: label,
        errorText: galat,
        suffixIcon: IconButton(
          tooltip: dilihat ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
          icon: Icon(dilihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: skema.onSurfaceVariant),
          onPressed: padaToggle,
        ),
      ),
    );
  }
}
