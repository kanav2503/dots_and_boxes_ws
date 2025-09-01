// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")    // FlutterFire Google Services
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
}

android {
    namespace   = "com.example.dots_and_boxes"   // must match your applicationId
    compileSdk  = 34

    ndkVersion  = "27.0.12077973"                // match Firebase’s NDK requirement

    defaultConfig {
        applicationId = "com.example.dots_and_boxes"
        minSdk        = 23                       // bump from 21 to 23
        targetSdk     = 34
        versionCode   = 1
        versionName   = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled   = false
            isShrinkResources = false           // disable resource shrinking
        }
        getByName("release") {
            isMinifyEnabled   = false
            isShrinkResources = false           // disable resource shrinking
            signingConfig     = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
