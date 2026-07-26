package com.androiddex.companion.server

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import org.json.JSONObject

/**
 * Device System Telemetry & Specs Route
 */
class SystemRoute(private val context: Context) {

    fun getSystemStatusJson(): String {
        var batteryLevel = -1
        var isCharging = false

        try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, filter)

            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level >= 0 && scale > 0) {
                batteryLevel = (level * 100 / scale.toFloat()).toInt()
            }

            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
        } catch (_: Exception) {}

        var freeStorageBytes = 0L
        var totalStorageBytes = 0L
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            freeStorageBytes = stat.availableBytes
            totalStorageBytes = stat.totalBytes
        } catch (_: Exception) {}

        return JSONObject().apply {
            put("status", "success")
            put("device_model", "${Build.MANUFACTURER} ${Build.MODEL}")
            put("android_version", Build.VERSION.RELEASE)
            put("sdk_int", Build.VERSION.SDK_INT)
            put("battery_level", batteryLevel)
            put("is_charging", isCharging)
            put("free_storage_bytes", freeStorageBytes)
            put("total_storage_bytes", totalStorageBytes)
        }.toString()
    }
}
