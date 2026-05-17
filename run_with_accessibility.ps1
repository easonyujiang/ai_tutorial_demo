$adb = "C:\Users\xuany\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$apk = "e:\Create\Code\ai_tutorial_demo\frontend\build\app\outputs\flutter-apk\app-debug.apk"
$package = "com.example.frontend"
$service = "$package/$package.TutorialAccessibilityService"

Write-Host "=== 步骤 1/5: 安装 APK ===" -ForegroundColor Cyan
& $adb install -r $apk

Write-Host "`n=== 步骤 2/5: 先停用无障碍服务（重置状态） ===" -ForegroundColor Cyan
& $adb shell settings put secure enabled_accessibility_services ""
& $adb shell settings put secure accessibility_enabled 0
Start-Sleep -Seconds 1

Write-Host "`n=== 步骤 3/5: 启用无障碍服务 ===" -ForegroundColor Cyan
& $adb shell settings put secure enabled_accessibility_services $service
& $adb shell settings put secure accessibility_enabled 1
Write-Host "无障碍服务已启用: $service" -ForegroundColor Green

Write-Host "`n=== 步骤 4/5: 等待无障碍服务完成连接 (3s) ===" -ForegroundColor Yellow
Start-Sleep -Seconds 3
$enabled = & $adb shell settings get secure enabled_accessibility_services
Write-Host "当前已启用的无障碍服务: $enabled" -ForegroundColor Green

Write-Host "`n=== 步骤 5/5: 启动应用 ===" -ForegroundColor Cyan
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1

Write-Host "`n完成! 应用已启动，无障碍权限已就绪 (服务已预热 3s)" -ForegroundColor Green
