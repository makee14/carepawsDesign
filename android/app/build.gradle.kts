plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.petcare.petcare_artifact"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.petcare.petcare_artifact"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release signing is driven entirely by environment variables so no
        // secrets ever live in the repo. Set CAREPAWS_KEYSTORE to the absolute
        // path of the release keystore plus CAREPAWS_KEY_ALIAS,
        // CAREPAWS_STORE_PASSWORD and CAREPAWS_KEY_PASSWORD before building.
        create("release") {
            val ks = System.getenv("CAREPAWS_KEYSTORE")
            if (!ks.isNullOrBlank()) {
                storeFile = file(ks)
                storePassword = System.getenv("CAREPAWS_STORE_PASSWORD")
                keyAlias = System.getenv("CAREPAWS_KEY_ALIAS")
                keyPassword = System.getenv("CAREPAWS_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Sign with the release keystore when its env vars are present;
            // otherwise fall back to the debug key so `flutter build apk`
            // still runs without secrets (CI builds --debug).
            val ks = System.getenv("CAREPAWS_KEYSTORE")
            signingConfig = if (!ks.isNullOrBlank()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
