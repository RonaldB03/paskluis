plugins {
    id("com.android.application")
    id("kotlin-android")
}
android {
    namespace = "nl.paskluis.watch"
    compileSdk = 36
    defaultConfig {
        applicationId = "nl.paskluis.app"
        minSdk = 30
        targetSdk = 36
        // Different version-code range from phone; same Play signing certificate.
        versionCode = System.getenv("WATCH_VERSION_CODE")?.toInt() ?: 1000143
        versionName = System.getenv("WATCH_VERSION_NAME") ?: "1.9.0-watch-beta1"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets["main"].java.srcDir("../watch-common/src/main/java")
    signingConfigs {
        val path = System.getenv("CM_KEYSTORE_PATH")
        if (!path.isNullOrBlank()) create("release") {
            storeFile = file(path)
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("CM_KEY_ALIAS")
            keyPassword = System.getenv("CM_KEY_PASSWORD")
        }
    }
    buildTypes {
        release { if (signingConfigs.findByName("release") != null) signingConfig = signingConfigs.getByName("release") }
    }
}
dependencies {
    implementation("androidx.core:core-splashscreen:1.2.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
