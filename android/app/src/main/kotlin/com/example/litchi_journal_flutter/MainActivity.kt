package com.example.litchi_journal_flutter

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val BACKUP_CHANNEL = "litchi_journal/backup_download"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "enqueue") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val url = call.argument<String>("url")?.trim()
                val authorization = call.argument<String>("authorization")
                val fileName = call.argument<String>("fileName")?.trim()
                if (url.isNullOrEmpty() || authorization.isNullOrEmpty() ||
                    fileName.isNullOrEmpty() || fileName.contains("/") ||
                    fileName.contains("\\") || fileName.contains("..")) {
                    result.error("INVALID_ARGUMENT", "下载参数无效", null)
                    return@setMethodCallHandler
                }

                try {
                    val request = DownloadManager.Request(Uri.parse(url))
                        .setTitle("荔枝日记备份")
                        .setDescription("正在保存 ZIP 到下载目录")
                        .setMimeType("application/zip")
                        .setNotificationVisibility(
                            DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                        )
                        .setAllowedOverMetered(true)
                        .setAllowedOverRoaming(true)
                        .setDestinationInExternalPublicDir(
                            Environment.DIRECTORY_DOWNLOADS,
                            "荔枝日记备份/$fileName"
                        )
                    request.addRequestHeader("Authorization", authorization)
                    val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    result.success(manager.enqueue(request))
                } catch (_: Exception) {
                    result.error("BACKUP_DOWNLOAD_FAILED", "无法开始下载备份", null)
                }
            }
    }
}
