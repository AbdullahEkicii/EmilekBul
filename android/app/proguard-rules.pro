# Flutter ve Kotlin standard kütüphaneleri için
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }
-keep class kotlin.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**


# Firebase Authentication, Firestore, Storage, Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.** { *; }

# Gson or Json parsing (if kullanıyorsan)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class com.google.gson.annotations.** { *; }

# Firebase Cloud Firestore model sınıfları için (eğer model kullanıyorsan)
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <fields>;
  @com.google.firebase.firestore.PropertyName <methods>;
}

# Keep native libraries (so dosyaları) strip sonrası çalışması için
-keep class *Native* { *; }

# Genel uyarılar ve uyarıları bastırmak için (isteğe bağlı)
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn kotlin.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Önemli: Proguard minify sırasında reflection kullanan Firebase ve Google API’leri için gerekli
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
