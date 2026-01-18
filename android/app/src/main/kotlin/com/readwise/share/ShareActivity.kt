// android/app/src/main/kotlin/com/readwise/share/ShareActivity.kt
// Android Share Activity for receiving URLs from other apps

package com.readwise.share

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShareActivity : FlutterActivity() {
    
    private val CHANNEL = "com.readwise.app/share"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val sharedData = handleIntent(intent)
                    result.success(sharedData)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        
        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    return handleSendText(intent)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                // Handle multiple items if needed
            }
        }
        
        return null
    }
    
    private fun handleSendText(intent: Intent): Map<String, Any?>? {
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        
        if (sharedText != null) {
            // Extract URL from shared text
            val url = extractUrl(sharedText)
            
            if (url != null) {
                // Show confirmation toast
                Toast.makeText(this, "Saving to Readwise...", Toast.LENGTH_SHORT).show()
                
                return mapOf(
                    "type" to "url",
                    "url" to url,
                    "title" to sharedSubject
                )
            }
        }
        
        return null
    }
    
    private fun extractUrl(text: String): String? {
        // Simple URL extraction regex
        val urlPattern = "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+".toRegex()
        val match = urlPattern.find(text)
        return match?.value
    }
}
