@echo off
REM 启动 Flutter Web 并把 API_BASE 指到本机 CORS 代理（127.0.0.1:8787）。
REM 前提：另开窗口已跑 start_cors_proxy.cmd，或本工具自己 fork 代理进程。
REM 用法（双击或 PowerShell 里 .\start_web_mobile.cmd）：
REM   - 双击本文件 = 同时拉起代理 + 启动 Flutter Web（代理在子窗口里跑）
REM   - 想手工分开也行：终端 A 跑 start_cors_proxy.cmd，终端 B 跑本文件
REM
REM 渲染器由 web/index.html 强制为 html，避开云桌面访问不到的 gstatic CDN。

cd /d D:\test9_1\tiejii_app
echo [1/2] 启动 CORS 代理（子窗口）
start "cors-proxy" /min cmd /c "node tools\cors-proxy.js"

REM 等代理起来再起 Flutter（避免首请求 502）
timeout /t 2 >nul

echo [2/2] 启动 Flutter Web（API_BASE 已经指到 http://127.0.0.1:8787/backendapi）
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8787/backendapi
