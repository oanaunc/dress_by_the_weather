package com.oanarinaldi.dressbytheweather

import org.junit.Test
import org.junit.Assert.*
import kotlinx.serialization.json.*
import java.io.File
import java.util.zip.GZIPInputStream
import java.security.*
import java.util.Base64
import java.time.*

class ParityTests {
    @Test fun androidMatchesShippingSwiftEngine() {
        val input=GZIPInputStream(javaClass.getResourceAsStream("/engine-parity.json.gz")!!).bufferedReader().use{it.readText()}
        val rows=storageJson.parseToJsonElement(input).jsonArray
        assertEquals(9360,rows.size)
        for((i,value) in rows.withIndex()) {
            val r=value.jsonObject;val w=storageJson.decodeFromJsonElement<Conditions>(r["weather"]!!);val o=Dressing.recommend(w,Occasion.valueOf(r["style"]!!.jsonPrimitive.content),r["comfort"]!!.jsonPrimitive.double)
            assertEquals("case $i band",r["band"]!!.jsonPrimitive.int,o.band)
            assertEquals("case $i clothing",storageJson.decodeFromJsonElement<List<Item>>(r["items"]!!),o.items)
            assertEquals("case $i accessories",storageJson.decodeFromJsonElement<List<String>>(r["bring"]!!),o.bring)
            assertEquals("case $i explanation",r["explanation"]!!.jsonPrimitive.content,o.explanation)
            assertEquals("case $i caution",r["caution"]?.jsonPrimitive?.content,o.caution)
            assertEquals("case $i image collection",r["image"]!!.jsonPrimitive.content,o.imageName)
            assertEquals("case $i feels-like",r["feelsLike"]!!.jsonPrimitive.double,w.feelsLike,1e-8)
        }
    }
    @Test fun temperatureBoundaries(){assertEquals(0,band(-15.01));assertEquals(1,band(-15.0));assertEquals(2,band(-5.0));assertEquals(3,band(5.0));assertEquals(4,band(10.0));assertEquals(5,band(15.0));assertEquals(6,band(20.0));assertEquals(7,band(25.0));assertEquals(8,band(30.0));assertEquals(9,band(35.0));assertEquals(-3,rounded(-2.5));assertEquals(3,rounded(2.5))}
    @Test fun rainDoesNotSubstituteUnprotectedShoes() {
        val w=Conditions(16.0,10.0,70.0,2.0,"rain");val o=Dressing.recommend(w)
        val wrong=Garment(name="Canvas sneakers",category=Category.Footwear,minimum=-10.0,maximum=35.0)
        val correct=wrong.copy(id="rain-shoes",name="Rain shoes",waterResistant=true)
        val result=WardrobeMatcher.match(o,w,listOf(wrong,correct))
        assertEquals("Rain shoes",result.first{it.suggested.category=="Footwear"}.name)
        assertNull(WardrobeMatcher.match(o,w,listOf(wrong)).first{it.suggested.category=="Footwear"}.garment)
    }
    @Test fun laundryComfortOccasionAndNoDuplicateUse(){val w=Conditions(20.0);val o=Dressing.recommend(w,Occasion.Office);val g=Garment(name="Shirt",category=Category.Top,minimum=-30.0,maximum=45.0);assertTrue(WardrobeMatcher.match(o,w,listOf(g.copy(available=false))).all{it.garment==null});assertTrue(WardrobeMatcher.match(o,w,listOf(g.copy(occasions=setOf(Occasion.Active)))).all{it.garment==null});assertTrue(WardrobeMatcher.match(o,w,listOf(g.copy(minimum=30.0))).all{it.garment==null});val ids=WardrobeMatcher.match(o,w,listOf(g)).mapNotNull{it.garment?.id};assertEquals(ids.size,ids.toSet().size)}
    @Test fun capsulesReuseAndCoverExtremes(){val w=Conditions(20.0,4.0,35.0);val days=(0..6).map{i->Day("2026-11-${20+i}",listOf(Hour(i*86400000L,w),Hour(i*86400000L+3600000,w.copy(temperature=0.0)),Hour(i*86400000L+7200000,w.copy(precipitationMm=2.0,symbol="rain",windKmh=40.0))))};val g=Garment(name="Own coat",category=Category.Outerwear,minimum=-30.0,maximum=45.0,waterResistant=true);val p=CapsulePlanner.make(days,Occasion.Everyday,0.0,listOf(g));assertEquals(7,p.days.size);assertEquals(7,p.pieces.first{it.garmentID==g.id}.daysUsed);assertTrue("Windproof outer layer" in p.bring);assertTrue(p.pieces.any{it.name.contains("Water-resistant")});assertTrue(p.pieces.any{it.name.contains("Warm trousers")});assertEquals(1,p.ownedCount)}
    @Test fun emptyCapsuleHasNoInventedDays(){val p=CapsulePlanner.make(emptyList(),Occasion.Everyday,0.0,emptyList());assertTrue(p.days.isEmpty());assertTrue(p.checklist.isEmpty())}
    @Test fun sparseMetFieldsAndDestinationDayBoundaries(){val text="""{"properties":{"meta":{"updated_at":"2026-11-26T00:00:00Z"},"timeseries":[{"time":"2026-11-26T23:00:00Z","data":{"instant":{"details":{"air_temperature":18,"wind_speed":2,"cloud_area_fraction":90}},"next_6_hours":{"summary":{"symbol_code":"rain"},"details":{"precipitation_amount":2}}}},{"time":"2026-11-27T05:00:00Z","data":{"instant":{"details":{"air_temperature":12,"cloud_area_fraction":50}}}}]}}""";val f=Forecast.parse(text);assertEquals(2,f.hours.size);assertEquals(6,f.hours.first().intervalHours);assertEquals(7.2,f.hours.first().conditions.windKmh,1e-8);assertTrue(f.hours.first().conditions.rain);assertEquals("partlycloudy_day",f.hours.last().conditions.symbol);assertEquals(1,f.days("Asia/Tokyo").size);assertEquals(2,f.days("Europe/London").size);assertFalse(f.sample)}
    @Test fun malformedEmptyWeatherDoesNotBecomeSample(){assertTrue(runCatching{Forecast.parse("""{"properties":{"meta":{"updated_at":"2026-11-26T00:00:00Z"},"timeseries":[]}}""")}.isFailure)}
    @Test fun globalOfflineTimeZones(){val zones=TimeZones(File(System.getProperty("dress.assets"),"timezones.json").readText());val cases=listOf(Triple(44.4268,26.1025,"Europe/Bucharest"),Triple(-33.8688,151.2093,"Australia/Sydney"),Triple(35.6762,139.6503,"Asia/Tokyo"),Triple(40.7128,-74.006,"America/New_York"),Triple(-36.8485,174.7633,"Pacific/Auckland"),Triple(27.7172,85.324,"Asia/Kathmandu"));for((lat,lon,zone)in cases)assertEquals(zone,zones.at(lat,lon));assertTrue(runCatching{zones.at(91.0,0.0)}.isFailure)}
    @Test fun purchaseProofRejectsTamperingAndWrongKeys(){val keys=KeyPairGenerator.getInstance("RSA").apply{initialize(2048)}.generateKeyPair();val key=Base64.getEncoder().encodeToString(keys.public.encoded);val payload="""{"productId":"dress_pro_lifetime","purchaseState":0}""";val signature=Signature.getInstance("SHA1withRSA").run{initSign(keys.private);update(payload.toByteArray());Base64.getEncoder().encodeToString(sign())};assertTrue(PurchaseVerification.verify(key,payload,signature));assertFalse(PurchaseVerification.verify(key,payload+" ",signature));assertFalse(PurchaseVerification.verify("",payload,signature));val other=KeyPairGenerator.getInstance("RSA").apply{initialize(2048)}.generateKeyPair();assertFalse(PurchaseVerification.verify(Base64.getEncoder().encodeToString(other.public.encoded),payload,signature))}
    @Test fun persistentStudioRoundTrip(){val p=Preferences(wardrobe=listOf(Garment(name="My shirt")),weekly=listOf(PlannedOutfit(City.Bucharest.id,"2026-11-26",Occasion.Office,2)),favorites=setOf("couple_dry_5_1_0"));assertEquals(p,storageJson.decodeFromString<Preferences>(storageJson.encodeToString(Preferences.serializer(),p)))}
}
