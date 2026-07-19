package com.lsantosnet.voicenote_leo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget de tela inicial com um único botão: abre o app direto na tela de
 * gravação (a tela raiz do app). Não grava em segundo plano — o toque só
 * inicia a MainActivity em primeiro plano, como tocar no ícone do app.
 */
class NotaDeVozWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nota_de_voz_widget)
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
