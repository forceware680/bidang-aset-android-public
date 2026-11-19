import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_aset/agenda.dart';
import 'package:agenda_aset/format.dart';

Map<String, dynamic> jsonDasar(Object? peserta) => {
      'id': 'a1',
      'agenda_rapat': 'Rapat koordinasi',
      'mulai': '2026-11-10T09:00:00+07:00',
      'status_rapat': 'terjadwal',
      'status_label': 'Terjadwal',
      'sumber': 'surat masuk',
      'dapat_diubah': false,
      'dapat_dihapus': false,
      'peserta': peserta,
    };

void main() {
  test('nama yang hadir dibaca sebagai daftar', () {
    final agenda = Agenda.dariJson(jsonDasar(['Kabid Aset', 'Chairul Alim S, H']));
    expect(agenda.peserta, ['Kabid Aset', 'Chairul Alim S, H']);
  });

  test('nama yang mengandung koma tidak dipecah jadi dua orang', () {
    final agenda = Agenda.dariJson(jsonDasar(['Chairul Alim S, H']));
    expect(agenda.peserta, ['Chairul Alim S, H']);
  });

  test('agenda tanpa peserta tidak punya daftar', () {
    expect(Agenda.dariJson(jsonDasar([])).peserta, isEmpty);
    expect(Agenda.dariJson(jsonDasar(null)).peserta, isEmpty);
    expect(Agenda.dariJson(jsonDasar(['', '  '])).peserta, isEmpty);
  });

  test('daftar nama yang panjang dipotong dengan sisa yang jelas', () {
    expect(daftarNama(['A', 'B']), 'A, B');
    expect(daftarNama(['A', 'B', 'C']), 'A, B +1 lainnya');
    expect(daftarNama(['A', 'B', 'C', 'D', 'E'], batas: 3), 'A, B, C +2 lainnya');
    expect(daftarNama([]), '');
  });
}
