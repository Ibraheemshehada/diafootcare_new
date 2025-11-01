# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep model classes
-keep class * implements org.tensorflow.lite.flex.** { *; }

