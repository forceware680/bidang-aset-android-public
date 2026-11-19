import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_aset/agenda.dart';
import 'package:agenda_aset/layar_detail.dart';

Agenda _agenda({required String status, required DateTime mulai}) => Agenda(
      id: 'a1',
      judul: 'Rapat koordinasi',
      mulai: mulai,
      status: status,
      statusLabel: status == 'berlangsung' ? 'Berlangsung' : 'Terjadwal',
      sumber: 'agenda sendiri',
      dapatDiubah: true,
      dapatDihapus: true,
    );

void main() {
  test('agenda yang belum waktunya: Belum, Selesai, Jadwal ulang, Batal', () {
    final nilai = segmenStatus(_agenda(status: 'terjadwal', mulai: DateTime.now().add(const Duration(hours: 2))))
        .map((s) => s.value)
        .toList();
    expect(nilai, ['terjadwal', 'selesai', 'dijadwalkan_ulang', 'dibatalkan']);
  });

  test('agenda yang waktunya sudah tiba: Selesai, Jadwal ulang, Batal', () {
    final nilai = segmenStatus(_agenda(status: 'terjadwal', mulai: DateTime.now().subtract(const Duration(hours: 2))))
        .map((s) => s.value)
        .toList();
    expect(nilai, ['selesai', 'dijadwalkan_ulang', 'dibatalkan']);
    expect(nilai, isNot(contains('berlangsung')));
  });

  test('hanya berlangsung yang tidak dipilih dari HP', () {
    expect(statusOtomatis, {'berlangsung'});
  });
}
