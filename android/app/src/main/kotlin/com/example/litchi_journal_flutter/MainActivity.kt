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
        private const val BACKUP_PREFERENCES = "litchi_journal_backup_download"
        private const val LATEST_DOWNLOAD_ID = "latest_download_id"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueue" -> enqueueBackup(call.arguments as? Map<*, *>, result)
                    "query" -> queryBackup(call.argument<Number>("downloadId")?.toLong(), result)
                    "queryLatest" -> queryBackup(latestDownloadId(), result)
                    "clearLatest" -> {
                        preferences().edit().remove(LATEST_DOWNLOAD_ID).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enqueueBackup(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val url = (arguments?.get("url") as? String)?.trim()
        val authorization = arguments?.get("authorization") as? String
        val fileName = (arguments?.get("fileName") as? String)?.trim()
        if (url.isNullOrEmpty() || authorization.isNullOrEmpty() ||
            fileName.isNullOrEmpty() || fileName.contains("/") ||
            fileName.contains("\\") || fileName.contains("..")) {
            result.error("INVALID_ARGUMENT", "下载参数无效", null)
            return
        }

        try {
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("荔枝日记备份")
                .setDescription("正在保存 ZIP 到下载目录")
                .setMimeType("application/zip")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setDestinationInExternalPublicDir(
                    Environment.DIRECTORY_DOWNLOADS,
                    "荔枝日记备份/$fileName"
                )
            request.addRequestHeader("Authorization", authorization)
            val id = downloadManager().enqueue(request)
            preferences().edit().putLong(LATEST_DOWNLOAD_ID, id).apply()
            result.success(id)
        } catch (_: Exception) {
            result.error("BACKUP_DOWNLOAD_FAILED", "无法开始下载备份", null)
        }
    }

    private fun queryBackup(downloadId: Long?, result: MethodChannel.Result) {
        if (downloadId == null || downloadId < 0) {
            result.success(null)
            return
        }
        try {
            downloadManager().query(DownloadManager.Query().setFilterById(downloadId)).use { cursor ->
                if (!cursor.moveToFirst()) {
                    result.success(null)
                    return
                }
                val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                result.success(
                    mapOf(
                        "downloadId" to downloadId,
                        "state" to downloadState(status),
                        "error" to downloadError(status, reason),
                        "downloadedBytes" to cursor.getLong(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                        ),
                        "totalBytes" to cursor.getLong(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                        )
                    )
                )
            }
        } catch (_: Exception) {
            result.error("BACKUP_DOWNLOAD_QUERY_FAILED", "无法读取下载状态", null)
        }
    }

    private fun downloadState(status: Int): String = when (status) {
        DownloadManager.STATUS_SUCCESSFUL -> "success"
        DownloadManager.STATUS_FAILED -> "failed"
        DownloadManager.STATUS_RUNNING -> "running"
        DownloadManager.STATUS_PAUSED -> "paused"
        else -> "pending"
    }

    private fun downloadError(status: Int, reason: Int): String? {
        if (status != DownloadManager.STATUS_FAILED) return null
        return when (reason) {
            DownloadManager.ERROR_INSUFFICIENT_SPACE -> "手机存储空间不足，备份未保存"
            DownloadManager.ERROR_CANNOT_RESUME -> "备份下载中断且无法继续，请重试"
            DownloadManager.ERROR_HTTP_DATA_ERROR -> "备份下载数据异常，请重试"
            DownloadManager.ERROR_UNHANDLED_HTTP_CODE -> "备份服务器返回异常，请重试"
            else -> "备份下载失败，请重试"
        }
    }

    private fun latestDownloadId(): Long? {
        val value = preferences().getLong(LATEST_DOWNLOAD_ID, -1L)
        return if (value >= 0) value else null
    }

    private fun preferences() = getSharedPreferences(BACKUP_PREFERENCES, Context.MODE_PRIVATE)

    private fun downloadManager() =
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
}
