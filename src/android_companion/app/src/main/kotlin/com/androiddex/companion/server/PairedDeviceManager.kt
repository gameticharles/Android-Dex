package com.androiddex.companion.server

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Data model representing a paired DEX Desktop computer.
 */
data class PairedComputer(
    val id: String,                  // Unique Device ID / UUID from Desktop
    var name: String,                // Display name / Hostname (e.g., "Charles-Desktop")
    var status: String,              // "APPROVED", "PENDING", "REJECTED"
    var autoConnect: Boolean,        // Always auto-connect without prompt
    val authToken: String,           // Secure 32-character authentication token
    var lastConnectedAt: Long,       // Epoch timestamp of last active telemetry connection
    var ipAddress: String            // Last seen IP address
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("name", name)
            put("status", status)
            put("auto_connect", autoConnect)
            put("auth_token", authToken)
            put("last_connected_at", lastConnectedAt)
            put("ip_address", ipAddress)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): PairedComputer {
            return PairedComputer(
                id = json.optString("id", ""),
                name = json.optString("name", "Unknown Desktop"),
                status = json.optString("status", "PENDING"),
                autoConnect = json.optBoolean("auto_connect", false),
                authToken = json.optString("auth_token", UUID.randomUUID().toString().replace("-", "")),
                lastConnectedAt = json.optLong("last_connected_at", System.currentTimeMillis()),
                ipAddress = json.optString("ip_address", "127.0.0.1")
            )
        }
    }
}

/**
 * Persistent Manager storing and managing paired DEX computers in SharedPreferences.
 */
class PairedDeviceManager(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("dex_paired_computers_prefs", Context.MODE_PRIVATE)

    @Synchronized
    fun getPairedComputers(): MutableList<PairedComputer> {
        val jsonStr = prefs.getString("paired_list", "[]") ?: "[]"
        val list = mutableListOf<PairedComputer>()
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                list.add(PairedComputer.fromJson(obj))
            }
        } catch (_: Exception) {}
        return list
    }

    @Synchronized
    fun savePairedComputers(list: List<PairedComputer>) {
        val jsonArray = JSONArray()
        for (item in list) {
            jsonArray.put(item.toJson())
        }
        prefs.edit().putString("paired_list", jsonArray.toString()).apply()
    }

    @Synchronized
    fun getComputerById(id: String): PairedComputer? {
        return getPairedComputers().firstOrNull { it.id == id }
    }

    @Synchronized
    fun getComputerByAuthToken(token: String): PairedComputer? {
        if (token.isEmpty()) return null
        return getPairedComputers().firstOrNull { it.authToken == token && it.status == "APPROVED" }
    }

    @Synchronized
    fun requestPairing(deviceId: String, computerName: String, ip: String): PairedComputer {
        val list = getPairedComputers()
        var existing = list.firstOrNull { it.id == deviceId }

        if (existing != null) {
            existing.name = if (computerName.isNotEmpty()) computerName else existing.name
            existing.ipAddress = ip
            existing.lastConnectedAt = System.currentTimeMillis()
            savePairedComputers(list)
            return existing
        }

        // New Computer Request - Automatically paired & trusted
        val newToken = UUID.randomUUID().toString().replace("-", "")
        val newComputer = PairedComputer(
            id = deviceId,
            name = if (computerName.isNotEmpty()) computerName else "DEX Desktop",
            status = "APPROVED",
            autoConnect = true,
            authToken = newToken,
            lastConnectedAt = System.currentTimeMillis(),
            ipAddress = ip
        )
        list.add(newComputer)
        savePairedComputers(list)
        return newComputer
    }

    @Synchronized
    fun respondToPairing(deviceId: String, approve: Boolean, autoConnect: Boolean): PairedComputer? {
        val list = getPairedComputers()
        val target = list.firstOrNull { it.id == deviceId } ?: return null
        target.status = if (approve) "APPROVED" else "REJECTED"
        target.autoConnect = autoConnect
        target.lastConnectedAt = System.currentTimeMillis()
        savePairedComputers(list)
        return target
    }

    @Synchronized
    fun updateComputerDetails(deviceId: String, newName: String, autoConnect: Boolean): Boolean {
        val list = getPairedComputers()
        val target = list.firstOrNull { it.id == deviceId } ?: return false
        target.name = newName
        target.autoConnect = autoConnect
        savePairedComputers(list)
        return true
    }

    @Synchronized
    fun deleteComputer(deviceId: String): Boolean {
        val list = getPairedComputers()
        val removed = list.removeAll { it.id == deviceId }
        if (removed) {
            savePairedComputers(list)
        }
        return removed
    }

    @Synchronized
    fun updateLastConnected(deviceId: String) {
        val list = getPairedComputers()
        val target = list.firstOrNull { it.id == deviceId } ?: return
        target.lastConnectedAt = System.currentTimeMillis()
        savePairedComputers(list)
    }
}
