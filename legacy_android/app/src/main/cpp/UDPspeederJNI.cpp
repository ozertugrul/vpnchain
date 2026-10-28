#include <jni.h>
#include <string>
#include <android/log.h>

#define LOG_TAG "UDPspeederJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

JavaVM* gJvm = nullptr;

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    gJvm = vm;
    return JNI_VERSION_1_6;
}

void protectSocketFromNative(int fd) {
    if (!gJvm) return;
    
    JNIEnv* env;
    int getEnvStat = gJvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    if (getEnvStat == JNI_EDETACHED) {
        if (gJvm->AttachCurrentThread(&env, NULL) != 0) {
            LOGE("Failed to attach thread");
            return;
        }
    }

    jclass clientClass = env->FindClass("com/selcuk9805/vpnchain/native/UDPspeederClient");
    if (clientClass != nullptr) {
        jmethodID protectMethod = env->GetStaticMethodID(clientClass, "onSocketCreated", "(I)V");
        if (protectMethod != nullptr) {
            env->CallStaticVoidMethod(clientClass, protectMethod, fd);
        } else {
            LOGE("Method onSocketCreated not found");
        }
        env->DeleteLocalRef(clientClass);
    } else {
        LOGE("Class UDPspeederClient not found");
    }
    
    if (getEnvStat == JNI_EDETACHED) {
        gJvm->DetachCurrentThread();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_selcuk9805_vpnchain_native_UDPspeederClient_startSpeeder(
        JNIEnv* env,
        jobject /* this */,
        jstring configParams) {
    
    const char *nativeConfig = env->GetStringUTFChars(configParams, 0);
    LOGI("Starting UDPspeeder with params: %s", nativeConfig);
    
    LOGI("Simulating socket creation (FD: 42)");
    protectSocketFromNative(42);
    
    env->ReleaseStringUTFChars(configParams, nativeConfig);
}

extern "C" JNIEXPORT void JNICALL
Java_com_selcuk9805_vpnchain_native_UDPspeederClient_stopSpeeder(
        JNIEnv* env,
        jobject /* this */) {
    
    LOGI("Stopping UDPspeeder...");
}
