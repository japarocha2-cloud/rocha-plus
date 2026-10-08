package com.rochaplus.app

import android.view.KeyEvent
import android.widget.Toast
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
