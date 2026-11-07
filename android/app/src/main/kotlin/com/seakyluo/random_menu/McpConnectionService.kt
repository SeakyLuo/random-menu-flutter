package com.seakyluo.random_menu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel

/** User-enabled connection lifetime; the cached Flutter engine owns the server/store. */
class McpConnectionService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            channel!!.invokeMethod("stop", null, object : MethodChannel.Result {
                override fun success(result: Any?) = Unit
                override fun error(code: String, message: String?, details: Any?) {
                    android.widget.Toast.makeText(applicationContext, "$code: $message\n$details", android.widget.Toast.LENGTH_LONG).show()
                }
                override fun notImplemented() = error("not_implemented", "MCP stop handler unavailable", null)
            })
            return START_NOT_STICKY
        }
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "AI 连接", NotificationManager.IMPORTANCE_LOW))
        }
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)!!.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val open = PendingIntent.getActivity(this, 0, openIntent, PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, McpConnectionService::class.java).setAction(STOP), PendingIntent.FLAG_IMMUTABLE)
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }).setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("随机菜单 MCP 连接已开启")
            .setContentText("AI 可访问已授权的菜谱、餐厅和探店记录")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "关闭连接", stop).build()).build()
        startForeground(52147, notification)
        running = true
        return START_NOT_STICKY
    }

    override fun onDestroy() { running = false; super.onDestroy() }

    companion object {
        private const val CHANNEL = "random_menu_mcp"
        private const val STOP = "com.seakyluo.random_menu.STOP_MCP"
        var running = false
            private set
        var channel: MethodChannel? = null
    }
}
