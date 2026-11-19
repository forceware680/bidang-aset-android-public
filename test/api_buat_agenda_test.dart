import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:agenda_aset/api.dart';

/// Klien palsu yang menjawab persis seperti `POST /api/agenda` di aplikasi web.
class _KlienPura extends http.BaseClient {
  final Map<String, dynamic> jawaban;
  _KlienPura(this.jawaban);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(jawaban))), 201);
  }
}

void main() {
  test('id agenda dibaca dari jawaban { pesan, agenda }', () async {
    final api = Api(
      baseUrl: 'https://server-uji.test',
      token: 'token-uji',
      klien: _KlienPura({
        'ok': true,
        'pesan': 'Agenda Rapat uji tersimpan.',
        'agenda': {'id': 'a-123', 'agenda_rapat': 'Rapat uji', 'status_rapat': 'terjadwal'},
      }),
    );
    final hasil = await api.buatAgenda(judul: 'Rapat uji', mulai: '2026-11-16T09:00');
    expect(hasil.id, 'a-123');
    expect(hasil.pesan, 'Agenda Rapat uji tersimpan.');
  });

  test('jawaban tanpa id tidak melempar, hanya mengembalikan null', () async {
    final api = Api(
      baseUrl: 'https://server-uji.test',
      token: 'token-uji',
      klien: _KlienPura({'pesan': 'Agenda tersimpan.'}),
    );
    final hasil = await api.buatAgenda(judul: 'Rapat uji', mulai: '2026-11-16T09:00');
    expect(hasil.id, isNull);
  });
}
