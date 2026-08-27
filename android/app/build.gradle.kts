import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

// Environment variables are used by GitHub Actions. key.properties remains
// supported for local release builds, as documented by Flutter.
val releaseStoreFile =
    System.getenv("ANDROID_KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFile")
val releaseStorePassword =
    System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
val releaseKeyAlias =
    System.getenv("ANDROID_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword =
    System.getenv("ANDROID_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")

val releaseSigningValues =
    mapOf(
        "keystore path" to releaseStoreFile,
        "keystore password" to releaseStorePassword,
        "key alias" to releaseKeyAlias,
        "key password" to releaseKeyPassword,
    )
val hasAnyReleaseSigningValue = releaseSigningValues.values.any { !it.isNullOrBlank() }
val hasAllReleaseSigningValues = releaseSigningValues.values.all { !it.isNullOrBlank() }
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    val task = taskName.substringAfterLast(':')
    task.equals("assembleRelease", ignoreCase = true) ||
        task.equals("bundleRelease", ignoreCase = true) ||
        task.equals("packageRelease", ignoreCase = true)
}

check(!hasAnyReleaseSigningValue || hasAllReleaseSigningValues) {
    val missingValues = releaseSigningValues.filterValues { it.isNullOrBlank() }.keys.joinToString()
    "Incomplete Android release signing configuration. Missing: $missingValues"
}

check(!releaseTaskRequested || hasAllReleaseSigningValues) {
    "A signed Android release was requested, but no complete release keystore " +
        "configuration was found. Configure android/key.properties or the four " +
        "ANDROID_KEYSTORE_* environment variables; unsigned APKs must not be distributed."
}

android {
    namespace = "com.orbitforge.orbit_breaker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.orbitforge.orbit_breaker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasAllReleaseSigningValues) {
            create("release") {
                storeFile = file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            // A release without signing values stays unsigned instead of silently
            // using the debug key. CI always supplies the four required values.
            signingConfig = signingConfigs.findByName("release")
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
