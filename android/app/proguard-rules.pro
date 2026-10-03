-keep class org.videolan.** { *; }
-keep class com.scovil1.bestplayer.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn org.videolan.**
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn io.flutter.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
