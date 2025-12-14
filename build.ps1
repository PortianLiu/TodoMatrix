# 仅需修改这2个变量！路径含空格直接写，PowerShell自动兼容
$APP_VERSION = "2.1.6"
$INNO_SCRIPT = "TodoMatrix.iss"

# ===================== 核心构建步骤 =====================
# 1. 清理Flutter缓存
flutter clean

# 2. 构建Windows Release产物
flutter build windows --release

# 3. 构建Android Release APK（复用本地key.properties签名）
flutter build apk --release

# 4. 7Z压缩Windows产物（最高压缩级别+多线程）
7z a -t7z -mx=9 -mmt=on "build\TodoMatrix_Win_v$APP_VERSION.7z" "build\windows\x64\runner\Release\*"

# 5. InnoSetup打包安装包（传递版本号环境变量）
$env:MY_APP_VERSION = $APP_VERSION
ISCC $INNO_SCRIPT /O"build" /F"TodoMatrix_Setup_v$APP_VERSION"
# 6. 重命名APK（覆盖已有文件）
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "build\TodoMatrix_Android_v$APP_VERSION.apk" -Force