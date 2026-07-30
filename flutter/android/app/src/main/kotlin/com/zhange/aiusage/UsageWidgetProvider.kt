package com.zhange.aiusage

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class UsageWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, buildViews(context, false)) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            listOf(
                UsageWidgetProvider::class.java to false,
                AppStyleUsageWidgetProvider::class.java to true,
            ).forEach { (provider, appStyle) ->
                val component = ComponentName(context, provider)
                manager.getAppWidgetIds(component).forEach {
                    manager.updateAppWidget(it, buildViews(context, appStyle))
                }
            }
        }

        fun buildViews(context: Context, appStyle: Boolean): RemoteViews {
            val layout = if (appStyle) R.layout.widget_usage_app else R.layout.widget_usage
            val views = RemoteViews(context.packageName, layout)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.snapshotCache", null)
                ?: prefs.getString("snapshotCache", null)
            val showClaude = readBool(prefs.all, "display.showClaudeUsage")
            val showCodex = readBool(prefs.all, "display.showCodexUsage")
            val root = runCatching { json?.let(::JSONObject) }.getOrNull()

            bindSource(
                views,
                root,
                "claudeLimits",
                showClaude,
                R.id.claude_row,
                R.id.claude_percent,
                R.id.claude_reset,
                R.id.claude_progress,
            )
            bindSource(
                views,
                root,
                "codexLimits",
                showCodex,
                R.id.codex_row,
                R.id.codex_percent,
                R.id.codex_reset,
                R.id.codex_progress,
            )
            bindProjects(views, root, showClaude, showCodex)

            if (root == null) {
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                views.setTextViewText(R.id.empty_state, "打开 App 同步")
            } else if (!showClaude && !showCodex) {
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                views.setTextViewText(R.id.empty_state, "用量显示已关闭")
            } else {
                views.setViewVisibility(R.id.empty_state, View.GONE)
            }

            val costs = visibleCosts(root, showClaude, showCodex)
            views.setTextViewText(R.id.today_cost, "今日 ${usd(costs.first)}")
            views.setTextViewText(R.id.month_cost, "本月 ${usd(costs.second)}")

            val launchIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            return views
        }

        private fun bindSource(
            views: RemoteViews,
            root: JSONObject?,
            limitsKey: String,
            visible: Boolean,
            rowID: Int,
            percentID: Int,
            resetID: Int,
            progressID: Int,
        ) {
            val window = root
                ?.optJSONObject(limitsKey)
                ?.optJSONArray("windows")
                ?.optJSONObject(0)
            if (!visible || window == null) {
                views.setViewVisibility(rowID, View.GONE)
                return
            }
            val utilization = window.optDouble("utilization", 0.0).coerceIn(0.0, 100.0)
            views.setViewVisibility(rowID, View.VISIBLE)
            views.setTextViewText(percentID, "${utilization.toInt()}%")
            views.setTextViewText(resetID, countdown(window.optString("resetsAt")))
            views.setProgressBar(progressID, 100, utilization.toInt(), false)
        }

        private data class RankedProject(
            val name: String,
            val source: String,
            val cost: Double,
            val tokens: Long,
        )

        private fun bindProjects(
            views: RemoteViews,
            root: JSONObject?,
            showClaude: Boolean,
            showCodex: Boolean,
        ) {
            val projects = root?.optJSONArray("projects")
            val ranked = buildList {
                if (projects != null) {
                    for (index in 0 until projects.length()) {
                        val project = projects.optJSONObject(index) ?: continue
                        val source = project.optString("source")
                        if ((source == "claude" && !showClaude) ||
                            (source == "codex" && !showCodex)
                        ) {
                            continue
                        }
                        val tally = project.optJSONObject("tally") ?: JSONObject()
                        add(
                            RankedProject(
                                name = project.optString("name").ifBlank { "未知项目" },
                                source = if (source == "claude") "Claude" else "Codex",
                                cost = tally.optDouble("costUSD", 0.0),
                                tokens = tally.optLong("input", 0) +
                                    tally.optLong("output", 0) +
                                    tally.optLong("cacheRead", 0) +
                                    tally.optLong("cacheWrite", 0),
                            ),
                        )
                    }
                }
            }.sortedWith(
                compareByDescending<RankedProject> { it.cost }
                    .thenByDescending { it.tokens },
            )

            views.setViewVisibility(
                R.id.project_ranking,
                if (ranked.isEmpty()) View.GONE else View.VISIBLE,
            )
            bindProjectRow(
                views,
                ranked.getOrNull(0),
                1,
                R.id.project_row_1,
                R.id.project_name_1,
                R.id.project_cost_1,
            )
            bindProjectRow(
                views,
                ranked.getOrNull(1),
                2,
                R.id.project_row_2,
                R.id.project_name_2,
                R.id.project_cost_2,
            )
        }

        private fun bindProjectRow(
            views: RemoteViews,
            project: RankedProject?,
            rank: Int,
            rowID: Int,
            nameID: Int,
            costID: Int,
        ) {
            if (project == null) {
                views.setViewVisibility(rowID, View.GONE)
                return
            }
            views.setViewVisibility(rowID, View.VISIBLE)
            views.setTextViewText(nameID, "#$rank ${project.name} · ${project.source}")
            views.setTextViewText(costID, usd(project.cost))
        }

        private fun visibleCosts(
            root: JSONObject?,
            showClaude: Boolean,
            showCodex: Boolean,
        ): Pair<Double, Double> {
            val days = root?.optJSONArray("days") ?: return 0.0 to 0.0
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val month = today.substring(0, 7)
            var todayCost = 0.0
            var monthCost = 0.0
            for (index in 0 until days.length()) {
                val day = days.optJSONObject(index) ?: continue
                var cost = 0.0
                if (showClaude) cost += day.optJSONObject("claude")?.optDouble("costUSD", 0.0) ?: 0.0
                if (showCodex) cost += day.optJSONObject("codex")?.optDouble("costUSD", 0.0) ?: 0.0
                val key = day.optString("day")
                if (key == today) todayCost = cost
                if (key.startsWith(month)) monthCost += cost
            }
            return todayCost to monthCost
        }

        private fun readBool(values: Map<String, *>, key: String): Boolean {
            val value = values["flutter.$key"] ?: values[key] ?: return true
            return value as? Boolean ?: true
        }

        private fun usd(value: Double): String =
            String.format(Locale.US, "$%.2f", value)

        private fun countdown(raw: String): String {
            if (raw.isBlank()) return "—"
            val reset = parseISO(raw) ?: return "—"
            val seconds = (reset.time - System.currentTimeMillis()) / 1000
            if (seconds <= 0) return "即将重置"
            val days = seconds / 86_400
            val hours = (seconds % 86_400) / 3_600
            val minutes = (seconds % 3_600) / 60
            return when {
                days > 0 -> "${days}天 ${hours}小时"
                hours > 0 -> "${hours}小时 ${minutes}分"
                else -> "${minutes}分钟"
            }
        }

        private fun parseISO(raw: String): Date? {
            val formats = listOf(
                "yyyy-MM-dd'T'HH:mm:ss.SSSX",
                "yyyy-MM-dd'T'HH:mm:ssX",
            )
            for (pattern in formats) {
                val parsed = runCatching {
                    SimpleDateFormat(pattern, Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.parse(raw)
                }.getOrNull()
                if (parsed != null) return parsed
            }
            return null
        }
    }
}

class AppStyleUsageWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach {
            appWidgetManager.updateAppWidget(
                it,
                UsageWidgetProvider.buildViews(context, true),
            )
        }
    }
}
