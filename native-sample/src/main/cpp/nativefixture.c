#include <jni.h>

/* No libc or other external symbols are required. This is a real JNI library. */
JNIEXPORT jint JNICALL Java_vn_apktachgoc_nativesample_MainActivity_nativeValue(
        JNIEnv *env, jobject activity) {
    (void)activity;
    /* Class/JNI namespaces must remain unchanged when Android package changes. */
    jclass original_class = (*env)->FindClass(env, "vn/apktachgoc/nativesample/MainActivity");
    if (original_class == NULL) return -1;
    (*env)->DeleteLocalRef(env, original_class);
    return 73;
}
