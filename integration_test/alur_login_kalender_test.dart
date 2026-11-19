import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_aset/main.dart';

/// Akun uji dikirim lewat --dart-define supaya kata sandi tidak masuk ke berkas git.
const akunUji = String.fromEnvironment('UJI_EMAIL');
const sandiUji = String.fromEnvironment('UJI_SANDI');

/// Tunggu sampai penentu muncul. Loading dan skeleton beranimasi terus, jadi tidak
/// pakai pumpAndSettle; tiap iterasi memberi waktu nyata supaya jaringan jalan.
Future<void> tunggu(WidgetTester tester, bool Function() ada, {int detik = 40, String sebab = 'tidak tampil'}) async {
  for (var i = 0; i < detik * 2; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ada()) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final terlihat = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((s) => s.isNotEmpty).join(' | ');
  fail('$sebab (setelah $detik detik). Yang tampil di layar: $terlihat');
}

Finder barisAgenda() => find.byWidgetPredicate(
      (widget) => widget is Card && widget.key is ValueKey<String> && (widget.key as ValueKey<String>).value.startsWith('agenda-'),
    );

/// Masuk dengan akun uji lalu buka daftar agenda 30 hari. Setiap uji memanggil ini karena
/// `testWidgets` membangun ulang aplikasi dari awal.
Future<void> masukKeKalender(WidgetTester tester) async {
  await initializeDateFormatting('id');
  final preferensi = await SharedPreferences.getInstance();
  await preferensi.clear();

  await tester.pumpWidget(Aplikasi());
  await tunggu(tester, () => find.byKey(const ValueKey('masuk')).evaluate().isNotEmpty, sebab: 'layar masuk tidak muncul');

  await tester.enterText(find.byKey(const ValueKey('email')), akunUji);
  await tester.enterText(find.byKey(const ValueKey('sandi')), sandiUji);
  await tester.tap(find.byKey(const ValueKey('masuk')));
  await tester.pump();
  await tunggu(tester, () => find.text('Hari ini').evaluate().isNotEmpty, sebab: 'kalender tidak terbuka setelah masuk');

  await tester.tap(find.text('Mendatang'));
  await tester.pump();
  await tunggu(tester, () => find.text('30 hari').evaluate().isNotEmpty, sebab: 'pilihan rentang tidak muncul');
  await tester.tap(find.text('30 hari'));
  await tester.pump();
  await tunggu(
    tester,
    () => barisAgenda().evaluate().isNotEmpty || find.text('Belum ada agenda bidang pada rentang ini.').evaluate().isNotEmpty,
    sebab: 'daftar agenda 30 hari tidak tampil',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('masuk lalu daftar agenda dan nama yang hadir terbaca', (tester) async {
    await masukKeKalender(tester);

    final adaNamaHadir = find.textContaining('Diikuti').evaluate().isNotEmpty;

    if (barisAgenda().evaluate().isEmpty) return;

    // Agenda pertama tidak selalu punya peserta; kalau ada baris yang menampilkan nama, pilih itu.
    final baris = adaNamaHadir ? find.descendant(of: barisAgenda(), matching: find.textContaining('Diikuti')).first : barisAgenda().first;
    await tester.tap(baris);
    await tester.pump();
    await tunggu(tester, () => find.byKey(const ValueKey('peserta')).evaluate().isNotEmpty, sebab: 'baris peserta tidak muncul di detail');

    final teks = tester
        .widget<Text>(find.descendant(of: find.byKey(const ValueKey('peserta')), matching: find.byType(Text)))
        .data;
    expect(teks, isNotNull);
    if (adaNamaHadir) {
      expect(teks, isNot('Peserta belum dicatat'));
      expect(teks!.trim().isNotEmpty, isTrue);
    } else {
      expect(teks ?? '', isNotEmpty);
    }
    await tester.tap(find.byTooltip('Kembali ke kalender'));
    await tester.pump();
  }, skip: akunUji.isEmpty || sandiUji.isEmpty);

  testWidgets('pilihan status di detail hanya manual: tidak ada Berjalan', (tester) async {
    if (akunUji.isEmpty || sandiUji.isEmpty) return;
    await masukKeKalender(tester);
    if (barisAgenda().evaluate().isEmpty) return;

    final barisBerjalan = find.descendant(of: barisAgenda(), matching: find.text('Berlangsung')).first;
    final target = barisBerjalan.evaluate().isNotEmpty ? barisBerjalan : barisAgenda().first;
    await tester.tap(target);
    await tester.pump();
    await tunggu(
      tester,
      () => find.byKey(const ValueKey('status-rapat')).evaluate().isNotEmpty || find.text('Batalkan agenda').evaluate().isNotEmpty,
      sebab: 'pilihan status atau tombol batal tidak tampil',
    );

    if (find.text('Batalkan agenda').evaluate().isNotEmpty) {
      // Agenda berstatus otomatis: tidak ada pilihan status, hanya tombol batal.
      expect(find.byKey(const ValueKey('status-rapat')), findsNothing);
      expect(find.textContaining('berubah sendiri menurut waktu'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali ke kalender'));
      await tester.pump();
      return;
    }

    // Dropdown status: pilihannya baru muncul setelah pemicunya dibuka.
    await tester.tap(find.byKey(const ValueKey('status-rapat')));
    await tester.pumpAndSettle();
    final label = find
        .byType(MenuItemButton)
        .evaluate()
        .map((e) => (e.widget as MenuItemButton).child as Text)
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(label, contains('Selesai'));
    expect(label, contains('Jadwal ulang'));
    expect(label, contains('Batal'));
    expect(label, isNot(contains('Berjalan')));
    await tester.tap(find.byTooltip('Kembali ke kalender'));
    await tester.pump();
  }, skip: akunUji.isEmpty || sandiUji.isEmpty);
}
