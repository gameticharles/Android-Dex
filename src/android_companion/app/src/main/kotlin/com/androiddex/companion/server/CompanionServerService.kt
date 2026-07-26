package com.androiddex.companion.server

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject

/**
 * Foreground Service running embedded HTTP Telemetry Server
 */
class CompanionServerService : Service() {

    private var server: EmbeddedHttpServer? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceNotification()
        startEmbeddedServer()
    }

    private fun startForegroundServiceNotification() {
        val channelId = "dex_companion_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Android Dex Companion Server",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Android Dex Companion")
            .setContentText("Streaming telemetry to Desktop shell...")
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setOngoing(true)
            .build()

        startForeground(1001, notification)
    }

    private fun startEmbeddedServer() {
        try {
            server = EmbeddedHttpServer(this, 8080)
            server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        server?.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    class EmbeddedHttpServer(private val context: CompanionServerService, port: Int) : NanoHTTPD(port) {
        private val mediaRoute = MediaRoute(context).apply { init() }
        private val contactsRoute = ContactsRoute(context)
        private val imageRoute = ImageRoute(context)
        private val smsRoute = SmsRoute(context)
        private val callLogRoute = CallLogRoute(context)
        private val appsRoute = AppsRoute(context)
        private val systemRoute = SystemRoute(context)
        private val permissionsRoute = PermissionsRoute(context)

        override fun serve(session: IHTTPSession): Response {
            val uri = session.uri
            val parms = session.parms

            return when {
                uri == "/ping" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", "success").toString()
                    )
                }
                uri == "/media" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        mediaRoute.getMediaStateJson()
                    )
                }
                uri == "/contacts" -> {
                    val offset = parms["offset"]?.toIntOrNull() ?: 0
                    val limit = parms["limit"]?.toIntOrNull() ?: 50
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        contactsRoute.getPaginatedContacts(offset, limit)
                    )
                }
                uri == "/wallpaper" -> {
                    val bytes = imageRoute.getDeviceWallpaperBytes()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "image/webp",
                        bytes.inputStream(),
                        bytes.size.toLong()
                    )
                }
                uri == "/sms" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        smsRoute.getConversationsJson()
                    )
                }
                uri == "/sms/messages" -> {
                    val threadId = parms["thread_id"]?.toLongOrNull() ?: 0L
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        smsRoute.getMessagesForThreadJson(threadId)
                    )
                }
                uri == "/sms/send" -> {
                    val recipient = parms["recipient"] ?: ""
                    val message = parms["message"] ?: ""
                    val ok = smsRoute.sendSms(recipient, message)
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").toString()
                    )
                }
                uri == "/calls" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        callLogRoute.getCallLogsJson()
                    )
                }
                uri == "/telephony/state" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        callLogRoute.getCallStateJson()
                    )
                }
                uri == "/telephony/answer" -> {
                    val ok = callLogRoute.answerCall()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").toString()
                    )
                }
                uri == "/telephony/end" -> {
                    val ok = callLogRoute.endCall()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").toString()
                    )
                }
                uri == "/telephony/toggle_speaker" -> {
                    val ok = callLogRoute.toggleSpeaker()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").toString()
                    )
                }
                uri == "/phone/dial" -> {
                    val number = parms["number"] ?: ""
                    val ok = callLogRoute.dialNumber(number)
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").toString()
                    )
                }
                uri == "/apps" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        appsRoute.getInstalledAppsJson()
                    )
                }
                uri == "/apps/icon" -> {
                    val pkg = parms["package"] ?: ""
                    val bytes = appsRoute.getAppIconPngBytes(pkg)
                    if (bytes != null) {
                        newFixedLengthResponse(
                            Response.Status.OK,
                            "image/png",
                            bytes.inputStream(),
                            bytes.size.toLong()
                        )
                    } else {
                        newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Icon not found")
                    }
                }
                uri == "/system/status" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        systemRoute.getSystemStatusJson()
                    )
                }
                uri == "/permissions" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        permissionsRoute.getPermissionsStatusJson()
                    )
                }
                else -> newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "404 Not Found")
            }
        }
    }
}
