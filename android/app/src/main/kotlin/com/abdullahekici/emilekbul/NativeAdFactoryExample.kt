package com.abdullahekici.emilekbul

import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import android.widget.Button
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdFactoryExample(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_layout, null) as NativeAdView

        // Başlık
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        (adView.headlineView as? TextView)?.text = nativeAd.headline

        // Body
        adView.bodyView = adView.findViewById(R.id.ad_body)
        (adView.bodyView as? TextView)?.text = nativeAd.body

        // İkon
        adView.iconView = adView.findViewById(R.id.ad_icon)
        nativeAd.icon?.let {
            (adView.iconView as? ImageView)?.setImageDrawable(it.drawable)
            adView.iconView?.visibility = View.VISIBLE
        } ?: run { adView.iconView?.visibility = View.GONE }

        // Call to action
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        (adView.callToActionView as? Button)?.text = nativeAd.callToAction

        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)
        (adView.advertiserView as? TextView)?.text = nativeAd.advertiser ?: ""

        // MediaView
        adView.mediaView = adView.findViewById(R.id.ad_media)

        adView.setNativeAd(nativeAd)
        return adView
    }
}
