import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_aset/agenda.dart';
import 'package:agenda_aset/api.dart';
import 'package:agenda_aset/layar_agenda_baru.dart';
import 'package:agenda_aset/pengingat.dart';
import 'package:agenda_aset/theme.dart';

class _ApiPura extends Api {
  _ApiPura() : super(baseUrl: 'http://localhost:3000', token: 'token-uji');

  @override
  Future<({String? id, String pesan})> buatAgenda({
    required String judul,
    required String mulai,
    String? selesai,
    String? tempat,
    String? penyelenggara,
    String? catatan,
  }) async {
    return (id: 'a1', pesan: 'Agenda tersimpan');
  }
}

/// Alarm yang lambat — layar harus tetap kembali setelah agenda tersimpan.
class _PengingatLambat extends Pengingat {
  @override
  Future<String?> pasang(Agenda agenda, bool aktif, int menit) async {
    await Future.delayed(const Duration(seconds: 5));
    return null;
  }
}

class _PengingatGagal extends Pengingat {
  @override
  Future<String?> pasang(Agenda agenda, bool aktif, int menit) async => pesanNotifikasiDiblokir;
}

/// Layar agenda di dalam Navigator, dengan setelan bahasa yang sama seperti aplikasi.
Widget _layar(Widget Function(BuildContext ctx) isi) => MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (r) => MaterialPageRoute(
            settings: r,
            builder: (ctx) => Scaffold(body: isi(ctx)),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  testWidgets('menyimpan agenda tidak menggantung saat alarm lambat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final galatPengingat = <String>[];

    await tester.pumpWidget(_layar(
      (_) => LayarAgendaBaru(
        api: _ApiPura(),
        pengingat: _PengingatLambat(),
        padaGalatPengingat: (pesan) => galatPengingat.add(pesan),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Rapat uji kembali');
    await tester.tap(find.text('Simpan agenda'));
    // Satu frame cukup: tidak menunggu alarm selesai.
    await tester.pump();

    expect(find.text('Simpan agenda'), findsNothing);
    // Kembali setelah simpan bukan "batal": dialog buang isian tidak boleh muncul.
    expect(find.text('Buang'), findsNothing);
    expect(galatPengingat, isEmpty);

    // Alarm yang lambat selesai belakangan tanpa menahan layar.
    await tester.pump(const Duration(seconds: 6));
    expect(galatPengingat, isEmpty);
  });

  testWidgets('alarm yang gagal dilaporkan ke layar sebelumnya', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final pengingat = _PengingatGagal();
    await tester.pumpWidget(_layar(
      (ctx) => LayarAgendaBaru(
        api: _ApiPura(),
        pengingat: pengingat,
        padaGalatPengingat: (pesan) => umpanPengingat(ctx, pengingat, pesan),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Rapat uji galat');
    await tester.tap(find.text('Simpan agenda'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(pesanNotifikasiDiblokir), findsOneWidget);
  });
}
