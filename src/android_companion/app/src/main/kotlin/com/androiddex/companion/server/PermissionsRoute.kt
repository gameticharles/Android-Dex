package com.androiddex.companion.server

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Real-Time Device Permissions Telemetry Route
 */
class PermissionsRoute(private val context: Context) {

    fun getPermissionsStatusJson(): String {
        val permissionsArray = JSONArray()

        val checkList = mutableListOf(
            PermissionItem("Notification Listener", "Notification Access required to sync notifications & media", isNotificationListenerEnabled()),
            PermissionItem("Read Contacts", "Required to access contacts stored on the device", checkPermission(Manifest.permission.READ_CONTACTS)),
            PermissionItem("Write Contacts", "Required to add, edit or delete contacts", checkPermission(Manifest.permission.WRITE_CONTACTS)),
            PermissionItem("Read Call Log", "Required to read call history from the device", checkPermission(Manifest.permission.READ_CALL_LOG)),
            PermissionItem("Call Phone", "Required to programmatically place phone calls", checkPermission(Manifest.permission.CALL_PHONE)),
            PermissionItem("Read Phone State", "Required to detect incoming calls & network state", checkPermission(Manifest.permission.READ_PHONE_STATE)),
            PermissionItem("Read SMS", "Required to sync text messages to desktop", checkPermission(Manifest.permission.READ_SMS)),
            PermissionItem("Send SMS", "Required to send text messages from desktop", checkPermission(Manifest.permission.SEND_SMS)),
            PermissionItem("Battery Optimization", "Required to keep companion service alive in background", isBatteryOptimizationDisabled())
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkList.add(PermissionItem("Bluetooth Connect", "Required to monitor connected Bluetooth devices", checkPermission(Manifest.permission.BLUETOOTH_CONNECT)))
            checkList.add(PermissionItem("Bluetooth Scan", "Required to discover nearby Bluetooth devices", checkPermission(Manifest.permission.BLUETOOTH_SCAN)))
        }

        var allGranted = true
        for (item in checkList) {
            if (!item.isGranted) allGranted = false
            val json = JSONObject().apply {
                put("title", item.title)
                put("description", item.description)
                put("is_granted", item.isGranted)
            }
            permissionsArray.put(json)
        }

        return JSONObject().apply {
            put("status", "success")
            put("all_granted", allGranted)
            put("permissions", permissionsArray)
        }.toString()
    }

    private fun checkPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            flat != null && flat.contains(context.packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = context.getSystemService(PowerManager::class.java)
                pm?.isIgnoringBatteryOptimizations(context.packageName) ?: false
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    data class PermissionItem(val title: String, val description: String, val isGranted: Boolean)
}
