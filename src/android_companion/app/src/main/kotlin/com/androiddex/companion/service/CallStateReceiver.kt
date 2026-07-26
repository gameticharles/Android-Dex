package com.androiddex.companion.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.TelephonyManager
import org.json.JSONObject

object CallStateStore {
    var currentState: String = "IDLE" // "IDLE", "RINGING", "ACTIVE"
    var callerName: String = "Unknown Caller"
    var callerNumber: String = ""
    var callerLocation: String = "Mobile Call"
    var startTimeMs: Long = 0

    fun toJson(): JSONObject {
        val durationSec = if (currentState == "ACTIVE" && startTimeMs > 0) {
            (System.currentTimeMillis() - startTimeMs) / 1000
        } else {
            0
        }

        return JSONObject().apply {
            put("state", currentState)
            put("name", callerName)
            put("number", callerNumber)
            put("location", callerLocation)
            put("duration_sec", durationSec)
        }
    }
}

class CallStateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
            val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""

            when (stateStr) {
                TelephonyManager.EXTRA_STATE_RINGING -> {
                    CallStateStore.currentState = "RINGING"
                    CallStateStore.callerNumber = number
                    CallStateStore.callerName = resolveContactName(context, number)
                    CallStateStore.callerLocation = "Incoming Call"
                    CallStateStore.startTimeMs = 0
                }
                TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                    if (CallStateStore.currentState != "ACTIVE") {
                        CallStateStore.currentState = "ACTIVE"
                        CallStateStore.startTimeMs = System.currentTimeMillis()
                        if (CallStateStore.callerName == "Unknown Caller" && number.isNotEmpty()) {
                            CallStateStore.callerNumber = number
                            CallStateStore.callerName = resolveContactName(context, number)
                        }
                    }
                }
                TelephonyManager.EXTRA_STATE_IDLE -> {
                    CallStateStore.currentState = "IDLE"
                    CallStateStore.callerName = "Unknown Caller"
                    CallStateStore.callerNumber = ""
                    CallStateStore.callerLocation = "Mobile Call"
                    CallStateStore.startTimeMs = 0
                }
            }
        }
    }

    private fun resolveContactName(context: Context, number: String): String {
        if (number.isEmpty()) return "Unknown Caller"
        return try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
            val cursor: Cursor? = context.contentResolver.query(uri, projection, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIdx = it.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIdx != -1) {
                        return it.getString(nameIdx) ?: number
                    }
                }
            }
            number
        } catch (_: Exception) {
            if (number.isNotEmpty()) number else "Unknown Caller"
        }
    }
}
