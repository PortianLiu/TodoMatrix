# Flutter 相关
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# 保留 MainActivity
-keep class lpt.todo_matrix.MainActivity { *; }

# 保留注解
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 保留行号（用于崩溃日志）
-keepattributes SourceFile,LineNumberTable

# 网络相关（保留 NetworkInterface 等）
-keep class java.net.** { *; }
-keep class java.io.** { *; }
-keep class javax.net.** { *; }

# Dart/Flutter 网络相关
-keep class dart.io.** { *; }

# Play Core 相关（Flutter 延迟组件功能，不使用时可忽略）
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
