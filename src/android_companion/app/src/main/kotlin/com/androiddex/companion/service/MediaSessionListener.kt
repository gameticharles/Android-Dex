package com.androiddex.companion.service

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Real-Time MediaSession & Artwork Extractor for Android Dex
 * Compatible with Android 5.0 (API 21) through Android 15+ (API 35+).
 */
class MediaSessionListener(
    private val context: Context,
    private val onMediaChanged: (JSONObject) -> Unit
) {

    private val mediaSessionManager =
        context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

    private var activeController: MediaController? = null
    private var cachedArtworkKey: String? = null
    private var cachedArtworkBase64: String? = null

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
            if (!controllers.isNullOrEmpty()) {
                selectAndAttachController(controllers)
            }

            mediaSessionManager.addOnActiveSessionsChangedListener({ newControllers ->
                if (!newControllers.isNullOrEmpty()) {
                    selectAndAttachController(newControllers)
                } else {
                    broadcastFallbackMedia()
                }
            }, componentName)
        } catch (_: Exception) {
            broadcastFallbackMedia()
        }
    }

    private fun selectAndAttachController(controllers: List<MediaController>) {
        val playingController = controllers.firstOrNull { 
            it.playbackState?.state == PlaybackState.STATE_PLAYING 
        } ?: controllers.firstOrNull()

        if (playingController != null && playingController != activeController) {
            activeController?.unregisterCallback(controllerCallback)
            activeController = playingController
            playingController.registerCallback(controllerCallback, Handler(Looper.getMainLooper()))
            broadcastCurrentMedia()
        }
    }

    fun seekTo(positionMs: Long): Boolean {
        return try {
            val controller = activeController ?: return false
            controller.transportControls?.seekTo(positionMs)
            broadcastCurrentMedia()
            true
        } catch (_: Exception) {
            false
        }
    }

    fun sendTransportCommand(cmd: String): Boolean {
        return try {
            val controller = activeController ?: return false
            val controls = controller.transportControls ?: return false
            when (cmd.lowercase()) {
                "play" -> controls.play()
                "pause" -> controls.pause()
                "next", "skip_next" -> controls.skipToNext()
                "prev", "skip_prev", "previous" -> controls.skipToPrevious()
                "stop" -> controls.stop()
                else -> return false
            }
            broadcastCurrentMedia()
            true
        } catch (_: Exception) {
            false
        }
    }

    fun broadcastCurrentMedia() {
        val controller = activeController ?: run {
            broadcastFallbackMedia()
            return
        }

        val metadata = controller.metadata
        val playbackState = controller.playbackState
        val description = metadata?.description

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: description?.title?.toString()
            ?: "Dex Stream"

        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_AUTHOR)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
            ?: description?.subtitle?.toString()
            ?: "Android Audio Engine"

        var rawAlbum = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_DESCRIPTION)
            ?: ""

        var album = ""
        if (rawAlbum.isNotEmpty() &&
            !rawAlbum.lowercase().contains("www.") &&
            !rawAlbum.lowercase().contains(".com") &&
            !rawAlbum.lowercase().contains(".net") &&
            !rawAlbum.lowercase().contains(".org") &&
            rawAlbum != title) {
            album = rawAlbum
        }

        var durationMs = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        if (durationMs <= 0L) {
            val extras = metadata?.description?.extras ?: playbackState?.extras
            if (extras != null) {
                durationMs = extras.getLong("android.media.metadata.DURATION", 0L)
                if (durationMs <= 0L) durationMs = extras.getLong("duration", 0L)
                if (durationMs <= 0L) durationMs = extras.getInt("duration", 0).toLong()
                if (durationMs <= 0L) durationMs = extras.getLong("duration_ms", 0L)
            }
        }

        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING
        var positionMs = playbackState?.position ?: 0L
        if (isPlaying && playbackState != null && playbackState.lastPositionUpdateTime > 0L) {
            val elapsedMs = android.os.SystemClock.elapsedRealtime() - playbackState.lastPositionUpdateTime
            if (elapsedMs > 0L) {
                val speed = if (playbackState.playbackSpeed > 0f) playbackState.playbackSpeed else 1.0f
                positionMs += (elapsedMs * speed).toLong()
            }
        }
        if (durationMs > 0L && positionMs > durationMs) {
            positionMs = durationMs
        }
        val lastPositionUpdateTime = System.currentTimeMillis()
        val packageName = controller.packageName ?: ""

        var artworkBitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: description?.iconBitmap

        val artUriStr = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ART_URI)
            ?: description?.iconUri?.toString()

        if (artworkBitmap == null && !artUriStr.isNullOrEmpty()) {
            try {
                val uri = android.net.Uri.parse(artUriStr)
                val input = context.contentResolver.openInputStream(uri)
                if (input != null) {
                    artworkBitmap = android.graphics.BitmapFactory.decodeStream(input)
                    input.close()
                }
            } catch (_: Exception) {}
        }

        val currentTrackKey = "$title|$artist|$album|$artUriStr"
        val artworkBase64 = if (currentTrackKey == cachedArtworkKey && cachedArtworkBase64 != null) {
            cachedArtworkBase64
        } else {
            val b64 = artworkBitmap?.let { encodeBitmapToSafeBase64(it, maxDimension = 300) }
            cachedArtworkKey = currentTrackKey
            cachedArtworkBase64 = b64
            b64
        }
        val appIconBase64 = getAppIconBase64(packageName)

        val json = JSONObject().apply {
            put("title", title)
            put("artist", artist)
            put("album", album)
            put("package_name", packageName)
            put("is_playing", isPlaying)
            put("position_ms", positionMs)
            put("last_position_update_time", lastPositionUpdateTime)
            put("duration_ms", durationMs)
            if (artworkBase64 != null) {
                put("artwork_base64", artworkBase64)
            }
            if (!artUriStr.isNullOrEmpty()) {
                put("artwork_url", artUriStr)
            }
            if (appIconBase64 != null) {
                put("app_icon_base64", appIconBase64)
            }
        }

        onMediaChanged(json)
    }

    private fun encodeBitmapToSafeBase64(bitmap: Bitmap, maxDimension: Int): String? {
        return try {
            val width = bitmap.width
            val height = bitmap.height
            val scaledBitmap = if (width > maxDimension || height > maxDimension) {
                val ratio = width.toFloat() / height.toFloat()
                val targetW = if (ratio >= 1) maxDimension else (maxDimension * ratio).toInt()
                val targetH = if (ratio < 1) maxDimension else (maxDimension / ratio).toInt()
                Bitmap.createScaledBitmap(bitmap, targetW.coerceAtLeast(1), targetH.coerceAtLeast(1), true)
            } else {
                bitmap
            }

            val stream = ByteArrayOutputStream()
            // Standard JPEG compression supported on all Android versions (API 1+)
            scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    private fun getAppIconBase64(packageName: String): String? {
        if (packageName.isEmpty()) return null
        return try {
            val pm = context.packageManager
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            encodeBitmapToSafeBase64(bitmap, maxDimension = 128)
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is android.graphics.drawable.BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val bitmap = if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
            Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        } else {
            Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
        }
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun broadcastFallbackMedia() {
        val json = JSONObject().apply {
            put("title", "No Active Media")
            put("artist", "Android DEX Audio Engine")
            put("album", "")
            put("package_name", "")
            put("is_playing", false)
            put("position_ms", 0)
            put("last_position_update_time", System.currentTimeMillis())
            put("duration_ms", 0)
        }
        onMediaChanged(json)
    }
}
