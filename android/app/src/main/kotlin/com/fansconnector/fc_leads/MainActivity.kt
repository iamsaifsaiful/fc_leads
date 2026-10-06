package com.fansconnector.fc_leads

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands the rendered audit graphic to WhatsApp or an email app.
 *
 * The app never sends anything itself: it opens the other app with the
 * image, text and recipient filled in, and the user taps Send there.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fc_leads/share")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "whatsapp" -> result.success(shareToWhatsApp(call))
                        "email" -> result.success(shareToEmail(call))
                        "share" -> result.success(shareAnywhere(call))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("share_failed", e.message, null)
                }
            }
    }

    private fun imageUri(path: String?): Uri? {
        if (path.isNullOrEmpty()) return null
        val file = File(path)
        if (!file.exists()) return null
        return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: Exception) {
        false
    }

    /** Returns "ok", or "not_installed" when no WhatsApp app is on the phone. */
    private fun shareToWhatsApp(call: MethodCall): String {
        val uri = imageUri(call.argument<String>("path"))
        val phone = call.argument<String>("phone") ?: ""
        val text = call.argument<String>("text") ?: ""
        val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { isInstalled(it) }
            ?: return "not_installed"

        val intent = Intent(Intent.ACTION_SEND).apply {
            setPackage(pkg)
            if (uri != null) {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                type = "text/plain"
            }
            putExtra(Intent.EXTRA_TEXT, text)
            // Opens the chat with this number directly instead of the contact picker.
            if (phone.isNotEmpty()) putExtra("jid", "$phone@s.whatsapp.net")
        }
        startActivity(intent)
        return "ok"
    }

    private fun shareToEmail(call: MethodCall): String {
        val uri = imageUri(call.argument<String>("path"))
        val to = call.argument<String>("to") ?: ""
        val subject = call.argument<String>("subject") ?: ""
        val body = call.argument<String>("body") ?: ""

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = if (uri != null) "image/png" else "text/plain"
            if (to.isNotEmpty()) putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
            if (uri != null) {
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            // Limit the chooser to email apps.
            selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
        }
        return try {
            startActivity(Intent.createChooser(intent, "Send email"))
            "ok"
        } catch (e: ActivityNotFoundException) {
            "not_installed"
        }
    }

    private fun shareAnywhere(call: MethodCall): String {
        val uri = imageUri(call.argument<String>("path"))
        val text = call.argument<String>("text") ?: ""
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = if (uri != null) "image/png" else "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (uri != null) {
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        startActivity(Intent.createChooser(intent, "Share"))
        return "ok"
    }
}
