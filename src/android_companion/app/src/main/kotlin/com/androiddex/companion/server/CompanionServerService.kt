package com.androiddex.companion.server

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.androiddex.companion.MainActivity
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject

/**
 * Foreground Service running embedded HTTP Telemetry & Pairing Server with dynamic connection tracking.
 */
class CompanionServerService : Service() {

    companion object {
        const val ACTION_STOP_SERVICE = "com.androiddex.companion.ACTION_STOP_SERVICE"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "dex_companion_channel"
        private const val INACTIVITY_TIMEOUT_MS = 15000L // 15 seconds
    }

    private var server: EmbeddedHttpServer? = null
    private val handler = Handler(Looper.getMainLooper())
    
    @Volatile
    private var isConnected = false
    
    @Volatile
    private var lastRequestTimeMs = 0L
    
    @Volatile
    private var lastClientIp = "127.0.0.1"

    @Volatile
    private var activeComputerName = "DEX Desktop"

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (isConnected && (System.currentTimeMillis() - lastRequestTimeMs > INACTIVITY_TIMEOUT_MS)) {
                isConnected = false
                updateNotification()
            }
            handler.postDelayed(this, 5000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        updateNotification()
        startEmbeddedServer()
        handler.postDelayed(watchdogRunnable, 5000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_SERVICE) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        updateNotification()
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Android DEX Companion Server",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live connection status for Android DEX Companion"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    fun updateClientActivity(clientIp: String, computerName: String = "") {
        lastRequestTimeMs = System.currentTimeMillis()
        lastClientIp = clientIp
        if (computerName.isNotEmpty()) {
            activeComputerName = computerName
        }
        if (!isConnected) {
            isConnected = true
            updateNotification()
        }
    }

    private fun updateNotification() {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val stopIntent = Intent(this, CompanionServerService::class.java).apply {
            action = ACTION_STOP_SERVICE
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val title: String
        val text: String
        if (isConnected) {
            title = "Android DEX"
            text = "Connected to $activeComputerName ($lastClientIp) • Streaming"
        } else {
            title = "Android DEX"
            text = "Service active on port 8080 • Ready to stream"
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                android.R.drawable.ic_menu_view,
                "Open App",
                openAppPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                if (isConnected) "Disconnect" else "Stop Service",
                stopPendingIntent
            )
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startEmbeddedServer() {
        try {
            server = EmbeddedHttpServer(this, 8080)
            server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        handler.removeCallbacks(watchdogRunnable)
        server?.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    class EmbeddedHttpServer(private val context: CompanionServerService, port: Int) : NanoHTTPD(port) {
        val pairingRoute = PairingRoute(context)
        private val mediaRoute = MediaRoute(context).apply { init() }
        private val contactsRoute = ContactsRoute(context)
        private val imageRoute = ImageRoute(context)
        private val smsRoute = SmsRoute(context)
        private val callLogRoute = CallLogRoute(context)
        private val appsRoute = AppsRoute(context)
        private val systemRoute = SystemRoute(context)
        private val permissionsRoute = PermissionsRoute(context)

        override fun serve(session: IHTTPSession): Response {
            val clientIp = session.remoteIpAddress ?: "127.0.0.1"
            val uri = session.uri
            val parms = session.parms
            val headers = session.headers

            // Check authToken header or query parameter (case-insensitive)
            val authToken = headers["x-dex-auth-token"] ?: headers["X-Dex-Auth-Token"] ?: parms["auth_token"] ?: ""
            var verifiedComputer = if (authToken.isNotEmpty()) pairingRoute.deviceManager.getComputerByAuthToken(authToken) else null

            if (verifiedComputer == null) {
                verifiedComputer = pairingRoute.deviceManager.getPairedComputers().firstOrNull { it.status == "APPROVED" }
            }

            if (verifiedComputer != null) {
                context.updateClientActivity(clientIp, verifiedComputer.name)
            } else {
                context.updateClientActivity(clientIp, "DEX Desktop")
            }

            return when {
                uri == "/ping" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", "success").put("connected", context.isConnected).toString()
                    )
                }
                uri == "/pairing/request" -> {
                    val body = readBodyString(session)
                    val result = pairingRoute.handlePairingRequest(body, clientIp)
                    try {
                        val resObj = JSONObject(result)
                        val status = resObj.optString("status")
                        val name = resObj.optString("computer_name")
                        if (status == "APPROVED") {
                            context.updateClientActivity(clientIp, name)
                        }
                    } catch (_: Exception) {}
                    newFixedLengthResponse(Response.Status.OK, "application/json", result)
                }
                uri == "/pairing/status" -> {
                    val deviceId = parms["device_id"] ?: parms["id"] ?: ""
                    val result = pairingRoute.handlePairingStatus(deviceId)
                    try {
                        val resObj = JSONObject(result)
                        val status = resObj.optString("status")
                        val name = resObj.optString("computer_name")
                        if (status == "APPROVED") {
                            context.updateClientActivity(clientIp, name)
                        }
                    } catch (_: Exception) {}
                    newFixedLengthResponse(Response.Status.OK, "application/json", result)
                }
                uri == "/pairing/respond" -> {
                    val deviceId = parms["device_id"] ?: parms["id"] ?: ""
                    val action = parms["action"] ?: "accept"
                    val autoConnect = parms["auto_connect"]?.toBoolean() ?: true
                    val result = pairingRoute.handlePairingRespond(deviceId, action, autoConnect)
                    newFixedLengthResponse(Response.Status.OK, "application/json", result)
                }
                uri == "/pairing/devices" -> {
                    newFixedLengthResponse(Response.Status.OK, "application/json", pairingRoute.getPairedDevicesJson())
                }
                uri == "/pairing/update_device" -> {
                    val deviceId = parms["device_id"] ?: parms["id"] ?: ""
                    val newName = parms["name"] ?: ""
                    val autoConnect = parms["auto_connect"]?.toBoolean() ?: true
                    newFixedLengthResponse(Response.Status.OK, "application/json", pairingRoute.handleUpdateDevice(deviceId, newName, autoConnect))
                }
                uri == "/pairing/delete_device" -> {
                    val deviceId = parms["device_id"] ?: parms["id"] ?: ""
                    newFixedLengthResponse(Response.Status.OK, "application/json", pairingRoute.handleDeleteDevice(deviceId))
                }
                uri == "/media" -> {
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        mediaRoute.getMediaStateJson()
                    )
                }
                uri == "/media/seek" -> {
                    val posMs = parms["position_ms"]?.toLongOrNull() ?: parms["position"]?.toLongOrNull() ?: 0L
                    val ok = mediaRoute.seekTo(posMs)
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").put("position_ms", posMs).toString()
                    )
                }
                uri == "/media/control" -> {
                    val cmd = parms["cmd"] ?: parms["command"] ?: ""
                    val posMs = parms["position_ms"]?.toLongOrNull() ?: parms["position"]?.toLongOrNull()
                    val ok = if (cmd.lowercase() == "seek" && posMs != null) {
                        mediaRoute.seekTo(posMs)
                    } else {
                        mediaRoute.sendTransportCommand(cmd)
                    }
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        JSONObject().put("status", if (ok) "success" else "failed").put("cmd", cmd).toString()
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

        private fun readBodyString(session: IHTTPSession): String {
            val map = HashMap<String, String>()
            return try {
                session.parseBody(map)
                map["postData"] ?: ""
            } catch (_: Exception) {
                ""
            }
        }
    }
}
