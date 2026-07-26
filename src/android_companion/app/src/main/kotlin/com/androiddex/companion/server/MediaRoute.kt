package com.androiddex.companion.server

import android.content.Context
import com.androiddex.companion.service.MediaSessionListener
import org.json.JSONObject

/**
 * Real-Time Media & Artwork Stream Route
 */
class MediaRoute(private val context: Context) {

    private var latestMediaJson = JSONObject().apply {
        put("title", "No Active Media")
        put("artist", "Android DEX Audio Engine")
        put("album", "")
        put("package_name", "")
        put("is_playing", false)
        put("position_ms", 0)
        put("duration_ms", 225000)
    }

    private val mediaListener = MediaSessionListener(context) { newMedia ->
        latestMediaJson = newMedia
    }

    fun init() {
        mediaListener.startListening()
    }

    fun getMediaStateJson(): String {
        return latestMediaJson.toString()
    }
}
