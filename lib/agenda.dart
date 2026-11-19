/// Agenda seperti yang dikirim API web (`mulai` dan `selesai` selalu ber-offset +07:00).
class Agenda {
  final String id;
  final String judul;
  final String? tempat;
  final String? penyelenggara;
  final String? catatan;
  final DateTime mulai;
  final DateTime? selesai;
  final String status;
  final String statusLabel;
  final String sumber;
  final String? nomorSurat;
  final String? perihal;
  final String? dibuatOleh;
  /// Nama pegawai/pejabat yang hadir, urut nama seperti yang dikirim server.
  final List<String> peserta;
  /// true bila akun ini pembuat atau namanya tercatat sebagai peserta. Agenda lain hanya terbaca
  /// ketika toggle "tampilkan agenda pejabat lain" menyala, dan alarmnya tidak pernah dipasang.
  final bool ikut;
  final bool dapatDiubah;
  final bool dapatDihapus;

  const Agenda({
    required this.id,
    required this.judul,
    required this.mulai,
    required this.status,
    required this.statusLabel,
    required this.sumber,
    required this.dapatDiubah,
    required this.dapatDihapus,
    this.tempat,
    this.penyelenggara,
    this.catatan,
    this.selesai,
    this.nomorSurat,
    this.perihal,
    this.dibuatOleh,
    this.peserta = const <String>[],
    this.ikut = true,
  });

  bool get milikSendiri => sumber == 'agenda sendiri' && dapatDiubah;
  bool get pejabatLain => !ikut;

  factory Agenda.dariJson(Map<String, dynamic> json) {
    DateTime baca(String teks) => DateTime.parse(teks);
    return Agenda(
      id: json['id'] as String,
      judul: json['agenda_rapat'] as String? ?? '',
      tempat: json['tempat'] as String?,
      penyelenggara: json['penyelenggara'] as String?,
      catatan: json['catatan'] as String?,
      mulai: baca(json['mulai'] as String),
      selesai: json['selesai'] is String ? baca(json['selesai'] as String) : null,
      status: json['status_rapat'] as String? ?? 'terjadwal',
      statusLabel: json['status_label'] as String? ?? json['status_rapat'] as String? ?? 'Terjadwal',
      sumber: json['sumber'] as String? ?? 'agenda sendiri',
      nomorSurat: json['nomor_surat'] as String?,
      perihal: json['perihal'] as String?,
      dibuatOleh: json['dibuat_oleh'] as String?,
      peserta: _bacaPeserta(json['peserta']),
      // Server lama belum mengirim flag ini: dianggap ikut supaya perilaku tidak berubah.
      ikut: json['ikut'] as bool? ?? true,
      dapatDiubah: json['dapat_diubah'] as bool? ?? false,
      dapatDihapus: json['dapat_dihapus'] as bool? ?? false,
    );
  }
}

/// Nama yang hadir datang sebagai daftar dari server. Nama kosong yang nyasar dibuang supaya tidak
/// muncul sebagai baris peserta tanpa nama.
List<String> _bacaPeserta(Object? nilai) {
  if (nilai is! List) return const <String>[];
  return nilai.whereType<String>().map((nama) => nama.trim()).where((nama) => nama.isNotEmpty).toList();
}

/// Pemberitahuan peserta dari `/api/pemberitahuan`: orang lain menambahkan nama akun ini ke sebuah agenda.
class Pemberitahuan {
  final String id;
  final String rapatId;
  final String oleh;
  final String agenda;
  final DateTime mulai;
  /// Waktu pemberitahuan dicatat (UTC); dipakai sebagai kursor penyarian perangkat.
  final DateTime padaUtc;

  Pemberitahuan({required this.id, required this.rapatId, required this.oleh, required this.agenda, required this.mulai, required this.padaUtc});

  factory Pemberitahuan.dariJson(Map<String, dynamic> json) {
    return Pemberitahuan(
      id: json['id'] as String,
      rapatId: json['rapat_id'] as String? ?? '',
      oleh: json['oleh'] as String? ?? '',
      agenda: json['agenda_rapat'] as String? ?? '',
      mulai: DateTime.parse(json['mulai'] as String),
      padaUtc: DateTime.parse(json['pada_utc'] as String),
    );
  }
}

class Sesi {
  final String nama;
  final String email;
  final String peran;
  final String? perangkat;
  final DateTime kedaluwarsa;

  const Sesi({required this.nama, required this.email, required this.peran, this.perangkat, required this.kedaluwarsa});

  factory Sesi.dariJson(Map<String, dynamic> json) => Sesi(
        nama: json['nama'] as String? ?? '',
        email: json['email'] as String? ?? '',
        peran: json['peran'] as String? ?? '',
        perangkat: json['perangkat'] as String?,
        kedaluwarsa: DateTime.tryParse(json['kedaluwarsa'] as String? ?? '') ?? DateTime.now(),
      );
}
