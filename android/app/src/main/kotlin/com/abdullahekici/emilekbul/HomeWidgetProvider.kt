package com.abdullahekici.emilekbul

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class HomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)
            bind(context, views, prefs)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bind(context: Context, views: RemoteViews, prefs: SharedPreferences) {
        val empty = context.getString(R.string.widget_empty)
        val streak = readInt(prefs, KEY_STREAK)
        val tokens = readInt(prefs, KEY_TOKENS)
        views.setTextViewText(R.id.widget_streak, streak?.toString() ?: empty)
        views.setTextViewText(R.id.widget_tokens, tokens?.toString() ?: empty)
    }

    // home_widget may store numbers as Int or Long depending on the Dart type; accept both.
    private fun readInt(prefs: SharedPreferences, key: String): Int? {
        return try {
            if (!prefs.contains(key)) null else prefs.all[key]?.let { (it as? Number)?.toInt() }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        const val KEY_STREAK = "widget_streak"
        const val KEY_TOKENS = "widget_tokens"
    }
}
