package com.androiddex.companion.server

import android.content.Context
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject

class ContactsRoute(private val context: Context) {

    fun getPaginatedContacts(offset: Int, limit: Int): String {
        val contactsArray = JSONArray()

        try {
            val cursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null,
                null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )

            cursor?.use { c ->
                var current = 0
                val total = c.count

                if (c.moveToPosition(offset)) {
                    do {
                        val id = c.getString(c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)) ?: ""
                        val name = c.getString(c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)) ?: "Unknown"
                        val number = c.getString(c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""

                        val contactJson = JSONObject().apply {
                            put("id", id)
                            put("name", name)
                            put("number", number)
                        }
                        contactsArray.put(contactJson)
                        current++
                    } while (c.moveToNext() && current < limit)
                }

                return JSONObject().apply {
                    put("status", "success")
                    put("offset", offset)
                    put("limit", limit)
                    put("total", total)
                    put("contacts", contactsArray)
                }.toString()
            }
        } catch (_: Exception) {}

        return JSONObject().apply {
            put("status", "error")
            put("contacts", JSONArray())
        }.toString()
    }
}
