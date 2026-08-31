import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

/// 内嵌 WebView 面板（原生端：Android / iOS / 桌面）。
///
/// 负责 controller 生命周期 + 加载态 / 错误态 / 超时回退。
/// web 端由 [webview_pane_web.dart] 的同名类兜底（webview_flutter 不支持 web）。
class WebViewPane extends StatefulWidget {
  const WebViewPane({
    required this.url,
    required this.originalUrl,
    required this.onOpenExternal,
  });

  /// 解析后的预览地址（web 端可能是 Blob URL）。
  final String url;

  /// 原始地址（用于"在浏览器打开"）。
  final String originalUrl;

  final VoidCallback onOpenExternal;

  @override
  State<WebViewPane> createState() => WebViewPaneState();
}

class WebViewPaneState extends State<WebViewPane> {
  static const Duration _loadTimeout = Duration(seconds: 10);

  late final WebViewController _controller;
  Timer? _timeoutTimer;
  bool _loading = true;
  bool _timedOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _timedOut = false;
              _error = null;
            });
            _armTimeout();
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
            _timeoutTimer?.cancel();
          },
          onWebResourceError: (e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = e.description;
            });
            _timeoutTimer?.cancel();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _armTimeout();
  }

  void _armTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _loading = false;
          _timedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _fallback('预览加载失败：$_error');
    }
    if (_timedOut) {
      return _fallback('预览加载超时（可能是格式不被当前内核支持，或链接已失效）');
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallback(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onOpenExternal,
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('在浏览器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
