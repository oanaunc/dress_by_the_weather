package com.oanarinaldi.dressbytheweather

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import android.location.*
import android.net.Uri
import android.os.*
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.compose.runtime.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.*
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.coroutines.resume
import kotlin.math.*

val storageJson=Json {ignoreUnknownKeys=true;encodeDefaults=true}
class DressApplication:Application()

/** Offline CC0 tz-lookup quad tree. No location is sent to a time-zone service. */
class TimeZones(text:String) {
    constructor(context:Context):this(context.assets.open("timezones.json").bufferedReader().use{it.readText()})
    private val root=storageJson.parseToJsonElement(text).jsonObject
    private val data=root["data"]!!.jsonPrimitive.content
    private val zones=root["zones"]!!.jsonArray.map{it.jsonPrimitive.content}
    fun at(lat:Double,lon:Double):String {
        require(lat.isFinite()&&lon.isFinite()&&lat in -90.0..90.0&&lon in -180.0..180.0)
        if(lat>=90) return "Etc/GMT"
        var v= -1;var s=48*(180+lon)/360.00000000000006;var u=24*(90-lat)/180.00000000000003
        var z=s.toInt();var row=u.toInt();var offset=96*row+2*z
        var k=56*data[offset].code+data[offset+1].code-1995
        var iterations=0
        while(k+zones.size<3136) {
            require(iterations++<40)
            v+=k+1;u=2*(u-row)%2;s=2*(s-z)%2;row=u.toInt();z=s.toInt()
            offset=8*v+4*row+2*z+2304;k=56*data[offset].code+data[offset+1].code-1995
        }
        return zones[k+zones.size-3136]
    }
}
@Serializable private data class CachedWeather(val forecast:Forecast,val expires:Long,val modified:String?=null)
class WeatherRepository(private val context:Context) {
    private val lock=Mutex()
    private var cooldown=0L
    private val root=File(context.cacheDir,"forecasts").apply{mkdirs()}
    suspend fun load(city:City):Forecast=withContext(Dispatchers.IO) { lock.withLock {
        val lat=(city.latitude*10000).toInt()/10000.0;val lon=(city.longitude*10000).toInt()/10000.0
        val file=File(root,"${lat}_${lon}.json")
        val cached=runCatching{storageJson.decodeFromString<CachedWeather>(file.readText())}.getOrNull()
        val now=System.currentTimeMillis()
        if(cached!=null && cached.expires>now) return@withLock cached.forecast
        check(now>=cooldown) {"The weather service is busy. Please try again later."}
        val connection=(URL("https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon").openConnection() as HttpURLConnection).apply {
            connectTimeout=20000;readTimeout=25000
            setRequestProperty("User-Agent","DressByTheWeather/1.0 Android https://github.com/oanaunc/dress_by_the_weather")
            setRequestProperty("Accept","application/json")
            cached?.modified?.let{setRequestProperty("If-Modified-Since",it)}
        }
        try {
            val status=connection.responseCode
            fun dateHeader(name:String)=runCatching{ZonedDateTime.parse(connection.getHeaderField(name),DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli()}.getOrNull()
            val expiry=max(now+3*3600000L,dateHeader("Expires")?:0L)
            if(status==429) { cooldown=connection.getHeaderField("Retry-After")?.toLongOrNull()?.let{now+it*1000}?:dateHeader("Retry-After")?:now+900000;error("The weather service is busy. Your last forecast is available; please try again later.") }
            val forecast=if(status==304 && cached!=null) cached.forecast.copy(fetchedAt=now) else {
                check(status==200) {"Weather is temporarily unavailable ($status). Try again later."}
                Forecast.parse(connection.inputStream.bufferedReader().use{it.readText()},now)
            }
            val entry=CachedWeather(forecast,expiry,connection.getHeaderField("Last-Modified")?:cached?.modified)
            val temp=File(root,file.name+".tmp");temp.writeText(storageJson.encodeToString(entry));if(!temp.renameTo(file)) {file.writeText(temp.readText());temp.delete()}
            forecast
        } finally {connection.disconnect()}
    } }
}
class Places(private val context:Context,private val zones:TimeZones) {
    private val cached=mutableMapOf<String,List<City>>()
    private val lock=Mutex();private var lastPhoton=0L
    private fun address(a:Address,query:String)=City(a.locality?:a.subAdminArea?:a.featureName?:query,a.latitude,a.longitude,zones.at(a.latitude,a.longitude))
    private suspend fun nativeGeocode(query:String):List<City> {
        if(!Geocoder.isPresent()) return emptyList()
        val g=Geocoder(context,Locale.getDefault())
        return if(Build.VERSION.SDK_INT>=33) withTimeout(8000) { suspendCancellableCoroutine { continuation->
            g.getFromLocationName(query,8,object:Geocoder.GeocodeListener {
                override fun onGeocode(addresses:MutableList<Address>) {if(continuation.isActive) continuation.resume(addresses.map{address(it,query)})}
                override fun onError(errorMessage:String?) {if(continuation.isActive) continuation.resume(emptyList())}
            })
        }} else withContext(Dispatchers.IO) {@Suppress("DEPRECATION") val results=g.getFromLocationName(query,8);results.orEmpty().map{address(it,query)}}
    }
    suspend fun search(query:String):List<City> {
        val q=query.trim();if(q.length<2) return emptyList()
        cached[q]?.let{return it}
        val coords=q.split(',').map{it.trim().toDoubleOrNull()}
        if(coords.size==2 && coords.all{it!=null} && coords[0]!! in -90.0..90.0 && coords[1]!! in -180.0..180.0) return listOf(City(q,coords[0]!!,coords[1]!!,zones.at(coords[0]!!,coords[1]!!)))
        val native=try{nativeGeocode(q)}catch(e:CancellationException){if(e !is TimeoutCancellationException) throw e;emptyList()}catch(_:Exception){emptyList()}
        if(native.isNotEmpty()) {cached[q]=native;return native}
        return withContext(Dispatchers.IO) {lock.withLock {
            val wait=1500-(System.currentTimeMillis()-lastPhoton);if(wait>0) delay(wait)
            lastPhoton=System.currentTimeMillis()
            val connection=(URL("https://photon.komoot.io/api/?q="+URLEncoder.encode(q,"UTF-8")+"&limit=8").openConnection() as HttpURLConnection).apply{connectTimeout=12000;readTimeout=12000;setRequestProperty("User-Agent","DressByTheWeather/1.0 https://github.com/oanaunc/dress_by_the_weather")}
            try {
                check(connection.responseCode==200){"Search is unavailable. Try a saved city."}
                val root=Json.parseToJsonElement(connection.inputStream.bufferedReader().use{it.readText()}).jsonObject
                val results=root["features"]!!.jsonArray.map{f->
                    val o=f.jsonObject;val xy=o["geometry"]!!.jsonObject["coordinates"]!!.jsonArray
                    val p=o["properties"]!!.jsonObject;val name=listOfNotNull(p["name"]?.jsonPrimitive?.content,p["city"]?.jsonPrimitive?.content,p["country"]?.jsonPrimitive?.content).distinct().joinToString(", ")
                    City(name,xy[1].jsonPrimitive.double,xy[0].jsonPrimitive.double,zones.at(xy[1].jsonPrimitive.double,xy[0].jsonPrimitive.double))
                }.distinctBy{it.id};cached[q]=results;results
            } finally{connection.disconnect()}
        }}
    }
    suspend fun currentName(lat:Double,lon:Double):String=withContext(Dispatchers.IO) {
        runCatching {@Suppress("DEPRECATION") val a=Geocoder(context).getFromLocation(lat,lon,1)?.firstOrNull();a?.locality?:a?.subAdminArea?:"Current location"}.getOrDefault("Current location")
    }
}
class DressModel @JvmOverloads constructor(app:Application,val demonstration:Boolean=false):AndroidViewModel(app) {
    private val prefs=app.getSharedPreferences(if(demonstration)"studio_sample"else"dress",Context.MODE_PRIVATE)
    var p by mutableStateOf(if(demonstration)Preferences()else runCatching{storageJson.decodeFromString<Preferences>(prefs.getString("preferences",null)?:"")}.getOrDefault(Preferences()));private set
    var forecast by mutableStateOf<Forecast?>(null);private set
    var loading by mutableStateOf(false);private set
    var error by mutableStateOf<String?>(null)
    var locating by mutableStateOf(false);private set
    var searchResults by mutableStateOf<List<City>>(emptyList());private set
    var searching by mutableStateOf(false);private set
    var searchError by mutableStateOf<String?>(null);private set
    var message by mutableStateOf<String?>(null)
    val zones=TimeZones(app);private val places=Places(app,zones);private val repository=WeatherRepository(app)
    val editorial:List<Editorial> = storageJson.decodeFromString(app.assets.open("lookbook.json").bufferedReader().use{it.readText()})
    val guides:List<Guide> = storageJson.decodeFromString(app.assets.open("guides.json").bufferedReader().use{it.readText()})
    private val art=app.assets.list("art").orEmpty().map{it.removeSuffix(".jpg")}.toSet()
    val pro=ProBilling(app)
    val studioAvailable get()=demonstration||pro.hasPro
    var startStudioDemo:()->Unit={}
    fun resetDemo(){check(demonstration);File(getApplication<Application>().filesDir,"DemoWardrobePhotos").deleteRecursively();p=Preferences();sample()}
    private var generation=0
    private var searchJob:Job?=null
    private var searchGeneration=0
    val now get()=System.currentTimeMillis()
    val current get()=forecast?.current()?.conditions
    val days get()=forecast?.days(p.city.zone).orEmpty()
    val upcoming get()=forecast?.hours?.filter{it.time>=now-3600000}.orEmpty()
    fun edit(block:(Preferences)->Preferences) {p=block(p);if(!demonstration){prefs.edit().putString("preferences",storageJson.encodeToString(p)).apply();writeWidget()}}
    fun temperature(c:Double)="${rounded(if(p.fahrenheit) c*9/5+32 else c)}°"
    fun date(time:Long,pattern:String="ha",zone:String=p.city.zone)=DateTimeFormatter.ofPattern(pattern,Locale.ENGLISH).format(Instant.ofEpochMilli(time).atZone(ZoneId.of(zone)))
    fun dayTitle(day:String,pattern:String="EEEE, MMM d")=DateTimeFormatter.ofPattern(pattern,Locale.ENGLISH).format(LocalDate.parse(day))
    fun artwork(o:Outfit,variant:Int=((LocalDate.now().toEpochDay()+719163L)%4).toInt()):String? {
        val replacements=mapOf("couple_rain_4_2" to "couple_rain_4_1","couple_rain_6_0" to "couple_rain_6_2","couple_rain_8_0" to "couple_rain_8_1","couple_rain_8_2" to "couple_rain_8_1")
        for(base in listOfNotNull(o.imageName,replacements[o.imageName])) for(i in 0..3) {val n="${base}_${(variant+i)%4}";if(n in art) return n}
        return null
    }
    fun outfit(w:Conditions,style:Occasion=p.style,comfort:Double=p.comfort)=Dressing.recommend(w,style,comfort)
    fun sample() {generation++;loading=false;forecast=Forecast.preview();error=null;edit{it.copy(onboarded=true)}}
    fun refresh() {if(demonstration)return;val g=++generation;val city=p.city;loading=true;error=null;viewModelScope.launch {
        try {val result=repository.load(city);if(g==generation) {forecast=result;writeWidget()}} catch(e:Exception){if(e is CancellationException) throw e;if(g==generation)error=e.message?:"Connect to the internet and try again."} finally{if(g==generation)loading=false}
    }}
    fun select(city:City) {if(demonstration){message="The Studio preview uses sample Bucharest weather. Exit preview for your live forecast.";return};edit{it.copy(city=city,cities=if(it.cities.any{c->c.id==city.id}) it.cities else it.cities+city,onboarded=true)};forecast=null;refresh()}
    fun search(query:String) {val generation=++searchGeneration;searchJob?.cancel();searchError=null;searchResults=emptyList();searching=query.trim().length>=2
        if(!searching) return
        searchJob=viewModelScope.launch {delay(600);try{searchResults=places.search(query);if(searchResults.isEmpty())searchError="No locations found. Try a city and country, or latitude, longitude."}catch(e:Exception){if(e is CancellationException)throw e;searchError=e.message?:"Search is unavailable. Try a saved city."}finally{if(generation==searchGeneration)searching=false}}
    }
    fun useLocation() {
        val app=getApplication<Application>()
        if(ContextCompat.checkSelfPermission(app,Manifest.permission.ACCESS_COARSE_LOCATION)!=PackageManager.PERMISSION_GRANTED){error="Choose a city or allow approximate location in Android Settings.";return}
        locating=true;error=null
        viewModelScope.launch {
            try {
                val lm=app.getSystemService(LocationManager::class.java)
                val location=withTimeout(20000) {suspendCancellableCoroutine<Location?> { c->
                    if(!lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {c.resume(null);return@suspendCancellableCoroutine}
                    if(Build.VERSION.SDK_INT>=30) {val signal=CancellationSignal();c.invokeOnCancellation{signal.cancel()};lm.getCurrentLocation(LocationManager.NETWORK_PROVIDER,signal,ContextCompat.getMainExecutor(app)){if(c.isActive)c.resume(it)}}
                    else {val listener=object:LocationListener{override fun onLocationChanged(l:Location){lm.removeUpdates(this);if(c.isActive)c.resume(l)};override fun onProviderEnabled(p:String){};override fun onProviderDisabled(p:String){};@Deprecated("Legacy") override fun onStatusChanged(p:String?,s:Int,b:Bundle?){} };c.invokeOnCancellation{lm.removeUpdates(listener)};@Suppress("DEPRECATION") lm.requestSingleUpdate(LocationManager.NETWORK_PROVIDER,listener,Looper.getMainLooper())}
                }} ?: error("Location is unavailable. Choose a city instead.")
                val city=City(places.currentName(location.latitude,location.longitude),location.latitude,location.longitude,zones.at(location.latitude,location.longitude));select(city)
            } catch(e:Exception){error="Your location couldn’t be found. Choose a city instead."} finally{locating=false}
        }
    }
    fun feedback(amount:Double) {edit{it.copy(comfort=(it.comfort+amount).coerceIn(-5.0,5.0))};message=if(amount==0.0) "Perfect. Your comfort profile stays as it is." else "Saved. Future outfits will use ${if(amount>0) "warmer" else "lighter"} layers."}
    fun saveLook(w:Conditions,s:Occasion,c:Double) {edit{it.copy(looks=listOf(SavedLook(conditions=w,style=s,comfort=c,city=it.city.name))+it.looks)}}
    fun plan(day:String,style:Occasion,variant:Int) {edit{it.copy(weekly=it.weekly.filterNot{d->d.cityID==it.city.id && d.date==day}+PlannedOutfit(it.city.id,day,style,variant))}}
    fun planned(day:String)=p.weekly.firstOrNull{it.cityID==p.city.id && it.date==day}
    fun clearPlan(day:String){edit{it.copy(weekly=it.weekly.filterNot{d->d.cityID==it.city.id && d.date==day})}}
    fun favorite(id:String){edit{it.copy(favorites=if(id in it.favorites)it.favorites-id else it.favorites+id)}}
    suspend fun saveGarment(g:Garment,photo:Uri?) {
        var garment=g.copy(minimum=min(g.minimum,g.maximum),maximum=max(g.minimum,g.maximum))
        if(photo!=null) withContext(Dispatchers.IO) {
            val app=getApplication<Application>();val opts=BitmapFactory.Options().apply{inJustDecodeBounds=true};app.contentResolver.openInputStream(photo).use{BitmapFactory.decodeStream(it,null,opts)}
            check(opts.outWidth>0 && opts.outHeight>0){"That photo couldn’t be loaded. Try another image."}
            var sample=1;while(max(opts.outWidth,opts.outHeight)/sample>2048)sample*=2
            val decoded=app.contentResolver.openInputStream(photo).use{BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply{inSampleSize=sample})}?:error("Photo unavailable")
            val exif=app.contentResolver.openInputStream(photo).use{stream->stream?.let{runCatching{ExifInterface(it)}.getOrNull()}}
            val matrix=Matrix().apply{if(exif?.isFlipped==true)postScale(-1f,1f);postRotate((exif?.rotationDegrees?:0).toFloat())}
            val bitmap=if(matrix.isIdentity)decoded else Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true).also{if(it!==decoded)decoded.recycle()}
            val scale=min(1.0,1024.0/max(bitmap.width,bitmap.height));val scaled=Bitmap.createScaledBitmap(bitmap,max(1,(bitmap.width*scale).toInt()),max(1,(bitmap.height*scale).toInt()),true)
            val filename=g.id+".jpg";photoFile(filename).outputStream().use{scaled.compress(Bitmap.CompressFormat.JPEG,82,it)};garment=garment.copy(photo=filename);if(scaled!==bitmap)scaled.recycle();bitmap.recycle()
        }
        edit{it.copy(wardrobe=listOf(garment)+it.wardrobe.filterNot{old->old.id==garment.id})}
    }
    fun photoFile(name:String)=File(getApplication<Application>().filesDir,if(demonstration)"DemoWardrobePhotos"else"WardrobePhotos").apply{mkdirs()}.resolve(File(name).name)
    fun removeGarment(g:Garment){g.photo?.let{photoFile(it).delete()};edit{it.copy(wardrobe=it.wardrobe.filterNot{old->old.id==g.id})}}
    fun clearStudio(){File(getApplication<Application>().filesDir,if(demonstration)"DemoWardrobePhotos"else"WardrobePhotos").deleteRecursively();edit{it.copy(wardrobe=emptyList(),weekly=emptyList(),capsules=emptyList(),favorites=emptySet())};message="Your saved Studio data has been removed from this device. Your Pro purchase is unchanged."}
    suspend fun makeTrip(city:City,start:String,end:String,capsule:Boolean,occasion:Occasion=p.style) {
        if(demonstration)check(city.id==p.city.id){"Choose Bucharest for the sample Studio. Exit preview to plan for a live destination."}
        val f=if((capsule||demonstration) && forecast?.sample==true && city.id==p.city.id) forecast!! else repository.load(city)
        val selected=f.days(city.zone).filter{it.date>=start && it.date<=end}
        check(selected.isNotEmpty() && selected.first().date==start && selected.last().date==end){"Choose dates within the next 8 days. Packing lists use actual forecasts, so later trips aren’t available yet."}
        if(capsule) {val plan=CapsulePlanner.make(selected,occasion,p.comfort,p.wardrobe);edit{it.copy(capsules=listOf(SavedCapsule(city=city,start=start,end=end,plan=plan))+it.capsules)}}
        else {val items=mutableSetOf<String>();for(d in selected) for(h in listOfNotNull(d.hours.minByOrNull{it.conditions.temperature},d.hours.maxByOrNull{it.conditions.temperature},d.hours.firstOrNull{it.conditions.rain||it.conditions.snow})) {val o=outfit(h.conditions);items.addAll(o.items.map{it.name});items.addAll(o.bring)};edit{it.copy(trips=listOf(Trip(city=city,start=start,end=end,items=items.sorted()))+it.trips)}}
    }
    private fun writeWidget(){if(demonstration)return;val f=forecast?:return;if(f.sample)return;val c=f.current()?.conditions?:return
        prefs.edit().putString("widgetCity",p.city.name).putString("widgetTemperature",temperature(c.temperature)).putString("widgetLabel",c.label).putString("widgetTip",outfit(c).items.firstOrNull()?.name).putLong("widgetUpdated",f.updatedAt).putLong("widgetValidUntil",f.fetchedAt+3*3600000L).putString("widgetArt",artwork(outfit(c))).apply();DressWidget.refresh(getApplication())
    }
    fun reminder(enable:Boolean,hour:Int=p.reminderHour){if(demonstration){message="Exit the Studio preview to change your reminders.";return};edit{it.copy(reminderEnabled=enable,reminderHour=hour)};MorningReminder.schedule(getApplication(),enable,hour);message=if(enable)"Your daily reminder is set for $hour:00. Open the app for fresh weather." else "Daily reminder turned off."}
    override fun onCleared(){pro.close();super.onCleared()}
}
