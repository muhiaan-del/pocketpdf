import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties for release signing.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.pocketpdf.pocketpdf"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pocketpdf.pocketpdf"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storePasswordValue =
                    keystoreProperties.getProperty("storePassword")
                val keyPasswordValue =
                    keystoreProperties.getProperty("keyPassword")
                val keyAliasValue = keystoreProperties.getProperty("keyAlias")
                val storeFileValue = keystoreProperties.getProperty("storeFile")

                if (storePasswordValue == null ||
                    keyPasswordValue == null ||
                    keyAliasValue == null ||
                    storeFileValue == null
                ) {
                    throw GradleException(
                        "Missing required keys in key.properties. " +
                        "Found: ${keystoreProperties.keys}. " +
                        "Required: storePassword, keyPassword, keyAlias, storeFile."
                    )
                }

                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeFile = file(storeFileValue)
                storePassword = storePasswordValue
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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