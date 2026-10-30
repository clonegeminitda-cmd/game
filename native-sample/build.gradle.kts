plugins { id("com.android.application"); kotlin("android") }
android {
    namespace = "vn.apktachgoc.nativesample"; compileSdk = 35
    defaultConfig { applicationId = "vn.apktachgoc.nativesample"; minSdk = 26; targetSdk = 35; versionCode = 1; versionName = "1.0-native" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_1_8; targetCompatibility = JavaVersion.VERSION_1_8 }
    kotlinOptions { jvmTarget = "1.8" }
    packaging { jniLibs.useLegacyPackaging = false }
}
