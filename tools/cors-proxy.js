/* eslint-disable */
// 本地 CORS 反向代理 —— 仅用于本地浏览器调试 Flutter Web。
//
// 背景：后端 SSE 端点（/turnstream、/experiencestream 等）响应头里没有
//  Access-Control-Allow-Origin，浏览器拒绝读取响应体（桌面端走原生 HTTP
//  没有 CORS 概念，所以同样代码桌面能聊、web 不能聊）。
//
// 这个代理：
//   1. 监听 http://localhost:8787
//   2. 把所有请求原样转发到后端（包含 body / headers / method）
//   3. 给响应强制注入 Access-Control-Allow-Origin: *
//   4. SSE 流也走同样逻辑 —— Node 在 proxyRes.headers 回调里 setHeader，
//      setHeader + pipe 会让 ACAO 头随响应头一起先发出去，再 streaming bytes，
//      浏览器看到 ACAO 后正常读取 SSE 流。
//
// 用法（PowerShell / cmd 都行）：
//   node tools/cors-proxy.js
// 另开一个窗口跑 flutter（带 --dart-define 切 baseUrl 到代理）：
//   flutter run -d chrome --dart-define=API_BASE=http://localhost:8787/backendapi
// 不需要装任何 npm 包；纯 Node 标准库。
//
// 退出：Ctrl+C。

const http = require('http');

const TARGET = process.env.PROXY_TARGET || 'http://kygl-crcc-tj-ai-front-vue.test.cdcgy-gw.com/backendapi';
const PORT = Number(process.env.PROXY_PORT || 8787);

let targetUrl;
try {
  targetUrl = new URL(TARGET);
} catch (e) {
  console.error('[cors-proxy] PROXY_TARGET 解析失败：', TARGET);
  process.exit(1);
}

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
  'access-control-allow-headers':
    'Content-Type, Authorization, X-Requested-With, X-Client-Type, Accept, Origin, Referer, User-Agent',
  'access-control-allow-credentials': 'true',
  'access-control-max-age': '86400',
};

// 透传响应头时，把后端的 ACAO 头去掉（以我们的为准，防 Access-Control-Allow-Origin 重复）
function pickResponseHeaders(srcHeaders) {
  const out = {};
  for (const k of Object.keys(srcHeaders)) {
    const lk = k.toLowerCase();
    if (
      lk === 'access-control-allow-origin' ||
      lk === 'access-control-allow-methods' ||
      lk === 'access-control-allow-headers' ||
      lk === 'access-control-allow-credentials' ||
      lk === 'access-control-max-age' ||
      lk === 'access-control-expose-headers'
    ) {
      continue;
    }
    out[k] = srcHeaders[k];
  }
  Object.assign(out, corsHeaders);
  // 不暴露给 JS 的头：去掉 hop-by-hop
  delete out['connection'];
  delete out['transfer-encoding']; // 让 Node 自动 chunked
  return out;
}

const server = http.createServer((req, res) => {
  // 1) 预检 OPTIONS 直接回
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }

  // 2) 构造转发到后端的请求头：去掉 hop-by-hop 与 Host
  const fwdHeaders = { ...req.headers };
  delete fwdHeaders['host'];
  delete fwdHeaders['connection'];
  delete fwdHeaders['origin']; // 去掉本地代理 origin，后端不该看到 localhost
  delete fwdHeaders['referer'];

  const proxyOpts = {
    protocol: targetUrl.protocol,
    hostname: targetUrl.hostname,
    port: targetUrl.port || (targetUrl.protocol === 'https:' ? 443 : 80),
    method: req.method,
    path: req.url, // 已经包含 /backendapi/...
    headers: fwdHeaders,
  };

  const lib = proxyOpts.protocol === 'https:' ? require('https') : http;
  const proxyReq = lib.request(proxyOpts, (proxyRes) => {
    const headers = pickResponseHeaders(proxyRes.headers);
    res.writeHead(proxyRes.statusCode || 502, headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error(
      `[cors-proxy] upstream error: ${req.method} ${req.url} -> ${targetUrl.host}${req.url}\n  ${err.message}`,
    );
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8', ...corsHeaders });
    }
    try {
      res.end(`[cors-proxy] 上游错误：${err.message}\n`);
    } catch (_) {}
  });

  // 客户端断网时，及时杀掉上游
  req.on('close', () => {
    if (!proxyReq.destroyed) proxyReq.destroy();
  });

  req.pipe(proxyReq);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log(`[cors-proxy] listening on http://127.0.0.1:${PORT}`);
  console.log(`[cors-proxy] forwarding to ${targetUrl.protocol}//${targetUrl.host}`);
  console.log('');
  console.log('前端用:  flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:' + PORT + '/backendapi');
  console.log('按 Ctrl+C 退出。');
  console.log('');
});

process.on('SIGINT', () => {
  console.log('\n[cors-proxy] shutting down');
  server.close(() => process.exit(0));
});
