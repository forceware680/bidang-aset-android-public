package id.go.magelang.agenda_aset

import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import android.util.Log
import androidx.annotation.Keep
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        payloadTunda = intent.getStringExtra("payload_agenda")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        payloadTunda = intent.getStringExtra("payload_agenda")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bunyi" -> {
                    Thread { bunyiAlarm(applicationContext) }.start()
                    result.success(true)
                }

                "jadwal" -> {
                    val millis = (call.argument<Any>("millis") as? Number)?.toLong() ?: 0L
                    val kode = (call.argument<Any>("kode") as? Number)?.toInt() ?: 0
                    jadwalBunyi(
                        applicationContext,
                        millis,
                        kode,
                        call.argument<Any>("judul") as? String ?: "Agenda Bidang Aset",
                        call.argument<Any>("isi") as? String ?: "",
                        call.argument<Any>("payload") as? String ?: "",
                    )
                    result.success(true)
                }

                "ambil_payload" -> {
                    result.success(payloadTunda)
                    payloadTunda = null
                }

                "batal" -> {
                    val kode = (call.argument<Any>("kode") as? Number)?.toInt() ?: 0
                    batalBunyi(applicationContext, kode)
                    result.success(true)
                }

                "stop" -> {
                    result.success(stopBunyi(applicationContext))
                }

                "aktif" -> {
                    synchronized(kunciBunyi) { result.success(pemainAktif != null) }
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val ALARM_CHANNEL = "agenda_aset.alarm"
        const val ACTION_BUNYI = "id.go.magelang.agenda_aset.BUNYI_ALARM"
        const val ACTION_STOP = "id.go.magelang.agenda_aset.STOP_ALARM"
        const val ACTION_BUKA = "id.go.magelang.agenda_aset.BUKA_AGENDA"
        const val RECEIVER = "id.go.magelang.agenda_aset.AlarmReceiver"
        const val KANAL_ALARM = "pengingat_agenda"

        /// Agenda yang diketuk dari notifikasi saat aplikasi belum jalan: ditahan sampai Dart siap.
        private var payloadTunda: String? = null

        /// Ikon notifikasi dicari plugin lewat nama string saat runtime, jadi resource shrinking
        /// menganggapnya tidak terpakai dan membuang PNG-nya dari APK. Referensi bertanda @Keep
        /// di sini membuat R8 menyimpan kedua drawable itu.
        @Keep
        @JvmStatic
        val ikonNotifikasi = intArrayOf(R.drawable.notification_small, R.drawable.notification_large)

        /// Bunyikan nada alarm milik aplikasi di jalur suara alarm (volume alarm HP, bukan volume notifikasi).
        /// Android 16 membisukan playback dari aplikasi yang sedang di latar, kecuali ia memegang audio
        /// focus, jadi fokus alarm diminta dulu sebelum MediaPlayer jalan.
        fun bunyiAlarm(ctx: Context) {
            val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val atribut = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val fokus: AudioFocusRequest? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                        .setAudioAttributes(atribut)
                        .build()
                } else {
                    null
                }
            if (fokus != null) {
                val hasilFokus = audio.requestAudioFocus(fokus)
                Log.i(TAG_ALARM, "fokus alarm: $hasilFokus (1=diizinkan)")
            }
            @Suppress("DEPRECATION")
            if (fokus == null) audio.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            val mp = MediaPlayer()
            synchronized(kunciBunyi) {
                // Bunyi lama dihentikan supaya nada tidak menumpuk saat dipencet berkali-kali.
                pemainAktif?.let { lama ->
                    try {
                        lama.stop()
                    } finally {
                        lama.release()
                    }
                }
                pemainAktif = mp
            }
            try {
                mp.setAudioAttributes(atribut)
                // android.resource:// ditolak MediaPlayer di perangkat ini (prepare gagal), jadi nada
                // alarm disalin ke cache dulu lalu diputar dari berkas. R.raw dipakai supaya file tidak
                // ikut dikecil oleh resource shrinking saat build rilis.
                val berkas = File(ctx.cacheDir, "agenda_alarm.wav")
                ctx.resources.openRawResource(R.raw.agenda_alarm).use { masuk ->
                    berkas.outputStream().use { keluar -> masuk.copyTo(keluar) }
                }
                mp.setDataSource(berkas.absolutePath)
                mp.setOnErrorListener { p, _, _ -> p.release(); true }
                mp.prepare()
                mp.start()
                // Ditahan sampai selesai supaya proses aplikasi tidak berhenti di tengah bunyi.
                // Nada alarm sekarang 30 detik, jadi batasnya di atas panjang nada.
                var waited = 0
                while (waited < 32_000) {
                    synchronized(kunciBunyi) {
                        if (pemainAktif !== mp) break
                    }
                    if (!mp.isPlaying) break
                    Thread.sleep(200)
                    waited += 200
                }
            } catch (e: Exception) {
                // Perangkat tanpa dukungan pemutaran audio tetap bisa dipakai.
                Log.w(TAG_ALARM, "bunyi alarm gagal: ${e.javaClass.simpleName} ${e.message}")
            } finally {
                synchronized(kunciBunyi) {
                    if (pemainAktif === mp) pemainAktif = null
                }
                mp.release()
                if (fokus != null) audio.abandonAudioFocusRequest(fokus)
                @Suppress("DEPRECATION")
                if (fokus == null) audio.abandonAudioFocus(null)
            }
        }

        private const val SIMPAN_ALARM = "alarm_bunyi"
        private const val TAG_ALARM = "agenda-alarm"

        /// Satu MediaPlayer aktif saja: nada alarm tidak boleh menumpuk kalau dipencet berkali-kali.
        /// Pencet baru menghentikan bunyi lama; tombol stop menghentikannya tanpa bunyi baru.
        private val kunciBunyi = Any()
        private var pemainAktif: MediaPlayer? = null

        /// Hentikan nada alarm yang sedang jalan. true bila ada bunyi yang dihentikan.
        fun stopBunyi(ctx: Context): Boolean {
            synchronized(kunciBunyi) {
                val mp = pemainAktif ?: return false
                pemainAktif = null
                try {
                    mp.stop()
                } finally {
                    mp.release()
                }
                // Jalur bunyi yang menunggu loop selesai akan keluar sendiri dan melepas fokus audio.
                Log.i(TAG_ALARM, "bunyi dihentikan")
                return true
            }
        }

        fun jadwalBunyi(ctx: Context, millis: Long, kode: Int, judul: String, isi: String, payload: String) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            am.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, millis, PendingIntentBunyi(ctx, kode, judul, isi, payload))
            // Disimpan supaya setelah HP mati-nyala alarm bunyi bisa dipasang ulang, lengkap dengan teks notifikasinya.
            ctx.getSharedPreferences(SIMPAN_ALARM, Context.MODE_PRIVATE).edit()
                .putLong("kode_$kode", millis)
                .putString("judul_$kode", judul)
                .putString("isi_$kode", isi)
                .putString("payload_$kode", payload)
                .apply()
        }

        fun batalBunyi(ctx: Context, kode: Int) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            am.cancel(PendingIntentBunyi(ctx, kode))
            hapusNotifikasi(ctx, kode)
            ctx.getSharedPreferences(SIMPAN_ALARM, Context.MODE_PRIVATE).edit()
                .remove("kode_$kode")
                .remove("judul_$kode")
                .remove("isi_$kode")
                .remove("payload_$kode")
                .apply()
        }

        /// Pasang ulang alarm bunyi yang masih akan datang setelah HP dinyalakan kembali.
        fun pulihkanBunyi(ctx: Context) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val prefs = ctx.getSharedPreferences(SIMPAN_ALARM, Context.MODE_PRIVATE)
            val sekarang = System.currentTimeMillis()
            for ((k, v) in prefs.all) {
                val kode = k.removePrefix("kode_").toIntOrNull() ?: continue
                val millis = (v as? Long) ?: continue
                if (millis <= sekarang) {
                    prefs.edit().remove(k).apply()
                    continue
                }
                am.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    millis,
                    PendingIntentBunyi(
                        ctx,
                        kode,
                        prefs.getString("judul_$kode", "Agenda Bidang Aset") ?: "Agenda Bidang Aset",
                        prefs.getString("isi_$kode", "") ?: "",
                        prefs.getString("payload_$kode", "") ?: "",
                    ),
                )
            }
        }

        /// Notifikasi alarm posting sendiri dari AlarmReceiver + tombol "Hentikan nada".
        fun tampilkanNotifikasi(ctx: Context, kode: Int, judul: String, isi: String, payload: String) {
            val man = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val kanal = NotificationChannel(KANAL_ALARM, "Pengingat agenda", NotificationManager.IMPORTANCE_MAX).apply {
                    description = "Alarm pengingat agenda bidang aset"
                    setSound(null, null) // nada alarm dibunyikan sendiri lewat MediaPlayer, bukan nada kanal
                    enableVibration(true)
                }
                man.createNotificationChannel(kanal)
            }
            val henti = android.app.PendingIntent.getBroadcast(
                ctx,
                kode + 7000,
                Intent(ACTION_STOP).setClassName(ctx.packageName, RECEIVER).putExtra("kode", kode),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            // Klik notifikasi lewat receiver supaya nada berhenti dulu lalu agenda terbuka.
            val buka = android.app.PendingIntent.getBroadcast(
                ctx,
                kode + 4000,
                Intent(ACTION_BUKA).setClassName(ctx.packageName, RECEIVER).putExtra("payload", payload),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
            )
            val notif = NotificationCompat.Builder(ctx, KANAL_ALARM)
                .setSmallIcon(R.drawable.notification_small)
                .setLargeIcon(BitmapFactory.decodeResource(ctx.resources, R.drawable.notification_large))
                .setContentTitle(judul)
                .setContentText(isi)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setVibrate(longArrayOf(0, 500, 500, 500))
                .setContentIntent(buka)
                .addAction(R.drawable.notification_small, "Hentikan nada", henti)
                .setTimeoutAfter(120_000)
                .build()
            man.notify(kode, notif)
        }

        fun hapusNotifikasi(ctx: Context, kode: Int) {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(kode)
        }

        private fun PendingIntentBunyi(ctx: Context, kode: Int, judul: String = "", isi: String = "", payload: String = ""): android.app.PendingIntent {
            val intent = Intent(ACTION_BUNYI).setClassName(ctx.packageName, RECEIVER)
                .putExtra("kode", kode)
                .putExtra("judul", judul)
                .putExtra("isi", isi)
                .putExtra("payload", payload)
            return android.app.PendingIntent.getBroadcast(
                ctx,
                kode,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
