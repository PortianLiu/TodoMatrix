@echo off
:: 仅需改这2个变量！路径含空格必须用双引号包裹
set APP_VERSION=2.1.6
set INNO_SCRIPT="TodoMatrix.iss"

:: 1. 清理
flutter clean

:: 2. 构建Windows Release
flutter build windows --release

:: 3. 构建Android Release（复用本地key.properties签名）
flutter build apk --release

:: 4. 7Z压缩Windows产物（最高压缩）
7z a -t7z -mx=9 -mmt=on build\TodoMatrix_Win_v%APP_VERSION%.7z build\windows\x64\runner\Release\*

:: 5. InnoSetup打包安装包（传版本号，路径已带引号）
set MY_APP_VERSION=%APP_VERSION%
ISCC %INNO_SCRIPT% /Obuild /FTodoMatrix_Setup_v%APP_VERSION%.exe

:: 6. 重命名APK
copy /y build\app\outputs\flutter-apk\app-release.apk build\TodoMatrix_Android_v%APP_VERSION%.apk