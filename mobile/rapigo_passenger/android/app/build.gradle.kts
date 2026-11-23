import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// The same flag controls Dart update behavior and the Android release manifest.
val dartDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotBlank() }.map { String(Base64.getDecoder().decode(it)) }
val playStoreBuild = dartDefines.contains("PLAY_STORE=true")
if (gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) } && !playStoreBuild) {
    throw GradleException("Build app bundles with --dart-define=PLAY_STORE=true and a private upload key.")
}
if (playStoreBuild) {
    val values = dartDefines.associate { it.substringBefore("=") to it.substringAfter("=", "") }
    require(values["SERVER_SCHEME"] == "https") { "Play builds require SERVER_SCHEME=https" }
    require(values["ROUTING_SCHEME"] == "https") { "Play builds require ROUTING_SCHEME=https" }
    for (key in listOf("PRIVACY_POLICY_URL", "ACCOUNT_DELETION_URL")) {
        require(values[key]?.startsWith("https://") == true) { "Missing public HTTPS URL: $key" }
    }
}
val uploadProperties = Properties()
val uploadPropertiesFile = rootProject.file("key.properties")
if (uploadPropertiesFile.exists()) uploadPropertiesFile.inputStream().use { uploadProperties.load(it) }
if (playStoreBuild && !uploadPropertiesFile.exists()) {
    throw GradleException("Google Play requires android/key.properties and a private upload key. Debug signing is forbidden.")
}

android {
    namespace = "com.rapigo.passenger"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rapigo.passenger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(36, flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (playStoreBuild) {
        sourceSets.getByName("release").manifest.srcFile("src/play/AndroidManifest.xml")
        sourceSets.getByName("release").res.srcDir("src/play/res")
        signingConfigs.create("upload") {
            keyAlias = uploadProperties.getProperty("keyAlias") ?: error("Missing keyAlias")
            keyPassword = uploadProperties.getProperty("keyPassword") ?: error("Missing keyPassword")
            storeFile = file(uploadProperties.getProperty("storeFile") ?: error("Missing storeFile"))
            storePassword = uploadProperties.getProperty("storePassword") ?: error("Missing storePassword")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName(if (playStoreBuild) "upload" else "debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
