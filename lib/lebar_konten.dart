import 'package:flutter/material.dart';

/// Lebar bacaan maksimum: pada HP penuh, pada tablet/foldable konten dipusatkan
/// supaya teks tidak melebar ke tepi jauh.
class LebarKonten extends StatelessWidget {
  final Widget child;
  const LebarKonten({super.key, required this.child});

  static const _maks = 720.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batasan) {
        if (batasan.maxWidth <= _maks) return child;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maks),
            child: child,
          ),
        );
      },
    );
  }
}
