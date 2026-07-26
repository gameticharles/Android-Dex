package com.androiddex.companion.service

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.util.Base64
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Real-Time MediaSession & Artwork Extractor for Android Dex
 */
class MediaSessionListener(
    private val context: Context,
    private val onMediaChanged: (JSONObject) -> Unit
) {

    private val mediaSessionManager =
        context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

    private var activeController: MediaController? = null

    private val controllerCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            broadcastCurrentMedia()
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            broadcastCurrentMedia()
        }
    }

    fun startListening() {
        try {
            val componentName = ComponentName(context, DexNotificationListenerService::class.java)
            val controllers = mediaSessionManager.getActiveSessions(componentName)
            if (controllers.isNotEmpty()) {
                attachController(controllers[0])
            }

            mediaSessionManager.addOnActiveSessionsChangedListener({ newControllers ->
                if (!newControllers.isNullOrEmpty()) {
                    attachController(newControllers[0])
                }
            }, componentName)
        } catch (_: Exception) {
            broadcastFallbackMedia()
        }
    }

    private fun attachController(controller: MediaController) {
        activeController?.unregisterCallback(controllerCallback)
        activeController = controller
        controller.registerCallback(controllerCallback, Handler(Looper.getMainLooper()))
        broadcastCurrentMedia()
    }

    fun broadcastCurrentMedia() {
        val controller = activeController ?: run {
            broadcastFallbackMedia()
            return
        }

        val metadata = controller.metadata
        val playbackState = controller.playbackState

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: "Dex Stream"

        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_AUTHOR)
            ?: "Android Audio Engine"

        val album = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        val durationMs = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 225000L
        val positionMs = playbackState?.position ?: 0L
        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING

        val artworkBitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)

        var artworkBase64: String? = null
        if (artworkBitmap != null) {
            try {
                val stream = ByteArrayOutputStream()
                artworkBitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, 75, stream)
                artworkBase64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
            } catch (_: Exception) {}
        }

        val json = JSONObject().apply {
            put("title", title)
            put("artist", artist)
            put("album", album)
            put("package_name", controller.packageName ?: "")
            put("is_playing", isPlaying)
            put("position_ms", positionMs)
            put("duration_ms", durationMs)
            if (artworkBase64 != null) {
                put("artwork_base64", artworkBase64)
            }
        }

        onMediaChanged(json)
    }

    private fun broadcastFallbackMedia() {
        val json = JSONObject().apply {
            put("title", "No Active Media")
            put("artist", "Android DEX Audio Engine")
            put("album", "")
            put("package_name", "")
            put("is_playing", false)
            put("position_ms", 0)
            put("duration_ms", 225000)
        }
        onMediaChanged(json)
    }
}
