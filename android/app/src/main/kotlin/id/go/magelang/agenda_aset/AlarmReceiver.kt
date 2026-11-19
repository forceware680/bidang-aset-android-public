package id.go.magelang.agenda_aset

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            MainActivity.pulihkanBunyi(context.applicationContext)
            return
        }
        if (intent.action == MainActivity.ACTION_STOP) {
            MainActivity.stopBunyi(context.applicationContext)
            MainActivity.hapusNotifikasi(context.applicationContext, intent.getIntExtra("kode", 0))
            return
        }
        if (intent.action == MainActivity.ACTION_BUKA) {
            // Diketuk notifikasi = hentikan nada lalu buka agendanya.
            MainActivity.stopBunyi(context.applicationContext)
            val buka = Intent(context, MainActivity::class.java)
                .putExtra("payload_agenda", intent.getStringExtra("payload") ?: "")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(buka)
            return
        }
        val pending = goAsync()
        Thread {
            try {
                // Notifikasi alarm diposting dari receiver milik aplikasi sendiri: MIUI memblok
                // receiver latar milik flutter_local_notifications, jadi bunyi jalan tapi
                // notifikasinya tidak pernah masuk ke shade.
                MainActivity.tampilkanNotifikasi(
                    context.applicationContext,
                    intent.getIntExtra("kode", 0),
                    intent.getStringExtra("judul") ?: "Agenda Bidang Aset",
                    intent.getStringExtra("isi") ?: "",
                    intent.getStringExtra("payload") ?: "",
                )
                MainActivity.bunyiAlarm(context.applicationContext)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
