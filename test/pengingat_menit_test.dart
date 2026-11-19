import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_aset/pengingat.dart';
import 'package:agenda_aset/pengingat_menit.dart';

void main() {
  test('tulisan menit pengingat terbaca seperti bahasa petugas', () {
    expect(labelMenitPengingat(0), 'Tepat saat waktu mulai');
    expect(labelMenitPengingat(5), '5 menit sebelum waktu mulai');
    expect(labelMenitPengingat(15), '15 menit sebelum waktu mulai');
    expect(labelMenitPengingat(60), '1 jam sebelum waktu mulai');
    expect(labelMenitPengingat(90), '1 jam 30 menit sebelum waktu mulai');
    expect(labelMenitPengingat(20), '20 menit sebelum waktu mulai');
  });

  test('waktu alarm dihitung dari menit yang dipilih sendiri', () {
    final mulai = DateTime(2026, 11, 8, 10, 0);
    expect(waktuAlarm(mulai, 0), mulai);
    expect(waktuAlarm(mulai, 15), DateTime(2026, 11, 8, 9, 45));
    expect(waktuAlarm(mulai, 120), DateTime(2026, 11, 8, 8, 0));
  });

  testWidgets('pilihan menit membuka daftar dan menerima pilihan', (tester) async {
    int dipilih = 15;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PilihMenitPengingat(
          menit: dipilih,
          onChanged: (menit) => dipilih = menit,
        ),
      ),
    ));

    expect(find.text('15 menit sebelum waktu mulai'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pilih-menit')));
    await tester.pumpAndSettle();

    expect(find.text('Tepat saat waktu mulai'), findsOneWidget);
    expect(find.text('30 menit sebelum waktu mulai'), findsOneWidget);
    expect(find.text('Menit sendiri...'), findsOneWidget);

    await tester.tap(find.text('30 menit sebelum waktu mulai'));
    await tester.pumpAndSettle();
    expect(dipilih, 30);
  });

  testWidgets('menit sendiri menerima angka di luar daftar pilihan', (tester) async {
    int dipilih = 15;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PilihMenitPengingat(
          menit: dipilih,
          onChanged: (menit) => dipilih = menit,
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('pilih-menit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menit sendiri...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('menit-sendiri')), '7');
    await tester.tap(find.text('Pasang alarm'));
    await tester.pumpAndSettle();
    expect(dipilih, 7);
  });

  testWidgets('menit sendiri menolak angka di luar batas', (tester) async {
    int dipilih = 15;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PilihMenitPengingat(
          menit: dipilih,
          onChanged: (menit) => dipilih = menit,
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('pilih-menit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menit sendiri...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('menit-sendiri')), '2000');
    await tester.tap(find.text('Pasang alarm'));
    await tester.pumpAndSettle();

    expect(find.text('Isi angka antara 0 dan 1440.'), findsOneWidget);
    expect(dipilih, 15);
  });
}
