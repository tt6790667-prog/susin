import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.susingroup.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.susingroup.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
            }

            val keystoreFile = rootProject.file("susin-release.jks")
            if (keystoreFile.exists() && keystorePropertiesFile.exists()) {
                signingConfigs.create("release") {
                    storeFile = keystoreFile
                    storePassword = keystoreProperties.getProperty("storePassword") ?: ""
                    keyAlias = keystoreProperties.getProperty("keyAlias") ?: "susin"
                    keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                }
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        // Removed keepDebugSymbols to prevent native crashes
    }
}

flutter {
    source = "../.."
}

// Removed strip hack
