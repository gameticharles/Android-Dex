package com.androiddex.companion.server

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles security pairing requests, device verification, and authorization management.
 */
class PairingRoute(private val context: Context) {

    val deviceManager = PairedDeviceManager(context)

    fun handlePairingRequest(jsonStr: String, clientIp: String): String {
        return try {
            val req = JSONObject(jsonStr)
            val deviceId = req.optString("device_id", "").ifEmpty { req.optString("id", "") }
            val computerName = req.optString("computer_name", "").ifEmpty { req.optString("name", "DEX Desktop") }
            val ip = if (clientIp.isNotEmpty()) clientIp else req.optString("ip", "127.0.0.1")

            if (deviceId.isEmpty()) {
                return JSONObject().put("status", "FAILED").put("error", "Missing device_id").toString()
            }

            val computer = deviceManager.requestPairing(deviceId, computerName, ip)

            val res = JSONObject().apply {
                put("device_id", computer.id)
                put("computer_name", computer.name)
                put("status", computer.status)
                put("auto_connect", computer.autoConnect)
                if (computer.status == "APPROVED") {
                    put("auth_token", computer.authToken)
                }
            }
            res.toString()
        } catch (e: Exception) {
            JSONObject().put("status", "FAILED").put("error", e.message ?: "Invalid JSON").toString()
        }
    }

    fun handlePairingStatus(deviceId: String): String {
        if (deviceId.isEmpty()) {
            return JSONObject().put("status", "UNKNOWN").toString()
        }
        val computer = deviceManager.getComputerById(deviceId)
            ?: return JSONObject().put("status", "UNKNOWN").toString()

        val res = JSONObject().apply {
            put("device_id", computer.id)
            put("computer_name", computer.name)
            put("status", computer.status)
            put("auto_connect", computer.autoConnect)
            if (computer.status == "APPROVED") {
                put("auth_token", computer.authToken)
            }
        }
        return res.toString()
    }

    fun handlePairingRespond(deviceId: String, action: String, autoConnect: Boolean): String {
        val approve = action.lowercase() == "accept" || action.lowercase() == "approve"
        val computer = deviceManager.respondToPairing(deviceId, approve, autoConnect)
            ?: return JSONObject().put("status", "FAILED").put("error", "Device not found").toString()

        return JSONObject().apply {
            put("status", computer.status)
            put("device_id", computer.id)
            put("computer_name", computer.name)
            put("auto_connect", computer.autoConnect)
            if (approve) {
                put("auth_token", computer.authToken)
            }
        }.toString()
    }

    fun getPairedDevicesJson(): String {
        val list = deviceManager.getPairedComputers()
        val jsonArray = JSONArray()
        for (item in list) {
            jsonArray.put(item.toJson())
        }
        return JSONObject().put("status", "success").put("devices", jsonArray).toString()
    }

    fun handleUpdateDevice(deviceId: String, newName: String, autoConnect: Boolean): String {
        val ok = deviceManager.updateComputerDetails(deviceId, newName, autoConnect)
        return JSONObject().put("status", if (ok) "success" else "failed").toString()
    }

    fun handleDeleteDevice(deviceId: String): String {
        val ok = deviceManager.deleteComputer(deviceId)
        return JSONObject().put("status", if (ok) "success" else "failed").toString()
    }
}
