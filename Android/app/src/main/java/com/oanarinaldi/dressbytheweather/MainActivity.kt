package com.oanarinaldi.dressbytheweather

import android.Manifest
import android.os.*
import android.content.*
import android.content.pm.PackageManager
import androidx.activity.*
import androidx.activity.compose.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.*
import java.time.*
import java.util.UUID

class MainActivity:ComponentActivity() {
    private lateinit var model:DressModel
    override fun onCreate(state:Bundle?) {
        super.onCreate(state);enableEdgeToEdge()
        if(BuildConfig.DEBUG && intent.getBooleanExtra("reset",false)){getSharedPreferences("dress",MODE_PRIVATE).edit().clear().commit()}
        model=ViewModelProvider(this)[DressModel::class.java]
        val nav=ViewModelProvider(this)[Navigator::class.java]
        val demoFactory=object:ViewModelProvider.Factory{override fun <T:ViewModel>create(modelClass:Class<T>):T {@Suppress("UNCHECKED_CAST") return DressModel(application,true) as T}}
        val studioSample=ViewModelProvider(this,demoFactory)["studio-sample",DressModel::class.java]
        val sampleNav=ViewModelProvider(this)["sample-navigation",Navigator::class.java]
        if(BuildConfig.DEBUG && intent.getBooleanExtra("sample",false)){model.sample();model.pro.preview(intent.getBooleanExtra("proPreview",false))}
        setContent {
            var sampleStudio by rememberSaveable{mutableStateOf(false)}
            model.startStudioDemo={studioSample.resetDemo();sampleNav.selectTab("Looks");sampleNav.open("pro");sampleStudio=true}
            val location=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){allowed->if(allowed)model.useLocation() else model.error="Choose any city without sharing your device location."}
            val notifications=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){allowed->if(allowed)model.reminder(true) else model.message="Notifications are off. Enable them in Android Settings to receive reminders."}
            nav.location={if(ContextCompat.checkSelfPermission(this,Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED)model.useLocation() else location.launch(Manifest.permission.ACCESS_COARSE_LOCATION)}
            nav.enableReminder={if(Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(this,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)notifications.launch(Manifest.permission.POST_NOTIFICATIONS) else model.reminder(true)}
            sampleNav.location={studioSample.message="Exit preview to use your location."}
            sampleNav.enableReminder={studioSample.message="Exit preview to set a reminder."}
            DressTheme {if(sampleStudio)DressApp(studioSample,sampleNav){studioSample.resetDemo();sampleStudio=false}else DressApp(model,nav)}
        }
    }
    override fun onResume(){super.onResume();if(::model.isInitialized){model.pro.refresh();if(model.p.onboarded && model.forecast?.sample!=true)model.refresh()}}
}
data class Destination(val screen:String,val id:String="",val weather:Conditions?=null,val style:Occasion=Occasion.Everyday,val comfort:Double?=null,val token:String=UUID.randomUUID().toString())
class Navigator:ViewModel() {
    var tab by mutableStateOf("Today")
    val stack=mutableStateListOf<Destination>()
    val current get()=stack.lastOrNull()
    var location:()->Unit={};var enableReminder:()->Unit={}
    var tripCity by mutableStateOf<City?>(null)
    var tripStart by mutableStateOf(LocalDate.now().toString())
    var tripEnd by mutableStateOf(LocalDate.now().plusDays(2).toString())
    var tripOccasion by mutableStateOf(Occasion.Everyday)
    fun open(d:Destination){stack.add(d)}
    fun open(screen:String,id:String=""){open(Destination(screen,id))}
    fun back(){if(stack.isNotEmpty())stack.removeAt(stack.lastIndex)}
    fun selectTab(value:String){tab=value;stack.clear()}
    fun newTrip(m:DressModel,capsule:Boolean){tripCity=if(capsule)m.p.city else null;val today=LocalDate.now(ZoneId.of((tripCity?:m.p.city).zone));tripStart=today.toString();tripEnd=today.plusDays(2).toString();tripOccasion=m.p.style;open(if(capsule)"newCapsule" else "newTrip")}
}
@Composable fun DressApp(m:DressModel,n:Navigator,onExitDemo:(()->Unit)?=null) {
    val d=n.current
    BackHandler(d!=null||onExitDemo!=null){if(d!=null)n.back()else onExitDemo?.invoke()}
    val holder=rememberSaveableStateHolder()
    val backdrop=rememberGraphicsLayer()
    val statusInset=WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val insets=statusInset+if(onExitDemo!=null)44.dp else 0.dp
    val wide=LocalConfiguration.current.screenWidthDp>=600
    Box(Modifier.fillMaxSize().background(Paper)) {
        Box(Modifier.fillMaxSize().drawWithContent{backdrop.record{this@drawWithContent.drawContent()};drawLayer(backdrop)}.padding(top=insets+if(d!=null)64.dp else if(wide&&m.p.onboarded)90.dp else 0.dp)) {
            holder.SaveableStateProvider(d?.token?:n.tab) {
                if(!m.p.onboarded) OnboardingScreen(m,n)
                else if(d==null) when(n.tab){"Today"->TodayScreen(m,n);"Forecast"->ForecastScreen(m,n);"Looks"->LooksScreen(m,n);"Planner"->PlannerScreen(m,n);else->SettingsScreen(m,n)}
                else {
                    val gated=d.screen in setOf("week","wardrobe","garment","capsules","newCapsule","capsule","library","guide","editorial")
                    if(gated && !m.studioAvailable) ProPaywallScreen(m) else when(d.screen) {
                        "outfit"->OutfitScreen(m,n,d)
                        "day"->DayScreen(m,n,d.id)
                        "locations"->LocationsScreen(m,n,d.id)
                        "pro"->if(m.studioAvailable) StudioScreen(m,n) else ProPaywallScreen(m)
                        "week"->WeeklyScreen(m,n)
                        "wardrobe"->WardrobeScreen(m,n)
                        "garment"->GarmentScreen(m,n,d.id)
                        "capsules"->CapsuleHomeScreen(m,n)
                        "newTrip","newCapsule"->NewTripScreen(m,n,d.screen=="newCapsule")
                        "trip"->PackingScreen(m,n,d.id)
                        "capsule"->CapsuleDetailScreen(m,n,d.id)
                        "library"->LibraryScreen(m,n)
                        "guide"->GuideScreen(m,n,d.id)
                        "editorial"->EditorialScreen(m,n,d.id)
                        "privacy"->PrivacyScreen(m)
                        "credits"->CreditsScreen()
                        "widgets"->WidgetHelpScreen()
                    }
                }
            }
        }
        if(onExitDemo!=null)Row(Modifier.align(Alignment.TopCenter).padding(top=statusInset).height(44.dp).fillMaxWidth().background(Sand).padding(horizontal=20.dp),verticalAlignment=Alignment.CenterVertically){Text("Sample Studio · changes are temporary",Modifier.weight(1f),fontSize=11.sp,color=Ink);TextButton(onExitDemo){Text("Exit preview",color=Ink)}}
        if(d!=null) {
            Row(Modifier.fillMaxWidth().padding(top=insets,start=18.dp,end=18.dp).height(64.dp).background(Paper.copy(alpha=.94f)),verticalAlignment=Alignment.CenterVertically) {
                CircleAction(Icons.Outlined.ChevronLeft,"Back"){n.back()}
                Text(screenTitle(d),Modifier.weight(1f),fontSize=17.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.SemiBold,color=Ink,textAlign=androidx.compose.ui.text.style.TextAlign.Center)
                if(d.screen in setOf("outfit","locations","day","editorial")) TextButton({n.back()}){Text("Done",color=Ink)} else Spacer(Modifier.width(48.dp))
            }
        }
        if(m.p.onboarded && d==null) {
            var position by remember{mutableStateOf(androidx.compose.ui.geometry.Offset.Zero)}
            Box(Modifier.align(if(wide)Alignment.TopCenter else Alignment.BottomCenter).then(if(wide)Modifier.padding(top=insets)else Modifier.navigationBarsPadding()).padding(horizontal=14.dp,vertical=8.dp).widthIn(max=560.dp).fillMaxWidth().height(if(wide)64.dp else 82.dp).shadow(12.dp,RoundedCornerShape(38.dp)).clip(RoundedCornerShape(38.dp)).onGloballyPositioned{position=it.positionInRoot()}) {
                Box(Modifier.matchParentSize().graphicsLayer{renderEffect=BlurEffect(20f,20f)}.drawWithContent{translate(-position.x,-position.y){drawLayer(backdrop)}})
                Box(Modifier.matchParentSize().background(Brush.verticalGradient(listOf(Color.White.copy(alpha=.74f),Sand.copy(alpha=.7f)))).border(1.dp,Color.White.copy(alpha=.9f),RoundedCornerShape(38.dp)))
                Row(Modifier.fillMaxSize().padding(6.dp),horizontalArrangement=Arrangement.SpaceEvenly) {
                    listOf("Today","Forecast","Looks","Planner","You").forEachIndexed{i,tab->Column(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(32.dp)).background(if(n.tab==tab)Olive.copy(alpha=.12f)else Color.Transparent).clickable{n.selectTab(tab)},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center){NavigationMark(tab);Spacer(Modifier.height(5.dp));Text(tab,fontSize=12.sp,color=Ink,fontWeight=if(n.tab==tab)androidx.compose.ui.text.font.FontWeight.SemiBold else androidx.compose.ui.text.font.FontWeight.Normal)}}
                }
            }
        }
    }
}
fun screenTitle(d:Destination)=when(d.screen){"outfit"->"The outfit edit";"locations"->"Your places";"day"->"The day ahead";"pro"->"The Pro Studio";"week"->"Dress the week";"wardrobe"->"Your wardrobe";"garment"->"A wardrobe piece";"capsules"->"Travel capsules";"newCapsule"->"A lighter suitcase";"newTrip"->"A new adventure";"trip"->"Packing list";"capsule"->"Your capsule";"library"->"The editorial library";"editorial"->"The visual edit";"privacy"->"Privacy";"credits"->"Weather & credits";"widgets"->"Widgets";else->"The style edit"}
fun shareText(c:android.content.Context,text:String){c.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{type="text/plain";putExtra(Intent.EXTRA_TEXT,text)},"Share checklist"))}
