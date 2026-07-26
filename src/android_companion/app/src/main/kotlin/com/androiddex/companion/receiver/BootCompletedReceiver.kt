package com.androiddex.companion.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.androiddex.companion.server.CompanionServerService

/**
 * Auto-starts CompanionServerService when Android device completes boot process.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (Intent.ACTION_BOOT_COMPLETED == action || "android.intent.action.QUICKBOOT_POWERON" == action) {
            val serviceIntent = Intent(context, CompanionServerService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (_: Exception) {}
        }
    }
}
