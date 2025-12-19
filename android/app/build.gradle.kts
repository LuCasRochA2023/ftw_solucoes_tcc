plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun getSigningProperty(key: String): String? {
    val fromFile = keystoreProperties[key] as String?
    if (!fromFile.isNullOrBlank()) return fromFile
    val fromEnv = System.getenv(key.uppercase())
    return if (fromEnv.isNullOrBlank()) null else fromEnv
}

val releaseKeyAlias = getSigningProperty("keyAlias")
val releaseKeyPassword = getSigningProperty("keyPassword")
val releaseStorePassword = getSigningProperty("storePassword")
val releaseStoreFilePath = getSigningProperty("storeFile")
val releaseStoreFile = releaseStoreFilePath?.let { rootProject.file(it) }
val isReleaseSigningConfigured = listOf(
    releaseKeyAlias,
    releaseKeyPassword,
    releaseStorePassword,
    releaseStoreFilePath
).all { !it.isNullOrBlank() }

android {
    namespace = "com.ftwsolucoes.ftw_solucoes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ftwsolucoes.ftw_solucoes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isReleaseSigningConfigured && releaseStoreFile != null) {
            create("release") {
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword!!
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("⚠️  Release signing config not provided. Using debug signing config for release build.")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
