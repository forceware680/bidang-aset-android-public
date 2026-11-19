import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_aset/theme.dart';

String hex(Color c) =>
    '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';

double kontras(Color a, Color b) {
  double lin(double v) {
    final s = v / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
  double luminansi(Color c) => 0.2126 * lin(c.r * 255) + 0.7152 * lin(c.g * 255) + 0.0722 * lin(c.b * 255);
  final x = luminansi(a);
  final y = luminansi(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  final tema = temaAplikasi();
  final skema = tema.colorScheme;

  test('teks utama dan pendukung lolos 4.5:1 di atas permukaan', () {
    expect(kontras(skema.onSurface, skema.surface), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onSurfaceVariant, skema.surface), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onSurfaceVariant, skema.surfaceContainerLow), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onPrimary, skema.primary), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onPrimaryContainer, skema.primaryContainer), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onSecondaryContainer, skema.secondaryContainer), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onErrorContainer, skema.errorContainer), greaterThanOrEqualTo(4.5));
    expect(kontras(skema.onInverseSurface, skema.inverseSurface), greaterThanOrEqualTo(4.5));
  });

  test('batas isian dan teks tombol terlihat minimal 3:1', () {
    expect(kontras(skema.outline, skema.surface), greaterThanOrEqualTo(3.0));
    expect(kontras(skema.primary, skema.surfaceContainerLow), greaterThanOrEqualTo(3.0));
  });

  test('lencana status punya kontras teks 4.5:1 dan batas yang terlihat', () {
    final e = EkstensiWarana.gelap;
    for (final trio in [e.selesai, e.berjalan, e.bahaya, e.netral]) {
      expect(kontras(trio.teks, trio.latar), greaterThanOrEqualTo(4.5), reason: 'lencana ${hex(trio.teks)} di ${hex(trio.latar)}');
      expect(kontras(skema.outline, trio.latar), greaterThanOrEqualTo(3.0), reason: 'batas lencana di ${hex(trio.latar)}');
    }
    expect(ikonStatus('selesai'), isNot(ikonStatus('dibatalkan')));
  });

  test('skala tipografi tidak di bawah 11px dan skala bentuk M3', () {
    final t = tema.textTheme;
    for (final gaya in [t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall]) {
      expect(gaya!.fontSize!, greaterThanOrEqualTo(11));
    }
    expect(kecil, 8);
    expect(sedang, 12);
    expect(besar, 16);
    expect(ekstraBesar, 28);
  });

  test('sasaran sentuh minimal 48px', () {
    final ukuran = tema.segmentedButtonTheme.style?.minimumSize?.resolve(const <WidgetState>{});
    expect(ukuran!.height, greaterThanOrEqualTo(48));
    expect(tema.navigationBarTheme.height, greaterThanOrEqualTo(64));
    expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}
