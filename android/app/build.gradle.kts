plugins {
    id("com.android.application")
    // Plugin Flutter phải đứng sau plugin Android và Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dohonganhduy.btkt_dohonganhduy"
    // permission_handler_android yêu cầu biên dịch với Android API 37 (đã cài android-37.0 trong SDK)
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications cần core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // applicationId mang tên cá nhân (yêu cầu giảng viên)
        applicationId = "com.dohonganhduy.btkt_dohonganhduy"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Bản release tạm ký bằng debug key để cài thử được ngay. Đưa lên Play Store thì cần keystore riêng.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // Phiên bản theo README của flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
