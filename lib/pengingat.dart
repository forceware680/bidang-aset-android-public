import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'agenda.dart';
import 'pengingat_menit.dart';
import 'simpan.dart';

/// Keterangan yang ditampilkan bila HP memblokir notifikasi aplikasi ini.
const pesanNotifikasiDiblokir = 'Notifikasi agenda diblokir di HP ini. Izinkan notifikasi aplikasi ini lewat pengaturan HP.';

const _kanal = 'pengingat_agenda';
const _namaKanal = 'Pengingat agenda';

/// Kanal pemberitahuan peserta: orang lain menambahkan kamu ke agenda; dibunyikan dengan nada notifikasi biasa.
const _kanalPeserta = 'pemberitahuan_peserta';
const _namaKanalPeserta = 'Pemberitahuan peserta';

/// Kanal native untuk bunyi alarm: MIUI memakai nada notifikasi bawaan untuk notifikasi aplikasi,
/// jadi nada alarm aplikasi dibunyikan sendiri lewat kode Kotlin di jalur suara alarm HP.
const _kanalAlarm = MethodChannel('agenda_aset.alarm');

/// Notifikasi alarm: tanpa suara (nada alarm dibunyikan sendiri), prioritas tinggi, getar.
/// Ikon kecil = siluet logo putih (di-tint sistem), ikon besar = logo warna penuh saat notifikasi dibuka.
final _rincianAlarm = NotificationDetails(
  android: AndroidNotificationDetails(
    _kanal,
    _namaKanal,
    channelDescription: 'Alarm pengingat agenda bidang aset',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'notification_small',
    largeIcon: const DrawableResourceAndroidBitmap('notification_large'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    vibrationPattern: Int64List.fromList([0, 500, 500, 500]),
  ),
);

/// Notifikasi "ditambahkan sebagai peserta": nada dan getar bawaan HP, ikon sama dengan alarm (siluet logo putih + logo warna).
final _rincianPeserta = NotificationDetails(
  android: AndroidNotificationDetails(
    _kanalPeserta,
    _namaKanalPeserta,
    channelDescription: 'Orang lain menambahkan kamu sebagai peserta sebuah agenda',
    importance: Importance.high,
    priority: Priority.defaultPriority,
    icon: 'notification_small',
    largeIcon: const DrawableResourceAndroidBitmap('notification_large'),
  ),
);

/// Waktu alarm: `menit` menit sebelum waktu mulai. 0 berarti tepat pada waktu mulai.
DateTime waktuAlarm(DateTime mulai, int menit) => mulai.subtract(Duration(minutes: menit));

/// Pengingat alarm di perangkat, dijadwalkan dari `mulai` agenda pada zona waktu setempat.
class Pengingat {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _siap = false;

  Future<void> siap({void Function(String payload)? saatDiketuk}) async {
    if (_siap) return;
    tz_data.initializeTimeZones();
    // Zona waktu acuan alarm ditetapkan WIB, bukan bawaan paket `timezone` (UTC).
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (respon) => saatDiketuk?.call(respon.payload ?? ''),
      );
      // Notifikasi alarm diposting native: diketuk mengirim payload lewat kanal, dan payload saat
      // aplikasi baru dibuka lewat 'ambil_payload' supaya agenda tetap terbuka.
      _kanalAlarm.setMethodCallHandler((call) async {
        if (call.method == 'agenda') saatDiketuk?.call(call.arguments as String? ?? '');
      });
      final tertunda = await _kanalAlarm.invokeMethod<String>('ambil_payload');
      if (tertunda != null && tertunda.isNotEmpty) saatDiketuk?.call(tertunda);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Nada kanal tidak bisa diubah setelah kanal dibuat, jadi kanal lama dibuang dulu sekali.
      if (!await Simpan().kanalNadaAlarmSiap()) await android.deleteNotificationChannel(channelId: _kanal);
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _kanal,
          _namaKanal,
          description: 'Alarm pengingat agenda bidang aset',
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _kanalPeserta,
          _namaKanalPeserta,
          description: 'Orang lain menambahkan kamu sebagai peserta sebuah agenda',
          importance: Importance.high,
        ),
      );
      await Simpan().simpanKanalNadaAlarmSiap();
    }
    _siap = true;
  }

  /// Minta izin yang dibutuhkan alarm: Android 13 izin notifikasi, Android 14 izin alarm tepat.
  /// Dipanggil saat alarm akan dipasang, bukan saat aplikasi dibuka, supaya layar masuk tidak
  /// tertahan menunggu jawaban pengguna pada dialog izin HP.
  Future<void> mintaIzin() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
  }

  /// Pasang alarm `menit` menit sebelum waktu mulai (0 = tepat saat waktu mulai). Agenda yang sudah lewat tidak dijadwalkan.
  /// Mengembalikan keterangan bila pengingat tidak bisa dipasang; agenda tetap tersimpan.
  Future<String?> pasang(Agenda agenda, bool aktif, int menit) async {
    try {
      await siap();
      await mintaIzin();
      await _batalDalam(agenda.id);
      if (!aktif) return null;
      if (!await bolehNotifikasi()) return pesanNotifikasiDiblokir;
      final waktuMulai = tz.TZDateTime.from(agenda.mulai.toUtc(), tz.local);
      final alarm = waktuMulai.subtract(Duration(minutes: menit));
      if (alarm.isBefore(tz.TZDateTime.now(tz.local))) return null;
      // Alarm dan notifikasinya dikelola penuh di jalur native (AlarmReceiver.kt):
      // receiver latar milik paket flutter_local_notifications diblok MIUI saat aplikasi tidak
      // aktif, jadi bunyi jalan tanpa notifikasi yang masuk ke shade.
      await _kanalAlarm.invokeMethod('jadwal', {
        'millis': alarm.millisecondsSinceEpoch,
        'kode': _id(agenda.id),
        'judul': 'Agenda ${agenda.judul}',
        'isi': '${agenda.tempat ?? 'tempat belum ditentukan'} · ${labelMenitPengingat(menit)}',
        'payload': agenda.id,
      });
      return null;
    } catch (e) {
      return 'Pengingat belum bisa dipasang di perangkat ini: $e';
    }
  }

  /// Apakah HP mengizinkan aplikasi ini menampilkan notifikasi. Bila tidak, alarm pasang tapi tidak muncul.
  Future<bool> bolehNotifikasi() async {
    await siap();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? true;
  }

  /// Buka pengaturan notifikasi aplikasi ini di HP supaya petugas bisa mengizinkan.
  Future<void> bukaPengaturanNotifikasi() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.openAppNotificationSettings();
  }

  /// Tampilkan notifikasi "ditambahkan sebagai peserta" sekarang. `payload` id agenda: diketuk membuka detailnya.
  Future<void> tampilkanPeserta({required String idNotif, required String oleh, required String agenda, required String isi, required String payload}) async {
    try {
      await siap();
      if (!await bolehNotifikasi()) return;
      await _plugin.show(
        // Jumlah dua hash bisa melewati 2^31; id notifikasi harus muat int32.
        id: (_id(payload) + _id(idNotif)) & 0x7FFFFFFF,
        title: 'Ditambahkan sebagai peserta',
        body: '$oleh telah menambahkan kamu sebagai peserta pada agenda $agenda — $isi',
        notificationDetails: _rincianPeserta,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Pemberitahuan peserta tidak bisa ditampilkan: $e');
    }
  }

  /// Bunyikan notifikasi alarm sekarang, supaya petugas bisa mendengar nada alarmnya.
  Future<String?> cobaBunyi() async {
    try {
      await siap();
      await _kanalAlarm.invokeMethod('bunyi');
      await _plugin.show(
        id: 0,
        title: 'Uji bunyi alarm',
        body: 'Seperti ini alarm pengingat agenda di HP kamu',
        notificationDetails: _rincianAlarm,
      );
      return null;
    } catch (e) {
      return 'Bunyi alarm tidak bisa dicoba di perangkat ini: $e';
    }
  }

  /// Hentikan nada alarm yang sedang berbunyi (tombol stop). true bila ada bunyi yang dihentikan.
  Future<bool> stopBunyi() async {
    await siap();
    return await _kanalAlarm.invokeMethod<bool>('stop') ?? false;
  }

  /// Apakah nada alarm sedang berbunyi di perangkat ini sekarang.
  Future<bool> bunyiAktif() async {
    await siap();
    return await _kanalAlarm.invokeMethod<bool>('aktif') ?? false;
  }

  Future<void> batal(String agendaId) async {
    try {
      await siap();
      await _batalDalam(agendaId);
    } catch (e) {
      debugPrint('Pengingat agenda tidak bisa dibatalkan: $e');
    }
  }

  Future<void> _batalDalam(String agendaId) async {
    await _plugin.cancel(id: _id(agendaId));
    await _kanalAlarm.invokeMethod('batal', {'kode': _id(agendaId)});
  }

  Future<void> batalSemua() async {
    try {
      await siap();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Pengingat tidak bisa dibatalkan: $e');
    }
  }

  /// Nomor id harus stabil dari id agenda; hash sederhana cukup karena id uuid unik.
  int _id(String uuid) {
    int h = 0;
    for (final b in uuid.codeUnits) {
      h = (h * 31 + b) & 0x7FFFFFFF;
    }
    return h;
  }
}

/// Zona waktu perangkat dipakai sebagai acuan alarm; perangkat petugas selalu WIB.
bool perangkatWIB() => kDebugMode || tz.local.name == 'Asia/Jakarta';
