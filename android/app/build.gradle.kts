import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Internal builds retain the installed app's identity and signing certificate.
val distribution = providers.gradleProperty("distribution").orElse("internal").get()
require(distribution in setOf("internal", "store")) { "distribution must be internal or store" }
val storeDistribution = distribution == "store"
val storeApplicationId = providers.gradleProperty("storeApplicationId").orNull
val releaseKeys = Properties()
if (storeDistribution) {
    require(storeApplicationId != null &&
        Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+").matches(storeApplicationId) &&
        !storeApplicationId.startsWith("com.example.")) {
        "Store builds require an explicit non-example storeApplicationId"
    }
    val keyFile = rootProject.file("key.properties")
    require(keyFile.isFile) { "Store builds require a local android/key.properties" }
    keyFile.inputStream().use { releaseKeys.load(it) }
    require(listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !releaseKeys.getProperty(it).isNullOrBlank() && releaseKeys.getProperty(it) != "SET_LOCALLY"
    }) { "Complete the local release signing configuration before building for a store" }
    require(rootProject.file(releaseKeys.getProperty("storeFile")).isFile) {
        "The configured release keystore is unavailable"
    }
}

android {
    namespace = "com.example.litchi_journal_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (storeDistribution) storeApplicationId!! else "com.example.litchi_journal_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (storeDistribution) {
            create("storeRelease") {
                storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (storeDistribution) "storeRelease" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
