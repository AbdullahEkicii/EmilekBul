# -----------------------------------------------------------------------------
# Flutter & Kotlin Base Rules
# -----------------------------------------------------------------------------
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }

# R8 Code Optimization & Obfuscation
-optimizationpasses 5
-allowaccessmodification
-dontusemixedcaseclassnames
-repackageclasses ''
-overloadaggressively

# Keep attributes needed for Reflection & Debugging
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# -----------------------------------------------------------------------------
# Firebase & Google Play Services
# -----------------------------------------------------------------------------
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

-keep class com.google.android.gms.common.annotation.KeepName { *; }
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# Google Sign-In & Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }

# Firebase Auth internal
-dontwarn com.google.android.gms.internal.firebase-auth-api.**

# Play Integrity
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Native libs (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Suppress harmless warnings from dependencies
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn kotlin.**
