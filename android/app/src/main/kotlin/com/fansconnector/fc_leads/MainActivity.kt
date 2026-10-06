package com.fansconnector.fc_leads

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Parcelable
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands messages and the audit graphic to WhatsApp, email apps or the
 * share sheet. The app never sends anything itself: the user taps Send
 * in the other app (WhatsApp and email apps do not allow anything else).
 */
class MainActivity : FlutterActivity() {

    private val whatsappPackages = listOf("com.whatsapp", "com.whatsapp.w4b")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fc_leads/share")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "whatsappChat" -> result.success(whatsappChat(call))
                        "whatsappImage" -> result.success(whatsappImage(call))
                        "email" -> result.success(email(call))
                        "shareFile" -> result.success(shareFile(call))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("share_failed", e.message ?: e.javaClass.simpleName, null)
                }
            }
    }

    private fun fileUri(path: String?): Uri? {
        if (path.isNullOrEmpty()) return null
        val file = File(path)
        if (!file.exists()) return null
        return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
    }

    /** Attaches [uri] so the receiving app is allowed to read it. */
    private fun Intent.attach(uri: Uri, mime: String) {
        type = mime
        putExtra(Intent.EXTRA_STREAM, uri)
        clipData = ClipData.newRawUri("", uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    private fun isInstalled(pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (e: Exception) {
        false
    }

    private fun whatsappPackage(): String? = whatsappPackages.firstOrNull { isInstalled(it) }

    /** Opens the chat with this number and types the message in. Reliable on every WhatsApp version. */
    private fun whatsappChat(call: MethodCall): String {
        val phone = call.argument<String>("phone") ?: ""
        val text = call.argument<String>("text") ?: ""
        val pkg = whatsappPackage() ?: return "not_installed"
        val uri = Uri.parse("https://api.whatsapp.com/send")
            .buildUpon()
            .appendQueryParameter("phone", phone)
            .appendQueryParameter("text", text)
            .build()
        startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(pkg))
        return "ok"
    }

    /** Sends the graphic to the chat with this number (caption optional). */
    private fun whatsappImage(call: MethodCall): String {
        val uri = fileUri(call.argument<String>("path")) ?: throw IllegalStateException("Graphic file not found")
        val phone = call.argument<String>("phone") ?: ""
        val text = call.argument<String>("text") ?: ""
        val pkg = whatsappPackage() ?: return "not_installed"
        val intent = Intent(Intent.ACTION_SEND).apply {
            setPackage(pkg)
            attach(uri, "image/png")
            if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            if (phone.isNotEmpty()) putExtra("jid", "$phone@s.whatsapp.net")
        }
        startActivity(intent)
        return "ok"
    }

    /**
     * Opens an email app with recipient, subject, body and the graphic.
     * Builds one targeted intent per installed email app, which works on
     * every Android version (the generic "selector" trick does not).
     */
    private fun email(call: MethodCall): String {
        val uri = fileUri(call.argument<String>("path"))
        val to = call.argument<String>("to") ?: ""
        val subject = call.argument<String>("subject") ?: ""
        val body = call.argument<String>("body") ?: ""

        val probe = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
        val apps = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.queryIntentActivities(probe, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(probe, 0)
        }.map { it.activityInfo.packageName }.distinct()

        fun build(pkg: String?) = Intent(Intent.ACTION_SEND).apply {
            if (pkg != null) setPackage(pkg)
            if (uri != null) attach(uri, "image/png") else type = "text/plain"
            if (to.isNotEmpty()) putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
        }

        if (apps.isEmpty()) {
            // No app answers mailto: try a plain mailto link (no attachment).
            val mailto = Uri.parse(
                "mailto:" + Uri.encode(to) + "?subject=" + Uri.encode(subject) + "&body=" + Uri.encode(body)
            )
            return try {
                startActivity(Intent(Intent.ACTION_SENDTO, mailto))
                "ok"
            } catch (e: ActivityNotFoundException) {
                "not_installed"
            }
        }
        if (apps.size == 1) {
            startActivity(build(apps.first()))
            return "ok"
        }
        val chooser = Intent.createChooser(build(apps.first()), "Send email with")
        val others: Array<Parcelable> = apps.drop(1).map { build(it) }.toTypedArray()
        chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, others)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(chooser)
        return "ok"
    }

    private fun shareFile(call: MethodCall): String {
        val uri = fileUri(call.argument<String>("path")) ?: throw IllegalStateException("File not found")
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        val text = call.argument<String>("text") ?: ""
        val subject = call.argument<String>("subject") ?: ""
        val intent = Intent(Intent.ACTION_SEND).apply {
            attach(uri, mime)
            if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        val chooser = Intent.createChooser(intent, "Share")
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(chooser)
        return "ok"
    }
}
