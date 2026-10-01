package lk.vitalu.vitalu

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Backs the Screen Time tracker's "Read from device" option with Android's
 * usage-stats API, filtered down to apps a student would actually recognise.
 *
 * The raw API (`UsageStatsManager`) reports every component's time "in
 * foreground", which includes the home launcher (counted as foreground for
 * the whole time the phone sits idle on the home screen) and other system
 * pieces — summing those naively inflates the total well past what a
 * device's own Digital Wellbeing / Screen Time figure shows. This filters
 * those out before totalling.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "vitalu/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasUsageAccess())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "screenTimeMinutes" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                    result.success(screenTimeMinutes(start, end))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageAccess(): Boolean {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        // An app with no usage-access grant always gets an empty list back,
        // even over a wide window, so this is the standard way to detect it.
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 1000L * 60 * 60 * 24, now)
        return stats != null && stats.isNotEmpty()
    }

    private fun screenTimeMinutes(start: Long, end: Long): Int {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager
        val launcherPackage = resolveLauncherPackage(pm)
        val selfPackage = packageName
        val stats = usm.queryAndAggregateUsageStats(start, end)
        var totalMs = 0L
        for ((pkg, usage) in stats) {
            if (pkg == launcherPackage || pkg == selfPackage) continue
            if (isSystemComponent(pkg)) continue
            // Keep only packages the student can actually open from an app
            // drawer/home screen — drops background system services.
            if (pm.getLaunchIntentForPackage(pkg) == null) continue
            totalMs += usage.totalTimeInForeground
        }
        return (totalMs / 60000L).toInt()
    }

    private fun resolveLauncherPackage(pm: PackageManager): String? {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
    }

    private fun isSystemComponent(pkg: String): Boolean {
        val denylist = setOf(
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.vending",
        )
        if (denylist.contains(pkg)) return true
        val lower = pkg.lowercase()
        return lower.contains("launcher") || lower.contains("inputmethod") || lower.contains("systemui")
    }
}
