package com.example.dataradar

import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.dataradar/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "getRealDataUsage" -> {
                    val period = call.argument<String>("period") ?: "daily"
                    val network = call.argument<String>("network") ?: "all"
                    if (!hasUsageStatsPermission()) {
                        result.error("PERMISSION_DENIED", "يرجى منح صلاحية الوصول لبيانات الاستخدام", null)
                    } else {
                        try {
                            val data = querySystemNetworkStats(period, network)
                            result.success(data)
                        } catch (e: Exception) {
                            result.error("STATS_ERROR", e.localizedMessage, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getStartTimeMillis(period: String): Long {
        val cal = Calendar.getInstance()
        when (period) {
            "daily" -> {
                cal.set(Calendar.HOUR_OF_DAY, 0)
                cal.set(Calendar.MINUTE, 0)
                cal.set(Calendar.SECOND, 0)
                cal.set(Calendar.MILLISECOND, 0)
            }
            "weekly" -> {
                cal.add(Calendar.DAY_OF_YEAR, -7)
            }
            "monthly" -> {
                cal.set(Calendar.DAY_OF_MONTH, 1)
                cal.set(Calendar.HOUR_OF_DAY, 0)
                cal.set(Calendar.MINUTE, 0)
                cal.set(Calendar.SECOND, 0)
            }
        }
        return cal.timeInMillis
    }

    private fun querySystemNetworkStats(period: String, networkFilter: String): List<Map<String, Any>> {
        val networkStatsManager = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val pm = packageManager
        val startTime = getStartTimeMillis(period)
        val endTime = System.currentTimeMillis()

        // uid -> [rxDownBytes, txUpBytes, bgBytes]
        val uidStats = mutableMapOf<Int, LongArray>()

        val typesToQuery = when (networkFilter) {
            "mobile" -> listOf(ConnectivityManager.TYPE_MOBILE)
            "wifi" -> listOf(ConnectivityManager.TYPE_WIFI)
            else -> listOf(ConnectivityManager.TYPE_MOBILE, ConnectivityManager.TYPE_WIFI)
        }

        for (netType in typesToQuery) {
            try {
                val stats: NetworkStats = networkStatsManager.querySummary(netType, null, startTime, endTime)
                val bucket = NetworkStats.Bucket()
                while (stats.hasNextBucket()) {
                    stats.getNextBucket(bucket)
                    val uid = bucket.uid
                    val entry = uidStats.getOrPut(uid) { LongArray(3) }
                    entry[0] += bucket.rxBytes
                    entry[1] += bucket.txBytes
                    if (bucket.state == NetworkStats.Bucket.STATE_DEFAULT) {
                        entry[2] += (bucket.rxBytes + bucket.txBytes)
                    }
                }
                stats.close()
            } catch (_: Exception) {}
        }

        val appsList = mutableListOf<Map<String, Any>>()
        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (app in installedApps) {
            val values = uidStats[app.uid] ?: continue
            val totalBytes = values[0] + values[1]
            if (totalBytes <= 10240) continue

            val appName = pm.getApplicationLabel(app).toString()
            appsList.add(
                mapOf(
                    "appName" to appName,
                    "packageName" to app.packageName,
                    "uid" to app.uid,
                    "downloadMB" to (values[0].toDouble() / (1024.0 * 1024.0)),
                    "uploadMB" to (values[1].toDouble() / (1024.0 * 1024.0)),
                    "backgroundMB" to (values[2].toDouble() / (1024.0 * 1024.0)),
                    "totalMB" to (totalBytes.toDouble() / (1024.0 * 1024.0))
                )
            )
        }

        return appsList.sortedByDescending { it["totalMB"] as Double }
    }
}
