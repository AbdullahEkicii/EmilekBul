package com.abdullahekici.emilekbul

import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactorySmall(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_layout_small, null) as NativeAdView

        // Icon
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        adView.iconView = iconView
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.visibility = android.view.View.VISIBLE
        } else {
            iconView.visibility = android.view.View.GONE
        }

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        adView.headlineView = headlineView
        headlineView.text = nativeAd.headline

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        adView.bodyView = bodyView
        if (nativeAd.body != null) {
            bodyView.text = nativeAd.body
            bodyView.visibility = android.view.View.VISIBLE
        } else {
            bodyView.visibility = android.view.View.INVISIBLE
        }

        // Advertiser
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        adView.advertiserView = advertiserView
        if (nativeAd.advertiser != null) {
            advertiserView.text = nativeAd.advertiser
            advertiserView.visibility = android.view.View.VISIBLE
        } else {
            advertiserView.visibility = android.view.View.GONE
        }

        // Call To Action
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        adView.callToActionView = ctaView
        if (nativeAd.callToAction != null) {
            ctaView.text = nativeAd.callToAction
            ctaView.visibility = android.view.View.VISIBLE
        } else {
            ctaView.visibility = android.view.View.INVISIBLE
        }

        // Connect the NativeAd to the View
        adView.setNativeAd(nativeAd)

        return adView
    }
}
