import 'package:flutter/material.dart';

import 'package:device_info_plus/device_info_plus.dart';

import 'api.dart';
import 'agenda.dart';
import 'konfigurasi.dart';
import 'lebar_konten.dart';
import 'simpan.dart';
import 'theme.dart';

/// Layar masuk: email dan kata sandi akun petugas, sama seperti aplikasi web.
class LayarMasuk extends StatefulWidget {
  final void Function(Api api, Sesi sesi) padaMasuk;
  /// Banner di atas logo saat sesi keluar otomatis (token dicabut dari web atau kedaluwarsa).
  final String? pesanKeluar;
  const LayarMasuk({super.key, required this.padaMasuk, this.pesanKeluar});

  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  bool _menyimpan = false;
  bool _dilihat = false;
  String? _galatEmail;
  String? _galatSandi;
  String? _pesanServer;

  @override
  void dispose() {
    _email.dispose();
    _sandi.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    final email = _email.text.trim();
    final sandi = _sandi.text;
    setState(() {
      _galatEmail = email.isEmpty ? 'Email harus diisi.' : null;
      _galatSandi = sandi.isEmpty ? 'Kata sandi harus diisi.' : null;
      _pesanServer = null;
    });
    if (_galatEmail != null || _galatSandi != null) return;

    setState(() => _menyimpan = true);
    try {
      // Nama HP dikirim supaya administrator bisa melihat perangkat mana yang masuk.
      String? namaPerangkat;
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        namaPerangkat = '${info.brand} ${info.model}'.trim();
        if (namaPerangkat.length > 60) namaPerangkat = namaPerangkat.substring(0, 60);
      } catch (_) {}
      final jawaban = await Api.masuk(baseUrl: baseUrl, email: email, password: sandi, perangkat: namaPerangkat);
      final token = jawaban['token'] as String;
      final api = Api(baseUrl: baseUrl, token: token);
      final sesi = await api.sesi();
      await Simpan().simpanSesi(token: token, nama: sesi.nama, email: sesi.email, peran: sesi.peran);
      widget.padaMasuk(api, sesi);
    } on Galat catch (g) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _pesanServer = g.pesan;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tipografi = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241A15), kanvas],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GridLatar(garis: skema.onSurface)),
                ),
              ),
              LebarKonten(
                child: LayoutBuilder(
                  builder: (context, batas) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: batas.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.pesanKeluar != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: skema.surfaceContainerHighest,
                                borderRadius: bentuk(besar),
                                border: Border.all(color: skema.outline),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, size: 20, color: skema.onSurfaceVariant),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.pesanKeluar!,
                                      style: tipografi.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Column(
                            children: [
                              Image.asset('assets/logo.png', width: 84, height: 84),
                              const SizedBox(height: 6),
                              Text('Agenda Aset', style: tipografi.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Catatan Agenda Pejabat Bidang Aset', style: tipografi.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: skema.surfaceContainerLow,
                              borderRadius: bentuk(ekstraBesar),
                              border: Border.all(color: skema.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 3,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: kar,
                                    borderRadius: pil(),
                                  ),
                                ),
                                TextField(
                                  key: const ValueKey('email'),
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  onChanged: (_) => setState(() => _galatEmail = null),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    errorText: _galatEmail,
                                    prefixIcon: Icon(Icons.email_outlined, size: 20, color: skema.onSurfaceVariant),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  key: const ValueKey('sandi'),
                                  controller: _sandi,
                                  obscureText: !_dilihat,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => _masuk(),
                                  onChanged: (_) => setState(() => _galatSandi = null),
                                  decoration: InputDecoration(
                                    labelText: 'Kata sandi',
                                    errorText: _galatSandi,
                                    prefixIcon: Icon(Icons.lock_outline, size: 20, color: skema.onSurfaceVariant),
                                    suffixIcon: IconButton(
                                      tooltip: _dilihat ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
                                      icon: Icon(_dilihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: skema.onSurfaceVariant),
                                      onPressed: () => setState(() => _dilihat = !_dilihat),
                                    ),
                                  ),
                                ),
                                if (_pesanServer != null) Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _Galat(pesan: _pesanServer!, cobaLagi: _masuk),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: TombolUtama(
                                    key: const ValueKey('masuk'),
                                    label: 'Masuk',
                                    labelMemuat: 'Menghubungi server…',
                                    ikon: Icons.login_outlined,
                                    sedangMemuat: _menyimpan,
                                    onTap: _masuk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Text(
                            'Versi Aplikasi $versiApp',
                            textAlign: TextAlign.center,
                            style: tipografi.labelSmall?.copyWith(color: skema.onSurfaceVariant.withValues(alpha: 0.75)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '© 2026 Bidang Aset',
                            textAlign: TextAlign.center,
                            style: tipografi.labelSmall?.copyWith(color: skema.onSurfaceVariant.withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid latar ala Vercel: garis halus yang memudar radial (kuat di tengah, lenyap
/// menuju tepi dan dasar). Digambar pada layer terpisah agar gradient dasar utuh.
class _GridLatar extends CustomPainter {
  final Color garis;

  _GridLatar({required this.garis});

  @override
  void paint(Canvas canvas, Size size) {
    const jarak = 30.0;

    final pensil = Paint()
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += jarak) {
      pensil.color = garis.withValues(alpha: 0.10);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pensil);
    }
    for (double y = 0; y <= size.height; y += jarak) {
      pensil.color = garis.withValues(alpha: 0.10);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pensil);
    }

    // Mask radial: grid kuat di tengah, lenyap menuju tepi dan dasar.
    final mask = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = RadialGradient(
        center: const Alignment(0, -0.35),
        radius: 0.85,
        colors: const [Color(0xFF000000), Color(0x00000000)],
        stops: const [0.15, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), mask);
  }

  @override
  bool shouldRepaint(_GridLatar oldDelegate) => oldDelegate.garis != garis;
}

/// Jawaban server yang tidak bisa diperbaiki sendiri: sebabnya apa, aksi berikutnya apa.
class _Galat extends StatelessWidget {
  final String pesan;
  final VoidCallback cobaLagi;
  const _Galat({required this.pesan, required this.cobaLagi});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
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
                  pesan.length > 120 ? 'Koneksi ke server bermasalah.' : pesan,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: skema.onErrorContainer),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: cobaLagi,
                  style: ButtonStyle(foregroundColor: WidgetStateProperty.all(skema.onErrorContainer)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
