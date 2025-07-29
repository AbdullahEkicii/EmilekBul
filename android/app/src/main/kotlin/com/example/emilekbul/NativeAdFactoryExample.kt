package com.abdullahekici.emilekbul
import com.abdullahekici.emilekbul.R
import android.content.Context
import android.view.LayoutInflater
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.formats.NativeAdOptions
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryExample(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = LayoutInflater.from(context).inflate(R.layout.native_ad, null) as NativeAdView

        adView.headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        adView.bodyView = adView.findViewById<TextView>(R.id.ad_body)
        adView.callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)

        (adView.headlineView as TextView).text = nativeAd.headline
        nativeAd.body?.let {
            adView.bodyView?.visibility = TextView.VISIBLE
            (adView.bodyView as TextView).text = it
        }

        nativeAd.callToAction?.let {
            adView.callToActionView?.visibility = Button.VISIBLE
            (adView.callToActionView as Button).text = it
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
