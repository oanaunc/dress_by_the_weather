package com.oanarinaldi.dressbytheweather

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.*
import com.android.billingclient.api.*
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

/** Pure verifier, also exercised against generated RSA signatures in unit tests. */
object PurchaseVerification {
    fun verify(key:String,payload:String,signature:String):Boolean=runCatching {
        if(key.isBlank()||payload.isBlank()||signature.isBlank()) return false
        val publicKey=KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.getDecoder().decode(key)))
        Signature.getInstance("SHA1withRSA").run{initVerify(publicKey);update(payload.toByteArray(Charsets.UTF_8));verify(Base64.getDecoder().decode(signature))}
    }.getOrDefault(false)
}
class ProBilling(private val context:Context):PurchasesUpdatedListener {
    companion object {const val PRODUCT="dress_pro_lifetime"}
    private val handler=Handler(Looper.getMainLooper())
    private val privatePrefs=context.getSharedPreferences("verified_pro",Context.MODE_PRIVATE)
    private val publicKey=runCatching{context.assets.open("play-billing-public-key.txt").bufferedReader().use{it.readText().trim()}}.getOrDefault("")
    var entitled by mutableStateOf(false);private set
    var demo by mutableStateOf(false);private set
    val hasPro get()=entitled || (BuildConfig.DEBUG && demo)
    var product by mutableStateOf<ProductDetails?>(null);private set
    var purchasing by mutableStateOf(false);private set
    var loading by mutableStateOf(true);private set
    var message by mutableStateOf<String?>(null);private set
    val price get()=product?.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice
    private val client=BillingClient.newBuilder(context).setListener(this).enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()).enableAutoServiceReconnection().build()
    init {
        val payload=privatePrefs.getString("payload",null);val signature=privatePrefs.getString("signature",null)
        if(payload!=null && signature!=null) runCatching {val p=Purchase(payload,signature);entitled=isVerified(p)}
        connect()
    }
    fun preview(enabled:Boolean) {if(BuildConfig.DEBUG) demo=enabled}
    private fun isVerified(p:Purchase):Boolean = p.purchaseState==Purchase.PurchaseState.PURCHASED && PRODUCT in p.products && p.packageName==BuildConfig.APPLICATION_ID && PurchaseVerification.verify(publicKey,p.originalJson,p.signature)
    fun connect() {
        if(client.isReady){loadProduct();refresh();return}
        client.startConnection(object:BillingClientStateListener {
            override fun onBillingSetupFinished(result:BillingResult){handler.post{if(result.responseCode==BillingClient.BillingResponseCode.OK){loadProduct();refresh()}else{loading=false;message="Google Play is unavailable. You can continue using free weather and daily advice."}}}
            override fun onBillingServiceDisconnected(){handler.post{loading=false}}
        })
    }
    fun loadProduct() {
        if(!client.isReady){loading=false;return}
        loading=true
        val query=QueryProductDetailsParams.newBuilder().setProductList(listOf(QueryProductDetailsParams.Product.newBuilder().setProductId(PRODUCT).setProductType(BillingClient.ProductType.INAPP).build())).build()
        client.queryProductDetailsAsync(query){result,details->handler.post {
            product=details.productDetailsList.firstOrNull{it.productId==PRODUCT};loading=false
            if(result.responseCode!=BillingClient.BillingResponseCode.OK || product==null) message="The Google Play price couldn’t be loaded. Check Google Play and try again."
        }}
    }
    fun refresh(restore:Boolean=false) {
        if(!client.isReady){if(restore){message="Connect to Google Play to restore your purchase.";connect()};return}
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()){result,purchases->handler.post {
            if(result.responseCode==BillingClient.BillingResponseCode.OK) {
                val owned=purchases.firstOrNull{isVerified(it)}
                entitled=owned!=null
                if(owned==null) privatePrefs.edit().clear().apply() else grantAndAcknowledge(owned)
                if(restore) message=if(entitled) "Your Pro purchase is restored." else "No Pro purchase was found for this Google Account."
            } else if(restore) message="Your purchase couldn’t be restored. Please try again."
        }}
    }
    fun purchase(activity:Activity) {
        if(purchasing)return
        val p=product?:run{loadProduct();return}
        val offer=p.oneTimePurchaseOfferDetailsList?.firstOrNull()?:run{message="The price is unavailable. Reload it before purchasing.";return}
        if(publicKey.isBlank()){message="Purchase verification is not configured. Free features remain available.";return}
        purchasing=true;message=null
        val entry=BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(p).apply { offer.offerToken?.let { setOfferToken(it) } }.build()
        val result=client.launchBillingFlow(activity,BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(entry)).build())
        if(result.responseCode!=BillingClient.BillingResponseCode.OK){purchasing=false;if(result.responseCode==BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED)refresh(true) else if(result.responseCode!=BillingClient.BillingResponseCode.USER_CANCELED)message="Google Play couldn’t start the purchase. Please try again."}
    }
    override fun onPurchasesUpdated(result:BillingResult,purchases:MutableList<Purchase>?) {handler.post {
        purchasing=false
        if(result.responseCode==BillingClient.BillingResponseCode.OK) for(p in purchases.orEmpty()) {
            if(p.purchaseState==Purchase.PurchaseState.PENDING){message="Your purchase is pending approval. Pro unlocks after Google Play confirms it.";continue}
            if(isVerified(p)) grantAndAcknowledge(p) else message="This purchase couldn’t be verified. Please restore your purchase or contact support."
        } else if(result.responseCode!=BillingClient.BillingResponseCode.USER_CANCELED) message="The purchase wasn’t completed. Please try again."
    }}
    private fun grantAndAcknowledge(p:Purchase) {
        if(!isVerified(p))return
        entitled=true;privatePrefs.edit().putString("payload",p.originalJson).putString("signature",p.signature).apply()
        if(!p.isAcknowledged) client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()){r->if(r.responseCode!=BillingClient.BillingResponseCode.OK)handler.post{message="Google Play is still confirming your purchase. Reopen the app to retry."}}
    }
    fun close(){client.endConnection()}
}
