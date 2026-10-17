package com.rochaplus.app

import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaLoadRequestData
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import android.widget.Toast
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.rochaplus.app/live_cast").setMethodCallHandler { call, result ->
            if (call.method != "loadLive") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val url = call.argument<String>("url") ?: throw IllegalArgumentException("Missing URL")
                val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
                metadata.putString(MediaMetadata.KEY_TITLE, call.argument<String>("title") ?: "Rocha+")
                val media = MediaInfo.Builder(url)
                    .setContentUrl(url)
                    .setContentType(call.argument<String>("contentType") ?: "application/x-mpegURL")
                    .setStreamType(MediaInfo.STREAM_TYPE_LIVE)
                    .setMetadata(metadata)
                    .build()
                val session = CastContext.getSharedInstance(this).sessionManager.currentCastSession
                val client = session?.remoteMediaClient
                if (session == null || !session.isConnected || client == null) {
                    result.error("cast_disconnected", "TV desconectada.", null)
                    return@setMethodCallHandler
                }
                // Never force time zero on a moving live window.
                val request = MediaLoadRequestData.Builder()
                    .setMediaInfo(media)
                    .setAutoplay(true)
                    .setCurrentTime(MediaLoadRequestData.PLAY_POSITION_UNASSIGNED)
                    .build()
                client.load(request).setResultCallback { response ->
                    if (response.status.isSuccess) result.success(null)
                    else result.error("cast_load_failed", "A TV não aceitou o canal.", response.status.statusCode)
                }
            } catch (_: Exception) {
                result.error("cast_load_failed", "Não foi possível carregar o canal na TV.", null)
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val volumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_MUTE
        if (!volumeKey) return super.dispatchKeyEvent(event)
        val session = try {
            CastContext.getSharedInstance(this).sessionManager.currentCastSession
        } catch (_: Exception) { null }
        if (session == null || !session.isConnected) return super.dispatchKeyEvent(event)
        if (event.action == KeyEvent.ACTION_DOWN) {
            try {
                if (event.keyCode == KeyEvent.KEYCODE_VOLUME_MUTE) {
                    if (event.repeatCount == 0) session.setMute(!session.isMute)
                } else {
                    val delta = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) 0.05 else -0.05
                    session.setVolume((session.volume + delta).coerceIn(0.0, 1.0))
                }
            } catch (_: Exception) {
                Toast.makeText(this, "Não foi possível alterar o volume da TV.", Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }
}
