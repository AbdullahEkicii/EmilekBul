import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.abdullahekici.emilekbul"
    compileSdk = 36
    ndkVersion = "27.0.12077973" 

    defaultConfig {
        applicationId = "com.abdullahekici.emilekbul"
        minSdk = 26
        targetSdk = 36
        versionCode = 48
        versionName = "1.5.20"
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }
    
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release") 
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // DEBUG SEMBOLLERİ İLE İLGİLİ AYARLARI EKLEYİN
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE" // veya "FULL" yerine NONE
            }
        }
    }
    packaging {
        jniLibs {
            excludes += listOf("/**/*.debug")
        }
        resources {
            excludes += listOf("/**/*.debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }   
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.9.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-auth:21.3.0")
    implementation("com.google.android.play:integrity:1.4.0")
}