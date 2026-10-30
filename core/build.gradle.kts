plugins { kotlin("jvm") }
kotlin { jvmToolchain(21); compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8) } }
java { sourceCompatibility = JavaVersion.VERSION_1_8; targetCompatibility = JavaVersion.VERSION_1_8 }
dependencies {
    api("io.github.reandroid:ARSCLib:1.4.0")
    api("org.smali:dexlib2:2.5.2")
    api("com.android.tools.build:apksig:8.9.1")
    api("org.bouncycastle:bcpkix-jdk15to18:1.78.1")
    testImplementation(kotlin("test-junit"))
}
tasks.test {
    dependsOn(":sample:assembleDebug", ":native-sample:assembleDebug")
    systemProperty("sampleApk", rootProject.file("sample/build/outputs/apk/debug/sample-debug.apk"))
    systemProperty("nativeApk", rootProject.file("native-sample/build/outputs/apk/debug/native-sample-debug.apk"))
}
