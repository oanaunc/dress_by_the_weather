package com.oanarinaldi.dressbytheweather

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.layer.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*
import coil.compose.AsyncImage
import kotlin.math.*

val Paper=Color(.97f,.96f,.93f)
val Ink=Color(.16f,.20f,.19f)
val Muted=Color(.43f,.45f,.41f)
val Olive=Color(.42f,.47f,.36f)
val Sand=Color(.89f,.86f,.78f)
val EditorialFont=FontFamily(Font(R.font.editorial))
val InterfaceFont=FontFamily(Font(R.font.interface_text))
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
val TemperatureFont=FontFamily(Font(R.font.editorial,weight=FontWeight.Light,variationSettings=FontVariation.Settings(FontVariation.weight(200),FontVariation.opticalSizing(100.sp))))
@Composable fun DressTheme(content:@Composable ()->Unit) {
    MaterialTheme(colorScheme=lightColorScheme(primary=Ink,onPrimary=Color.White,secondary=Olive,background=Paper,surface=Paper,onSurface=Ink,onBackground=Ink,surfaceVariant=Sand,outline=Muted.copy(alpha=.3f)),typography=Typography(
        bodyLarge=androidx.compose.ui.text.TextStyle(fontFamily=InterfaceFont,fontSize=17.sp,lineHeight=24.sp,color=Ink),
        bodyMedium=androidx.compose.ui.text.TextStyle(fontFamily=InterfaceFont,fontSize=15.sp,lineHeight=22.sp,color=Ink),
        bodySmall=androidx.compose.ui.text.TextStyle(fontFamily=InterfaceFont,fontSize=12.sp,lineHeight=17.sp,color=Muted),
        labelLarge=androidx.compose.ui.text.TextStyle(fontFamily=InterfaceFont,fontSize=15.sp,color=Ink),
        titleLarge=androidx.compose.ui.text.TextStyle(fontFamily=EditorialFont,fontSize=28.sp,color=Ink)
    ),content=content)
}
@Composable fun EditorialText(text:String,size:Int=28,modifier:Modifier=Modifier,color:Color=Ink) {Text(text,modifier,fontFamily=EditorialFont,fontSize=size.sp,lineHeight=(size*1.16).sp,color=color)}
@Composable fun Eyebrow(text:String,modifier:Modifier=Modifier) {Text(text.uppercase(),modifier,fontFamily=FontFamily.Monospace,fontSize=10.sp,lineHeight=15.sp,letterSpacing=2.sp,fontWeight=FontWeight.SemiBold,color=Muted)}
@Composable fun Heading(eyebrow:String,title:String){Column(verticalArrangement=Arrangement.spacedBy(10.dp)){Eyebrow(eyebrow);EditorialText(title,40)}}
@Composable fun Body(text:String,modifier:Modifier=Modifier){Text(text,modifier,color=Muted,style=MaterialTheme.typography.bodyMedium)}
@Composable fun Caption(text:String,modifier:Modifier=Modifier,color:Color=Muted){Text(text,modifier,color=color,style=MaterialTheme.typography.bodySmall)}
@Composable fun GlassCard(modifier:Modifier=Modifier,content:@Composable ColumnScope.()->Unit) {
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(Brush.linearGradient(listOf(Color.White.copy(alpha=.64f),Color.White.copy(alpha=.3f),Sand.copy(alpha=.24f)))).border(1.dp,Color.White.copy(alpha=.86f),RoundedCornerShape(26.dp)).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp),content=content)
}
@Composable fun EditorialPhoto(name:String?,height:Dp=240.dp,full:Boolean=false,modifier:Modifier=Modifier,description:String="Editorial couple outfit inspiration") {
    val model=name?.let{"file:///android_asset/art/$it.jpg"}
    if(full) AsyncImage(model,description,modifier.fillMaxWidth().aspectRatio(3f/4f).clip(RoundedCornerShape(28.dp)),contentScale=ContentScale.Fit)
    else BoxWithConstraints(modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(28.dp))) {
        val photoHeight=maxOf(height,maxWidth*4/3)
        if(name!=null) AsyncImage(model,description,Modifier.wrapContentSize(Alignment.TopStart,unbounded=true).requiredSize(maxWidth,photoHeight).offset(y=-(photoHeight-height)*.15f).align(Alignment.TopStart),contentScale=ContentScale.Crop,alignment=Alignment.TopCenter)
        else Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(Sand,Color.White,Olive.copy(alpha=.2f)))),contentAlignment=Alignment.Center){Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(18.dp)){Icon(Icons.Outlined.Checkroom,null,Modifier.size(64.dp),tint=Muted);EditorialText("Your daily layers",27)}}
    }
}
@Composable fun OutfitPhoto(m:DressModel,o:Outfit,height:Dp=240.dp,variant:Int?=null,full:Boolean=false,modifier:Modifier=Modifier) {EditorialPhoto(if(variant==null)m.artwork(o) else m.artwork(o,variant),height,full,modifier,description="${o.style.label} couple outfit · ${o.range}")}
@Composable fun Action(text:String,modifier:Modifier=Modifier,enabled:Boolean=true,primary:Boolean=false,icon:ImageVector?=null,onClick:()->Unit) {
    val shape=RoundedCornerShape(100.dp)
    Row(modifier.defaultMinSize(minHeight=44.dp).clip(shape).background(if(primary) Ink else Color.White.copy(alpha=.35f)).border(1.dp,if(primary) Color.Transparent else Color.White.copy(alpha=.9f),shape).clickable(enabled=enabled,role=Role.Button,onClick=onClick).padding(horizontal=16.dp,vertical=12.dp).alpha(if(enabled)1f else .5f),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.Center) {
        if(icon!=null){Icon(icon,null,Modifier.size(18.dp),tint=if(primary)Color.White else Ink);Spacer(Modifier.width(8.dp))}
        Text(text,color=if(primary)Color.White else Ink,style=MaterialTheme.typography.labelLarge,textAlign=TextAlign.Center)
    }
}
@Composable fun CircleAction(icon:ImageVector,label:String,modifier:Modifier=Modifier,onClick:()->Unit) {Box(modifier.size(48.dp).shadow(6.dp,CircleShape).clip(CircleShape).background(Color.White.copy(alpha=.7f),CircleShape).border(1.dp,Color.White,CircleShape).clickable(role=Role.Button,onClick=onClick),contentAlignment=Alignment.Center){Icon(icon,label,tint=Ink,modifier=Modifier.size(23.dp))}}
@Composable fun Segmented(options:List<String>,selected:String,onSelect:(String)->Unit,modifier:Modifier=Modifier) {Row(modifier.fillMaxWidth().clip(CircleShape).background(Muted.copy(alpha=.1f)).padding(3.dp)) {options.forEach{option->Box(Modifier.weight(1f).clip(CircleShape).background(if(option==selected)Color.White else Color.Transparent).clickable(role=Role.Tab){onSelect(option)}.padding(horizontal=4.dp,vertical=8.dp).semantics{this.selected=option==selected},contentAlignment=Alignment.Center){Text(option,fontFamily=InterfaceFont,fontSize=12.sp,fontWeight=if(option==selected)FontWeight.SemiBold else FontWeight.Normal,maxLines=1,color=Ink)}}}}
@Composable fun OccasionPicker(selected:Occasion,onSelect:(Occasion)->Unit){Segmented(Occasion.entries.map{it.label},selected.label,{onSelect(Occasion.valueOf(it))})}
@Composable fun Page(modifier:Modifier=Modifier,maxWidth:Dp=700.dp,content:@Composable ColumnScope.()->Unit) {
    val scroll=rememberScrollState()
    Box(modifier.fillMaxSize().background(Paper),contentAlignment=Alignment.TopCenter){Column(Modifier.fillMaxHeight().widthIn(max=maxWidth).fillMaxWidth().verticalScroll(scroll).padding(horizontal=24.dp).padding(top=22.dp,bottom=120.dp),verticalArrangement=Arrangement.spacedBy(24.dp),content=content)}
}
@Composable fun SectionLabel(title:String){Text(title,fontWeight=FontWeight.SemiBold,fontSize=16.sp,color=Ink)}
@Composable fun FormCard(content:@Composable ColumnScope.()->Unit){Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White).padding(18.dp),verticalArrangement=Arrangement.spacedBy(14.dp),content=content)}
@Composable fun DividerLine(){HorizontalDivider(color=Muted.copy(alpha=.16f))}
@Composable fun FormRow(label:String,detail:String?=null,icon:ImageVector?=null,onClick:()->Unit) {Row(Modifier.fillMaxWidth().clickable(role=Role.Button,onClick=onClick).padding(vertical=10.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)){if(icon!=null)Icon(icon,null,tint=Ink);Column(Modifier.weight(1f)){Text(label,color=Ink);if(detail!=null)Caption(detail)};Icon(Icons.Outlined.ChevronRight,null,Modifier.size(17.dp),tint=Muted)}}
@Composable fun SwitchRow(label:String,checked:Boolean,onChange:(Boolean)->Unit){Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text(label,Modifier.weight(1f),color=Ink);Switch(checked,onChange,colors=SwitchDefaults.colors(checkedTrackColor=Ink,checkedThumbColor=Color.White))}}
@Composable fun Choice(label:String,options:List<String>,selected:String,onSelect:(String)->Unit){var open by remember{mutableStateOf(false)};Box{FormRow(label,selected){open=true};DropdownMenu(open,{open=false}){options.forEach{value->DropdownMenuItem(text={Text(value)},onClick={onSelect(value);open=false})}}}}
@Composable fun WeatherIcon(w:Conditions,size:Dp=32.dp) {
    Canvas(Modifier.size(size).semantics{contentDescription=w.label}) {
        val unit=this.size.width/40;fun px(v:Float)=v*unit
        val sun=Color(0xFFFFC600);val cloud=Color(0xFFD3DDE6)
        if(!w.rain&&!w.snow&&!w.storm&&!w.symbol.contains("cloudy")){val night=w.symbol.contains("night");drawCircle(if(night)Color(0xFF9BAFC6) else sun,px(9f),Offset(px(26f),px(13f)));if(!night)for(i in 0..7){val a=i*PI/4;drawLine(sun,Offset(px(26f+cos(a).toFloat()*13),px(13f+sin(a).toFloat()*13)),Offset(px(26f+cos(a).toFloat()*16),px(13f+sin(a).toFloat()*16)),px(2f),StrokeCap.Round)}}
        if(w.rain||w.snow||w.storm||w.symbol.contains("cloud")||w.symbol.contains("fair")||w.symbol.contains("fog")) {drawCircle(cloud,px(8f),Offset(px(12f),px(22f)));drawCircle(cloud,px(10f),Offset(px(21f),px(18f)));drawCircle(cloud,px(7f),Offset(px(29f),px(23f)));drawRoundRect(cloud,Offset(px(8f),px(21f)),Size(px(24f),px(9f)),CornerRadius(px(4f)))}
        if(w.rain||w.snow)for(i in 0..2){val x=11f+i*9;if(w.snow)drawCircle(Color(0xFF94B5CC),px(1.6f),Offset(px(x),px(35f))) else drawLine(Color(0xFF589CDD),Offset(px(x+2),px(32f)),Offset(px(x),px(37f)),px(1.6f),StrokeCap.Round)}
        if(w.storm){val path=Path().apply{moveTo(px(22f),px(26f));lineTo(px(17f),px(33f));lineTo(px(23f),px(33f));lineTo(px(19f),px(39f))};drawPath(path,sun,style=Stroke(px(2f)))}
    }
}
@Composable fun Attribution(){val uri=LocalUriHandler.current;Column(Modifier.fillMaxWidth().padding(vertical=18.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(7.dp)){Text("Weather data: MET Norway",Modifier.clickable{uri.openUri("https://www.met.no/en")},style=MaterialTheme.typography.bodySmall,color=Muted);Text("CC BY 4.0 · Daily ranges & clothing advice by this app",Modifier.clickable{uri.openUri("https://creativecommons.org/licenses/by/4.0/")},fontSize=10.sp,color=Muted,textAlign=TextAlign.Center)}}

/** Original simple navigation marks matching the iOS visual vocabulary. */
@Composable fun NavigationMark(name:String,modifier:Modifier=Modifier) {
    Canvas(modifier.size(28.dp).semantics{contentDescription=name}) {
        val scale=size.width/24f
        scale(scale,scale,Offset.Zero) {
            val stroke=Stroke(1.7f,cap=StrokeCap.Round,join=StrokeJoin.Round)
            when(name) {
                "Today"->{drawCircle(Ink,4f,Offset(12f,12f));for(i in 0..7){val a=i*kotlin.math.PI/4;drawLine(Ink,Offset(12+cos(a).toFloat()*8,12+sin(a).toFloat()*8),Offset(12+cos(a).toFloat()*10,12+sin(a).toFloat()*10),1.8f,StrokeCap.Round)}}
                "Looks"->{val p=Path().apply{moveTo(8f,3f);lineTo(10f,4.5f);lineTo(14f,4.5f);lineTo(16f,3f);lineTo(22f,6.5f);lineTo(19f,11.5f);lineTo(17f,10.5f);lineTo(17f,22f);lineTo(7f,22f);lineTo(7f,10.5f);lineTo(5f,11.5f);lineTo(2f,6.5f);close()};drawPath(p,Ink)}
                "Forecast"->{drawLine(Ink,Offset(3f,2f),Offset(3f,21f),1.7f,StrokeCap.Round);drawLine(Ink,Offset(3f,21f),Offset(22f,21f),1.7f,StrokeCap.Round);val p=Path().apply{moveTo(4f,15f);lineTo(10f,9f);lineTo(15f,13f);lineTo(21f,6f)};drawPath(p,Ink,style=stroke);listOf(Offset(4f,15f),Offset(10f,9f),Offset(15f,13f),Offset(21f,6f)).forEach{drawCircle(Ink,1.7f,it)}}
                "Planner"->{drawRoundRect(Ink,Offset(5f,7f),Size(14f,14f),CornerRadius(2f),style=stroke);drawRoundRect(Ink,Offset(9f,2f),Size(6f,5f),CornerRadius(1.5f),style=stroke);drawLine(Ink,Offset(5f,18f),Offset(19f,18f),1.2f);drawCircle(Ink,1.3f,Offset(8f,23f));drawCircle(Ink,1.3f,Offset(17f,23f))}
                else->{listOf(5f to 9f,12f to 16f,19f to 7f).forEach{(y,x)->drawLine(Ink,Offset(2f,y),Offset(22f,y),1.5f,StrokeCap.Round);drawCircle(Paper,2.5f,Offset(x,y));drawCircle(Ink,2.5f,Offset(x,y),style=Stroke(1.5f))}}
            }
        }
    }
}
