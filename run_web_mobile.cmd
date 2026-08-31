@echo off
REM 启动 Flutter Web（渲染器已在 web/index.html 强制为 html，避开云桌面访问不到的 gstatic CDN 导致白屏）
REM 用法：双击本文件，或在该目录的 PowerShell 里执行 .\run_web_mobile.cmd
cd /d D:\test9_1\tiejii_app
flutter run -d chrome
