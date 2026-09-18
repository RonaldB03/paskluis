plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val codemagicKeystorePath = System.getenv("CM_KEYSTORE_PATH")
val codemagicKeystorePassword = System.getenv("CM_KEYSTORE_PASSWORD")
val codemagicKeyAlias = System.getenv("CM_KEY_ALIAS")
val codemagicKeyPassword = System.getenv("CM_KEY_PASSWORD")

android {
    namespace = "nl.paskluis.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "nl.paskluis.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!codemagicKeystorePath.isNullOrBlank()) {
            create("release") {
                storeFile = file(codemagicKeystorePath)
                storePassword = codemagicKeystorePassword
                keyAlias = codemagicKeyAlias
                keyPassword = codemagicKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (!codemagicKeystorePath.isNullOrBlank()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
