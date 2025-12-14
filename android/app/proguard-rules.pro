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

# 保留行号（用于崩溃日志）
-keepattributes SourceFile,LineNumberTable

# Play Core 相关（Flutter 延迟组件功能，不使用时可忽略）
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
