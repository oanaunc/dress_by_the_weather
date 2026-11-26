package com.oanarinaldi.dressbytheweather

import android.Manifest
import android.app.*
import android.appwidget.*
import android.content.*
import android.content.pm.PackageManager
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.time.*
import java.time.format.DateTimeFormatter

class DressWidget:AppWidgetProvider() {
    override fun onUpdate(c:Context,manager:AppWidgetManager,ids:IntArray){ids.forEach{update(c,manager,it)}}
    companion object {
        fun refresh(c:Context){val manager=AppWidgetManager.getInstance(c);manager.getAppWidgetIds(ComponentName(c,DressWidget::class.java)).forEach{update(c,manager,it)}}
        fun update(c:Context,m:AppWidgetManager,id:Int) {
            val p=c.getSharedPreferences("dress",Context.MODE_PRIVATE);val now=System.currentTimeMillis();val fresh=now<(p.getLong("widgetValidUntil",0))
            val views=RemoteViews(c.packageName,R.layout.dress_widget)
            views.setTextViewText(R.id.widget_city,p.getString("widgetCity","Dress by the Weather"))
            views.setTextViewText(R.id.widget_temperature,p.getString("widgetTemperature","—"))
            views.setTextViewText(R.id.widget_weather,if(fresh)p.getString("widgetLabel","") else "Open for fresh weather")
            views.setTextViewText(R.id.widget_tip,p.getString("widgetTip","Your forecast. Your outfit."))
            val updated=p.getLong("widgetUpdated",0)
            views.setTextViewText(R.id.widget_updated,if(updated==0L) "Open the app to choose a city" else "Updated "+DateTimeFormatter.ofPattern("MMM d, HH:mm").format(Instant.ofEpochMilli(updated).atZone(ZoneId.systemDefault())))
            p.getString("widgetArt",null)?.let {name->runCatching {val b=c.assets.open("art/$name.jpg").use{BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply{inSampleSize=4})};views.setImageViewBitmap(R.id.widget_photo,b)}}
            val intent=Intent(c,MainActivity::class.java);val pending=PendingIntent.getActivity(c,0,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE);views.setOnClickPendingIntent(R.id.widget_root,pending)
            m.updateAppWidget(id,views)
        }
    }
}
class MorningReminder:BroadcastReceiver() {
    override fun onReceive(c:Context,intent:Intent) {
        val prefs=c.getSharedPreferences("dress",Context.MODE_PRIVATE);val p=runCatching{storageJson.decodeFromString<Preferences>(prefs.getString("preferences",null)?:"")}.getOrNull()?:return
        if(!p.reminderEnabled)return
        if(intent.action!=Intent.ACTION_BOOT_COMPLETED && (Build.VERSION.SDK_INT<33 || ContextCompat.checkSelfPermission(c,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED)) {
            val manager=c.getSystemService(NotificationManager::class.java);manager.createNotificationChannel(NotificationChannel("morning","Your morning outfit",NotificationManager.IMPORTANCE_DEFAULT))
            val pending=PendingIntent.getActivity(c,1,Intent(c,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            manager.notify(1,NotificationCompat.Builder(c,"morning").setSmallIcon(R.drawable.ic_notification).setContentTitle("Your forecast. Your outfit.").setContentText("Open Dress by the Weather for today’s fresh forecast and what to wear.").setContentIntent(pending).setAutoCancel(true).build())
        }
        schedule(c,true,p.reminderHour)
    }
    companion object {
        fun schedule(c:Context,enabled:Boolean,hour:Int) {
            val alarm=c.getSystemService(AlarmManager::class.java);val pending=PendingIntent.getBroadcast(c,22,Intent(c,MorningReminder::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending);if(!enabled)return
            val now=ZonedDateTime.now();var next=now.withHour(hour).withMinute(0).withSecond(0).withNano(0);if(!next.isAfter(now))next=next.plusDays(1)
            alarm.setWindow(AlarmManager.RTC_WAKEUP,next.toInstant().toEpochMilli(),15*60*1000L,pending)
        }
    }
}
