# Flutter standard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class org.chromium.** { *; }

# Keep native MainActivity RASP checks
-keep class com.example.we_deliver.MainActivity { *; }
-keepclassmembers class com.example.we_deliver.MainActivity {
    private *** checkSignature(...);
    private *** checkRoot(...);
    private *** checkEmulator(...);
    private *** checkFrida(...);
    private *** checkUsbDebugging(...);
    private *** checkIntegrity(...);
    private *** isNativeDebug(...);
}

# Keep Google Play Services and Google Maps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.libraries.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Ignore missing Play Core classes referenced by Flutter's deferred components feature
-dontwarn com.google.android.play.core.**

# Keep AppsFlyer SDK
-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**
