import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_aset/root_yr.dart';

void main() {
  test('akar TLS tambahan terbaca sebagai satu sertifikat PEM', () {
    expect(sertifikatAkarYr.contains('-----BEGIN CERTIFICATE-----'), isTrue);
    expect(sertifikatAkarYr.contains('-----END CERTIFICATE-----'), isTrue);
    expect(RegExp(r'-----BEGIN CERTIFICATE-----').allMatches(sertifikatAkarYr).length, 1);
  });

  test('bentuk DER akar utuh dan bentuk PEM bisa dimuat di desktop', () {
    final der = akarYrDer();
    expect(der.length, greaterThan(1000));
    expect(der[0], 0x30); // DER dimulai dengan_sequence

    final konteks = SecurityContext(withTrustedRoots: true);
    konteks.setTrustedCertificatesBytes(utf8.encode(sertifikatAkarYr));
  });
}
