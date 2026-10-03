-keep class org.videolan.** { *; }
-keep class com.scovil1.bestplayer.** { *; }
-dontwarn org.videolan.**
-dontwarn kotlin.**
-dontwarn kotlinx.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

