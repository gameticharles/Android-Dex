package com.androiddex.companion.service

import android.content.Intent
import android.os.IBinder
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

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

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        // Broadcast notification posted event
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        // Broadcast notification removed event
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
            val title = extras?.getString("android.title") ?: ""
            val text = extras?.getCharSequence("android.text")?.toString() ?: ""

            if (title.isNotEmpty() || text.isNotEmpty()) {
                val notifObj = JSONObject().apply {
                    put("id", "notif_${index}_${pkg}")
                    put("package_name", pkg)
                    put("title", title)
                    put("body", text)
                    put("app_name", pkg.substringAfterLast('.').capitalize())
                }
                array.put(notifObj)
            }
        }
        return array
    }
}
