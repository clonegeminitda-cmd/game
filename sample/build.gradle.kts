plugins { id("com.android.application"); kotlin("android") }
android {
    namespace = "vn.apktachgoc.sample"; compileSdk = 35
    defaultConfig { applicationId = "vn.apktachgoc.sample"; minSdk = 26; targetSdk = 35; versionCode = 1; versionName = "1.0" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_1_8; targetCompatibility = JavaVersion.VERSION_1_8 }
    kotlinOptions { jvmTarget = "1.8" }
    buildFeatures { buildConfig = true }
}
