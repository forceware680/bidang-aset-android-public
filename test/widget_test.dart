import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_aset/main.dart';

void main() {
  testWidgets('Perangkat tanpa token membuka layar masuk', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const Aplikasi());
    await tester.pumpAndSettle();

    expect(find.text('Agenda Aset'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Perangkat tanpa token tetap minta masuk walau ada data lama', (tester) async {
    SharedPreferences.setMockInitialValues({'alamat_server': 'http://localhost:3000'});
    await tester.pumpWidget(const Aplikasi());
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
  });
}
