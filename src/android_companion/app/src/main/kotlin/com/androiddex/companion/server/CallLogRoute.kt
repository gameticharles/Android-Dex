package com.androiddex.companion.server

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.CallLog
import android.telecom.TelecomManager
import com.androiddex.companion.service.CallStateStore
import org.json.JSONArray
import org.json.JSONObject

/**
 * Call Logs & Telephony Control Route
 */
class CallLogRoute(private val context: Context) {

    fun getCallStateJson(): String {
        return JSONObject()
            .put("status", "success")
            .put("call", CallStateStore.toJson())
            .toString()
    }

    fun answerCall(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                telecomManager?.acceptRingingCall()
            } else {
                val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_HEADSETHOOK))
                }
                context.sendOrderedBroadcast(intent, null)
            }
            CallStateStore.currentState = "ACTIVE"
            CallStateStore.startTimeMs = System.currentTimeMillis()
            true
        } catch (_: Exception) {
            // Fallback via shell/keyevent
            try {
                Runtime.getRuntime().exec("input keyevent 5")
                CallStateStore.currentState = "ACTIVE"
                CallStateStore.startTimeMs = System.currentTimeMillis()
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    fun endCall(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                telecomManager?.endCall()
            } else {
                Runtime.getRuntime().exec("input keyevent 6")
            }
            CallStateStore.currentState = "IDLE"
            CallStateStore.startTimeMs = 0
            true
        } catch (_: Exception) {
            try {
                Runtime.getRuntime().exec("input keyevent 6")
                CallStateStore.currentState = "IDLE"
                CallStateStore.startTimeMs = 0
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    fun toggleSpeaker(): Boolean {
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                val newSpeakerState = !audioManager.isSpeakerphoneOn
                audioManager.isSpeakerphoneOn = newSpeakerState
                audioManager.mode = AudioManager.MODE_IN_CALL
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    fun getCallLogsJson(): String {
        val array = JSONArray()
        try {
            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION
                ),
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )

            cursor?.use {
                val numberIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
                val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
                val durationIdx = it.getColumnIndex(CallLog.Calls.DURATION)

                while (it.moveToNext()) {
                    val number = it.getString(numberIdx) ?: ""
                    val name = it.getString(nameIdx) ?: number
                    val type = it.getInt(typeIdx)
                    val date = it.getLong(dateIdx)
                    val duration = it.getLong(durationIdx)

                    val typeStr = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "INCOMING"
                        CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
                        CallLog.Calls.MISSED_TYPE -> "MISSED"
                        else -> "OTHER"
                    }

                    val item = JSONObject().apply {
                        put("number", number)
                        put("name", name)
                        put("type", typeStr)
                        put("date", date)
                        put("duration_sec", duration)
                    }
                    array.put(item)
                }
            }
        } catch (_: Exception) {}

        return JSONObject().put("status", "success").put("calls", array).toString()
    }

    fun dialNumber(number: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
