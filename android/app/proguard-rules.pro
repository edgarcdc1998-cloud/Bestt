-keep class org.videolan.** { *; }
-keep class com.scovil1.bestplayer.** { *; }
-dontwarn org.videolan.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
