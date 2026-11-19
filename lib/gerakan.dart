import 'package:flutter/material.dart';

import 'theme.dart';

/// Transisi halaman Material 3 "fade through": halaman baru pudar masuk sambil sedikit mengecil
/// dari 0.94 ke penuh. Durasi mengikuti pengaturan gerakan (gerakkan dikurangi = nol).
PageRoute<T> rutePudarLewat<T>(BuildContext context, Widget halaman) {
  final durasi = durasiGerakan(context);
  return PageRouteBuilder<T>(
    transitionDuration: durasi,
    reverseTransitionDuration: durasi,
    pageBuilder: (_, _, _) => halaman,
    transitionsBuilder: (context, masuk, _, anak) {
      final kurva = Curves.easeOutCubic;
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: masuk, curve: kurva)),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(CurvedAnimation(parent: masuk, curve: kurva)),
          child: anak,
        ),
      );
    },
  );
}
