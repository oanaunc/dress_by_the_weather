package com.oanarinaldi.dressbytheweather

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.time.*
import java.util.UUID
import kotlin.math.*

val ranges = listOf("Below −15°C", "−15 to −5°C", "−5 to 5°C", "5 to 10°C", "10 to 15°C", "15 to 20°C", "20 to 25°C", "25 to 30°C", "30 to 35°C", "35°C and above")
val titles = listOf("The deep winter edit", "Wrapped in warmth", "Winter, considered", "A little more layering", "The art of layering", "Light layers, easy days", "An effortless kind of day", "A lighter state of mind", "Made for the sunshine", "Keep your cool")
fun band(c: Double) = listOf(-15.0,-5.0,5.0,10.0,15.0,20.0,25.0,30.0,35.0).indexOfFirst { c < it }.let { if(it<0) 9 else it }
fun rounded(c: Double): Int = (if(c>=0) floor(c+.5) else ceil(c-.5)).toInt()
@Serializable enum class Occasion(val label: String) { Everyday("Everyday"),Office("Office"),Evening("Evening"),Active("Active") }
@Serializable data class Conditions(val temperature:Double,val windKmh:Double=0.0,val humidity:Double=50.0,val precipitationMm:Double=0.0,val symbol:String="clearsky_day") {
    val snow get()=symbol.contains("snow") || symbol.contains("sleet")
    val rain get()=precipitationMm>.1 || symbol.contains("rain") || symbol.contains("sleet")
    val storm get()=symbol.contains("thunder")
    val label get()=when { storm->"Thunderstorms";snow->"Snow / sleet";rain->"Rain";symbol.contains("fog")->"Foggy";symbol.contains("partlycloudy")||symbol.contains("fair")->"Partly cloudy";symbol.contains("cloudy")->"Cloudy";symbol.contains("night")->"Clear night";else->"Sunny" }
    val feelsLike get():Double {
        if(temperature<=10 && windKmh>4.8) { val w=windKmh.pow(.16);return 13.12+.6215*temperature-11.37*w+.3965*temperature*w }
        val vapour=humidity/100*6.105*exp(17.27*temperature/(237.7+temperature));return temperature+.33*vapour-.70*(windKmh/3.6)-4
    }
}
@Serializable data class Item(val category:String,val name:String,val fabric:String,val icon:String="tshirt") { val id get()=category+name }
data class Outfit(val band:Int,val style:Occasion,val items:List<Item>,val bring:List<String>,val explanation:String,val caution:String?,val imageName:String) {val title get()=titles[band];val range get()=ranges[band]}
object Dressing {
    fun recommend(w:Conditions,style:Occasion=Occasion.Everyday,comfort:Double=0.0):Outfit {
        val b=band(w.feelsLike-comfort+if(style==Occasion.Active) 3 else 0)
        val formal=style==Occasion.Office || style==Occasion.Evening
        var items=baseOutfits[b][if(formal) 1 else 0].toMutableList()
        if(style==Occasion.Active) items=items.map { i->when(i.category) {
            "Top"->Item("Top",if(b<4) "Wicking base & active midlayer" else "Breathable active top","Quick-drying technical fabric","tshirt")
            "Bottom"->Item("Bottom",if(b<6) "Technical trousers / leggings" else "Light active shorts","Stretch, quick-drying fabric","figure.run")
            "Footwear"->Item("Footwear","Supportive trainers","Grip suited to your route","shoe.2")
            else->i
        }}.toMutableList()
        val bring=mutableSetOf<String>()
        if(b<=2) bring.addAll(listOf("Gloves","Warm hat","Scarf")) else if(b==3) bring.add("Scarf")
        if(w.snow || w.rain) {
            items.removeAll{it.category in listOf("Outerwear","Layer")}
            items.add(0,Item("Outerwear",if(w.snow) "Insulated waterproof coat" else if(b<3) "Insulated rainproof coat" else "Breathable rain shell","Waterproof outer layer","jacket"))
            items.removeAll{it.category=="Footwear"};items.add(Item("Footwear",if(w.snow) "Waterproof winter boots" else "Water-resistant closed shoes","Grippy sole","shoe.2"))
            bring.addAll(if(w.snow) listOf("Warm hat","Gloves") else listOf(if(w.windKmh>=35) "Rain hood" else "Umbrella"))
        }
        if(w.windKmh>=25) bring.add("Windproof outer layer")
        if(w.temperature>=20 && !w.symbol.contains("night")) bring.addAll(listOf("Sunglasses","Sun protection","Water"))
        if(b>=8) bring.add("Sun hat")
        val caution=when { w.storm->"Thunderstorms forecast. Plan an indoor alternative and check local weather warnings.";w.temperature< -15->"Extreme cold. Limit exposure and check official local warnings.";w.temperature>=35->"Extreme heat. Seek shade, take breaks and follow local heat advice.";else->null }
        val category:String;val imageBand:Int
        if(w.snow || w.rain && b<3) { category="snow";imageBand=if(b<=1) 1 else 2 }
        else if(w.rain) { category="rain";imageBand=when {b<4->3;b<6->4;b<8->6;else->8} }
        else {category="dry";imageBand=b}
        val why="Chosen for an estimated feels-like temperature of ${rounded(w.feelsLike)}°C. "+(if(w.rain) "A waterproof outer layer keeps the rain out. " else "")+(if(w.windKmh>=25) "Wind protection matters today. " else "")+"Use removable layers to adjust your comfort."
        return Outfit(b,style,items,bring.sorted(),why,caution,"couple_${category}_${imageBand}_${style.ordinal}")
    }
}
@Serializable data class Hour(val time:Long,val conditions:Conditions,val intervalHours:Int=1)
data class Day(val date:String,val hours:List<Hour>) { val low get()=hours.minOf{it.conditions.temperature};val high get()=hours.maxOf{it.conditions.temperature};val representative get()=hours.firstOrNull{it.conditions.rain||it.conditions.snow}?:hours[hours.size/2] }
@Serializable data class Forecast(val updatedAt:Long,val fetchedAt:Long=System.currentTimeMillis(),val hours:List<Hour>,val sample:Boolean=false) {
    fun current(now:Long=System.currentTimeMillis())=hours.lastOrNull{it.time<=now}?:hours.firstOrNull()
    fun days(zone:String)=hours.groupBy{Instant.ofEpochMilli(it.time).atZone(ZoneId.of(zone)).toLocalDate().toString()}.toSortedMap().map{Day(it.key,it.value.sortedBy{h->h.time})}
    companion object {
        fun preview(now:Long=System.currentTimeMillis()):Forecast {
            val start=now/3600000*3600000
            return Forecast(now,now,(0..215).map { i->
                val rain=i/24 in listOf(2,5);Hour(start+i*3600000L,Conditions(28+sin((i%24)/24.0*PI*2)*3-(i/24)*.35,7.0,35.0,if(rain) 1.2 else 0.0,if(rain) "rain" else if(i%24>=12) "clearsky_night" else "fair_day"))
            },true)
        }
        fun parse(text:String,now:Long=System.currentTimeMillis()):Forecast {
            val p=Json.parseToJsonElement(text).jsonObject["properties"]!!.jsonObject
            val hours=p["timeseries"]!!.jsonArray.mapNotNull { v->
                val entry=v.jsonObject;val d=entry["data"]!!.jsonObject;val values=d["instant"]!!.jsonObject["details"]!!.jsonObject
                val t=values["air_temperature"]?.jsonPrimitive?.doubleOrNull ?: return@mapNotNull null
                if(!t.isFinite()) return@mapNotNull null
                val span=listOf(1,6,12).firstOrNull{d["next_${it}_hours"]!=null}?:12
                val period=d["next_${span}_hours"]?.jsonObject
                val cloud=values["cloud_area_fraction"]?.jsonPrimitive?.doubleOrNull?:0.0
                val symbol=period?.get("summary")?.jsonObject?.get("symbol_code")?.jsonPrimitive?.content?:if(cloud>75) "cloudy" else if(cloud>20) "partlycloudy_day" else "clearsky_day"
                Hour(Instant.parse(entry["time"]!!.jsonPrimitive.content).toEpochMilli(),Conditions(t,(values["wind_speed"]?.jsonPrimitive?.doubleOrNull?:0.0)*3.6,values["relative_humidity"]?.jsonPrimitive?.doubleOrNull?:50.0,period?.get("details")?.jsonObject?.get("precipitation_amount")?.jsonPrimitive?.doubleOrNull?:0.0,symbol),span)
            }
            require(hours.isNotEmpty()) {"The provider returned no forecast for this location."}
            return Forecast(Instant.parse(p["meta"]!!.jsonObject["updated_at"]!!.jsonPrimitive.content).toEpochMilli(),now,hours)
        }
    }
}
@Serializable data class City(val name:String,val latitude:Double,val longitude:Double,val zone:String) {
    val id get()="$latitude,$longitude"
    companion object {val Bucharest=City("Bucharest",44.4268,26.1025,"Europe/Bucharest");val suggestions=listOf(Bucharest,City("Paris",48.8566,2.3522,"Europe/Paris"),City("London",51.5074,-.1278,"Europe/London"),City("New York",40.7128,-74.0060,"America/New_York"),City("Tokyo",35.6762,139.6503,"Asia/Tokyo"))}
}
@Serializable enum class Category(val label:String) { Outerwear("Outerwear"),Top("Tops"),Midlayer("Knitwear"),Bottom("Bottoms"),Footwear("Shoes"),Accessory("Accessories");companion object{ fun forItem(c:String)=when(c){"Outerwear","Layer"->Outerwear;"Top","Base"->Top;"Midlayer"->Midlayer;"Bottom"->Bottom;"Footwear"->Footwear;else->Accessory} } }
@Serializable data class Garment(val id:String=UUID.randomUUID().toString(),val name:String="",val category:Category=Category.Top,val color:String="",val minimum:Double=5.0,val maximum:Double=25.0,val waterResistant:Boolean=false,val available:Boolean=true,val occasions:Set<Occasion> = Occasion.entries.toSet(),val photo:String?=null)
data class Match(val suggested:Item,val garment:Garment?) {val name get()=garment?.name?:suggested.name}
object WardrobeMatcher {
    fun match(outfit:Outfit,weather:Conditions,garments:List<Garment>,preferred:Set<String> = emptySet()):List<Match> {
        val used=mutableSetOf<String>()
        return outfit.items.map { i->
            val c=Category.forItem(i.category)
            val g=garments.filter{it.available && it.id !in used && it.category==c && outfit.style in it.occasions && weather.feelsLike in it.minimum..it.maximum && (!(weather.rain||weather.snow)||c !in listOf(Category.Outerwear,Category.Footwear)||it.waterResistant)}
                .sortedWith(compareBy<Garment>{if(it.id in preferred) 0 else 1}.thenBy{abs((it.minimum+it.maximum)/2-weather.feelsLike)}.thenBy{it.id}).firstOrNull()
            if(g!=null) used.add(g.id);Match(i,g)
        }
    }
}
@Serializable data class CapsuleDay(val date:String,val conditions:Conditions,val style:Occasion,val pieces:List<String>)
@Serializable data class CapsulePiece(val id:String,val name:String,val garmentID:String?,val category:String,val daysUsed:Int)
@Serializable data class CapsulePlan(val days:List<CapsuleDay>,val pieces:List<CapsulePiece>,val bring:List<String>) {val ownedCount get()=pieces.count{it.garmentID!=null};val checklist get()=pieces.map{it.name}+bring}
object CapsulePlanner {
    fun make(days:List<Day>,style:Occasion,comfort:Double,garments:List<Garment>):CapsulePlan {
        val pieces=linkedMapOf<String,CapsulePiece>();val preferred=mutableSetOf<String>();val bring=mutableSetOf<String>();val result=mutableListOf<CapsuleDay>()
        for(day in days.filter{it.hours.isNotEmpty()}) {
            val keys=mutableSetOf<String>();val names=mutableSetOf<String>()
            val samples=listOfNotNull(day.hours.minByOrNull{it.conditions.feelsLike},day.hours.maxByOrNull{it.conditions.feelsLike},day.hours.firstOrNull{it.conditions.rain||it.conditions.snow},day.hours.maxByOrNull{it.conditions.windKmh})
            for(sample in samples) {
                val o=Dressing.recommend(sample.conditions,style,comfort)
                for(m in WardrobeMatcher.match(o,sample.conditions,garments,preferred)) {
                    val key=m.garment?.let{"owned-"+it.id}?:"suggested-"+m.suggested.id
                    pieces.putIfAbsent(key,CapsulePiece(key,m.name,m.garment?.id,m.suggested.category,0));keys.add(key);names.add(m.name);m.garment?.let{preferred.add(it.id)}
                };bring.addAll(o.bring)
            }
            for(k in keys) pieces[k]=pieces[k]!!.copy(daysUsed=pieces[k]!!.daysUsed+1)
            result.add(CapsuleDay(day.date,day.representative.conditions,style,names.sorted()))
        }
        return CapsulePlan(result,pieces.values.sortedWith(compareByDescending<CapsulePiece>{it.daysUsed}.thenBy{it.name}),bring.sorted())
    }
}
@Serializable data class SavedLook(val id:String=UUID.randomUUID().toString(),val date:Long=System.currentTimeMillis(),val conditions:Conditions,val style:Occasion,val comfort:Double,val city:String)
@Serializable data class Trip(val id:String=UUID.randomUUID().toString(),val city:City,val start:String,val end:String,val items:List<String>,val checked:Set<String> = emptySet())
@Serializable data class PlannedOutfit(val cityID:String,val date:String,val style:Occasion,val variant:Int=0)
@Serializable data class SavedCapsule(val id:String=UUID.randomUUID().toString(),val city:City,val start:String,val end:String,val plan:CapsulePlan,val checked:Set<String> = emptySet())
@Serializable data class Editorial(val id:String,val collection:String,val band:Int,val range:String,val weather:String,val occasion:String)
@Serializable data class GuideNote(val title:String,val body:String)
@Serializable data class Guide(val id:String,val title:String,val subtitle:String,val collections:List<String>,val notes:List<GuideNote>)
@Serializable data class Preferences(val city:City=City.Bucharest,val cities:List<City> = listOf(City.Bucharest),val style:Occasion=Occasion.Everyday,val comfort:Double=0.0,val fahrenheit:Boolean=false,val onboarded:Boolean=false,val looks:List<SavedLook> = emptyList(),val trips:List<Trip> = emptyList(),val wardrobe:List<Garment> = emptyList(),val weekly:List<PlannedOutfit> = emptyList(),val capsules:List<SavedCapsule> = emptyList(),val favorites:Set<String> = emptySet(),val reminderHour:Int=8,val reminderEnabled:Boolean=false)
