import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yükleme anahtarı `android/key.properties` üzerinden geliyor; dosya da
// keystore'un kendisi de `.gitignore`'da. Depoda yoksa (taze klon, CI)
// `release` derlemesi debug anahtarına düşüyor: `flutter run --release`
// çalışmaya devam etsin diye. Mağazaya çıkan paketin gerçekten yükleme
// anahtarıyla imzalandığını `hasUploadKey` üzerinden görüyoruz.
//
// YAN YÜKLEME. `VOIDSPACE_YAN_YUKLEME=1` verildiğinde yükleme anahtarı
// dosyada dursa bile YOK SAYILIYOR ve paket debug anahtarıyla imzalanıyor.
// Bu bir kaçış kapısı değil, ayrı bir hedef: bir arkadaşa elden kurulacak
// APK'nın mağaza kimliğiyle imzalanmasına gerek yok, üstelik anahtar
// parolası bozuksa derleme buna takılıp hiç paket üretmiyor. Mağaza paketi
// bu değişkeni HİÇ görmüyor.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val yanYukleme = System.getenv("VOIDSPACE_YAN_YUKLEME") == "1"
val hasUploadKey = keystorePropertiesFile.exists() && !yanYukleme
if (hasUploadKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.voidspace.voidspace3"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.voidspace.voidspace3"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
