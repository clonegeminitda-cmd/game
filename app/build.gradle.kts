plugins { id("com.android.application"); kotlin("android") }
android {
    namespace = "vn.apktachgoc"
    compileSdk = 35
    defaultConfig { applicationId = "vn.apktachgoc"; minSdk = 26; targetSdk = 35; versionCode = 3; versionName = "0.2.0"; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_1_8; targetCompatibility = JavaVersion.VERSION_1_8; isCoreLibraryDesugaringEnabled = true }
    kotlinOptions { jvmTarget = "1.8" }
    packaging { resources.excludes += setOf("META-INF/versions/**", "META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA", "META-INF/DEPENDENCIES", "META-INF/LICENSE*", "META-INF/NOTICE*") }
    sourceSets.getByName("androidTest").assets.srcDir(layout.buildDirectory.dir("generated/test-assets"))
}
dependencies {
    implementation(project(":core"))
    implementation("androidx.core:core-ktx:1.15.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
val sampleTestAssets by tasks.registering(Copy::class) {
    dependsOn(":sample:assembleDebug", ":native-sample:assembleDebug")
    from(project(":sample").layout.buildDirectory.file("outputs/apk/debug/sample-debug.apk"))
    from(project(":native-sample").layout.buildDirectory.file("outputs/apk/debug/native-sample-debug.apk"))
    into(layout.buildDirectory.dir("generated/test-assets"))
}
tasks.configureEach { if (name == "mergeDebugAndroidTestAssets" || name == "generateDebugAndroidTestLintModel" || name == "lintAnalyzeDebugAndroidTest") dependsOn(sampleTestAssets) }
