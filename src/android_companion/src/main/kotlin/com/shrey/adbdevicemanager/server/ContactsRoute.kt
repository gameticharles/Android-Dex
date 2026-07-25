package com.shrey.adbdevicemanager.server

import android.content.Context
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject

/**
 * Performance Fix #3: Paginated Contacts Endpoint (Kotlin / NanoHTTPD / Ktor)
 */
class ContactsRoute(private val context: Context) {

    fun getPaginatedContacts(offset: Int = 0, limit: Int = 50, includePhotos: Boolean = false): String {
        val json = JSONObject()
        val contactsArray = JSONArray()

        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )

        val cursor = context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection, null, null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )

        val totalCount = cursor?.count ?: 0
        var current = 0

        cursor?.use { c ->
            val idIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

            while (c.moveToNext()) {
                if (current in offset until (offset + limit)) {
                    val contactObj = JSONObject().apply {
                        put("id", c.getString(idIdx))
                        put("name", c.getString(nameIdx))
                        put("number", c.getString(numIdx))
                    }
                    contactsArray.put(contactObj)
                }
                current++
                if (current >= offset + limit) break
            }
        }

        return json.apply {
            put("status", "success")
            put("total", totalCount)
            put("offset", offset)
            put("limit", limit)
            put("contacts", contactsArray)
        }.toString()
    }
}
