#include <jni.h>

/* No libc or other external symbols are required. This is a real JNI library. */
JNIEXPORT jint JNICALL Java_vn_apktachgoc_nativesample_MainActivity_nativeValue(
        JNIEnv *env, jobject activity) {
    (void)env;
    (void)activity;
    return 73;
}
