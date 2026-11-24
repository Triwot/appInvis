package com.example.invita_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Servicio en primer plano (tipo dataSync) que mantiene vivo el proceso mientras
 * Flutter genera el lote de invitaciones. El trabajo real sigue ocurriendo en
 * Dart/FFmpeg; este servicio solo evita que Android mate la app en segundo plano
 * y muestra la notificación persistente con el progreso.
 */
class BatchForegroundService : Service() {

    companion object {
        const val NOTIFICATION_ID = 4101
        const val DONE_NOTIFICATION_ID = 4102
        const val CHANNEL_PROGRESS = "invitapro_progress"
        const val CHANNEL_DONE = "invitapro_done"

        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        private fun manager(ctx: Context) =
            ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        fun ensureChannels(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val m = manager(ctx)
            m.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_PROGRESS,
                    "Progreso de generación",
                    NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
            )
            m.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_DONE,
                    "Generación terminada",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }

        private fun contentIntent(ctx: Context): PendingIntent {
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP }
            return PendingIntent.getActivity(
                ctx, 0, launch ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        @Suppress("DEPRECATION")
        private fun builder(ctx: Context, channel: String): Notification.Builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Notification.Builder(ctx, channel)
            else
                Notification.Builder(ctx)

        /** [percent] 0..100, o null para barra indeterminada. */
        fun progressNotification(ctx: Context, title: String, text: String, percent: Int?): Notification {
            val b = builder(ctx, CHANNEL_PROGRESS)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentIntent(ctx))
            if (percent == null) b.setProgress(0, 0, true) else b.setProgress(100, percent, false)
            return b.build()
        }

        fun doneNotification(ctx: Context, title: String, text: String): Notification =
            builder(ctx, CHANNEL_DONE)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setContentIntent(contentIntent(ctx))
                .build()

        fun notify(ctx: Context, id: Int, n: Notification) {
            try {
                manager(ctx).notify(id, n)
            } catch (_: SecurityException) {
                // POST_NOTIFICATIONS denegado: el servicio sigue vivo sin notificación visible.
            }
        }

        fun cancelAll(ctx: Context) {
            manager(ctx).cancel(NOTIFICATION_ID)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels(this)
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "InvitaPro"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "Preparando…"
        val notification = progressNotification(this, title, text, null)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Mantiene la CPU activa con la pantalla apagada (tope de seguridad: 6 h).
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "InvitaPro:batch").apply {
                setReferenceCounted(false)
                acquire(6 * 60 * 60 * 1000L)
            }
        }
        return START_NOT_STICKY
    }

    /** Si el usuario cierra la app desde recientes, Dart muere: detener el servicio. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        cancelAll(this)
        super.onDestroy()
    }
}
