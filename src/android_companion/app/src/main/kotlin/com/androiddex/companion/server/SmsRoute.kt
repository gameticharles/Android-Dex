package com.androiddex.companion.server

import android.content.Context
import android.net.Uri
import android.provider.Telephony
import android.telephony.SmsManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * Real-Time SMS Conversations, Messages & Outbound Dispatch Route
 */
class SmsRoute(private val context: Context) {

    fun getConversationsJson(): String {
        val array = JSONArray()
        try {
            val projection = arrayOf(
                Telephony.Sms.Conversations.THREAD_ID,
                Telephony.Sms.Conversations.SNIPPET,
                Telephony.Sms.Conversations.DATE
            )

            val cursor = context.contentResolver.query(
                Telephony.Sms.Conversations.CONTENT_URI,
                projection,
                null,
                null,
                "${Telephony.Sms.Conversations.DATE} DESC"
            )

            cursor?.use {
                val threadIdIdx = it.getColumnIndex(Telephony.Sms.Conversations.THREAD_ID)
                val snippetIdx = it.getColumnIndex(Telephony.Sms.Conversations.SNIPPET)
                val dateIdx = it.getColumnIndex(Telephony.Sms.Conversations.DATE)

                while (it.moveToNext()) {
                    val threadId = it.getLong(threadIdIdx)
                    val snippet = it.getString(snippetIdx) ?: ""
                    val date = it.getLong(dateIdx)

                    val item = JSONObject().apply {
                        put("thread_id", threadId)
                        put("snippet", snippet)
                        put("date", date)
                        put("sender", "Thread #$threadId")
                    }
                    array.put(item)
                }
            }
        } catch (_: Exception) {}

        return JSONObject().put("status", "success").put("conversations", array).toString()
    }

    fun getMessagesForThreadJson(threadId: Long): String {
        val array = JSONArray()
        try {
            val cursor = context.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf("_id", "address", "body", "date", "type"),
                "thread_id = ?",
                arrayOf(threadId.toString()),
                "date ASC"
            )

            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")
                val typeIdx = it.getColumnIndex("type")

                while (it.moveToNext()) {
                    val address = it.getString(addressIdx) ?: ""
                    val body = it.getString(bodyIdx) ?: ""
                    val date = it.getLong(dateIdx)
                    val type = it.getInt(typeIdx) // 1 = inbox, 2 = sent

                    val item = JSONObject().apply {
                        put("address", address)
                        put("body", body)
                        put("date", date)
                        put("is_sent", type == 2)
                    }
                    array.put(item)
                }
            }
        } catch (_: Exception) {}

        return JSONObject().put("status", "success").put("messages", array).toString()
    }

    fun sendSms(recipient: String, message: String): Boolean {
        return try {
            val smsManager = context.getSystemService(SmsManager::class.java)
            smsManager?.sendTextMessage(recipient, null, message, null, null)
            true
        } catch (_: Exception) {
            false
        }
    }
}
