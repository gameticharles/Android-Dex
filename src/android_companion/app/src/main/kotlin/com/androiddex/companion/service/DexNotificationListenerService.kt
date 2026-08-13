package com.androiddex.companion.service

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Icon
import android.os.IBinder
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Real-Time Notification Listener Bridge for Android Dex
 */
class DexNotificationListenerService : NotificationListenerService() {

    companion object {
        var instance: DexNotificationListenerService? = null
            private set
    }

    override fun onBind(intent: Intent?): IBinder? {
        instance = this
        return super.onBind(intent)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val action = intent.getStringExtra("action") ?: intent.action
            if (action == "cancel_all" || action == "com.androiddex.companion.CANCEL_ALL") {
                cancelAll()
            } else if (action == "cancel" || action == "com.androiddex.companion.CANCEL_PACKAGE") {
                val pkg = intent.getStringExtra("pkg")
                if (!pkg.isNullOrEmpty()) {
                    cancelNotificationByPackage(pkg)
                }
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    fun cancelAll() {
        try {
            cancelAllNotifications()
        } catch (_: Exception) {}
    }

    fun cancelNotificationByPackage(pkgName: String) {
        try {
            val activeNotifs = activeNotifications ?: return
            for (sbn in activeNotifs) {
                if (sbn.packageName == pkgName) {
                    cancelNotification(sbn.key)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }

    private fun bitmapToBase64(bitmap: Bitmap?): String? {
        if (bitmap == null) return null
        return try {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
            val byteArray = stream.toByteArray()
            "data:image/jpeg;base64," + Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    fun getActiveNotificationsJson(): JSONArray {
        val array = JSONArray()
        val activeNotifs = activeNotifications ?: return array

        for ((index, sbn) in activeNotifs.withIndex()) {
            val pkg = sbn.packageName ?: "android"
            if (pkg == "com.android.systemui" && sbn.notification.tickerText?.contains("USB debugging") == true) {
                continue
            }

            val extras = sbn.notification.extras
            val title = extras?.getCharSequence("android.title")?.toString() ?: ""
            val text = extras?.getCharSequence("android.text")?.toString() ?: ""
            val subText = extras?.getCharSequence("android.subText")?.toString() ?: ""

            // Extract picture attachment (if any)
            val pictureBitmap = extras?.get("android.picture") as? Bitmap
            val pictureBase64 = bitmapToBase64(pictureBitmap)

            // Extract large icon / avatar (if any)
            val largeIconObj = extras?.get("android.largeIcon")
            val largeIconBitmap = when (largeIconObj) {
                is Bitmap -> largeIconObj
                is Icon -> (largeIconObj.loadDrawable(this) as? BitmapDrawable)?.bitmap
                else -> null
            }
            val largeIconBase64 = bitmapToBase64(largeIconBitmap)

            // Extract notification action buttons
            val actionsArray = JSONArray()
            sbn.notification.actions?.forEach { act ->
                if (!act.title.isNullOrEmpty()) {
                    actionsArray.put(act.title.toString())
                }
            }

            if (title.isNotEmpty() || text.isNotEmpty()) {
                val notifObj = JSONObject().apply {
                    put("id", "notif_${index}_${pkg}")
                    put("package_name", pkg)
                    put("title", title)
                    put("body", text)
                    put("sub_text", subText)
                    put("app_name", pkg.substringAfterLast('.').replaceFirstChar { it.uppercase() })
                    put("image_data", pictureBase64 ?: "")
                    put("large_icon_data", largeIconBase64 ?: "")
                    put("actions", actionsArray)
                }
                array.put(notifObj)
            }
        }
        return array
    }
}
