@echo off
REM 启动 CORS 反向代理 + Flutter Web，用于云桌面 / 内网浏览器调试移动端 UI。
REM 背景：桌面端走原生 HTTP 不触发 CORS，web 浏览器对 SSE 强制校验 ACAO。
REM       后端 SSE 端点（/turnstream 等）目前没回 ACAO 头，所以 web 上聊天会被拦；
REM       这个代理透传请求并强制给所有响应（含 SSE 流）加 ACAO。
REM
REM 用法（双击本文件，或在 PowerShell 里执行 .\run_web_mobile.cmd）：
REM   1. 终端 A：保持本窗口开着（CORS 代理在跑）
REM   2. 终端 B：在新窗口执行  start_web_mobile.cmd
REM
REM 关掉：终端 A 里按 Ctrl+C

cd /d D:\test9_1\tiejii_app
where node >nul 2>nul
if errorlevel 1 (
  echo [error] 没找到 node，先装 Node 18+ 或把 node 路径加到 PATH。
  pause
  exit /b 1
)

echo [1/2] 启动 CORS 代理（http://127.0.0.1:8787  ->  http://kygl-crcc-tj-ai-front-vue.test.cdcgy-gw.com/backendapi）
echo       按 Ctrl+C 停止。
echo.
node tools\cors-proxy.js
