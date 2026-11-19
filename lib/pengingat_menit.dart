import 'package:flutter/material.dart';

/// Pilihan cepat berapa menit sebelum waktu mulai alarm dibunyikan. 0 berarti tepat pada waktu mulai.
const pilihanMenitPengingat = <int>[0, 5, 15, 30, 60, 120];

/// Tulisannya seperti dibaca petugas: "15 menit sebelum waktu mulai", "Tepat saat waktu mulai".
String labelMenitPengingat(int menit) {
  if (menit == 0) return 'Tepat saat waktu mulai';
  if (menit >= 60) {
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    return sisa == 0
        ? '$jam jam sebelum waktu mulai'
        : '$jam jam $sisa menit sebelum waktu mulai';
  }
  return '$menit menit sebelum waktu mulai';
}

/// Batas menit pengingat yang masih masuk akal untuk agenda bidang aset.
const menitPengingatMin = 0;
const menitPengingatMax = 1440;

/// Tombol yang membuka daftar menit pengingat; pilihan "Menit sendiri" membuka kotak angka.
class PilihMenitPengingat extends StatelessWidget {
  final int menit;
  final ValueChanged<int> onChanged;
  const PilihMenitPengingat({super.key, required this.menit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        for (final m in pilihanMenitPengingat)
          MenuItemButton(
            onPressed: () => onChanged(m),
            child: Text(labelMenitPengingat(m)),
          ),
        MenuItemButton(
          onPressed: () async {
            final angka = await _isiMenitSendiri(context);
            if (angka != null) onChanged(angka);
          },
          child: const Text('Menit sendiri...'),
        ),
      ],
      builder: (context, controller, child) => Semantics(
        label: 'Alarm: ${labelMenitPengingat(menit)}',
        button: true,
        child: OutlinedButton(
          key: const ValueKey('pilih-menit'),
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            foregroundColor: skema.onSurface,
            side: BorderSide(color: skema.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_outlined, size: 18, color: skema.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(child: Text(labelMenitPengingat(menit), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, color: skema.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _isiMenitSendiri(BuildContext context) => showDialog<int>(
    context: context,
    builder: (dialogContext) => _DialogMenit(menit: menit),
  );
}

/// Kotak angka menit pengingat. Kontroler teks dibuang bersama layarnya.
class _DialogMenit extends StatefulWidget {
  final int menit;
  const _DialogMenit({required this.menit});

  @override
  State<_DialogMenit> createState() => _DialogMenitState();
}

class _DialogMenitState extends State<_DialogMenit> {
  late final TextEditingController _kotak = TextEditingController(text: '${widget.menit}');
  String? _galat;

  @override
  void dispose() {
    _kotak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tipografi = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Menit sendiri'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Berapa menit sebelum waktu mulai alarm dibunyikan.', style: tipografi.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('menit-sendiri'),
            controller: _kotak,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => setState(() => _galat = null),
            decoration: InputDecoration(
              labelText: 'Menit sebelum waktu mulai',
              helperText: 'Boleh $menitPengingatMin sampai $menitPengingatMax menit. 0 berarti tepat saat waktu mulai.',
              errorText: _galat,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final angka = int.tryParse(_kotak.text.trim());
            if (angka == null || angka < menitPengingatMin || angka > menitPengingatMax) {
              setState(() => _galat = 'Isi angka antara $menitPengingatMin dan $menitPengingatMax.');
              return;
            }
            Navigator.of(context).pop(angka);
          },
          child: const Text('Pasang alarm'),
        ),
      ],
    );
  }
}
