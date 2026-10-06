# proguard-rules.pro — CryptoVault (secured)

# ✅ V4 — Supprime tous les appels android.util.Log au moment du build release.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ── Keep rules pour que R8 ne casse pas Flutter et les plugins ──────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_secure_storage (Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# webview_flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Conserver les annotations et les attributs nécessaires
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
