import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
// web 端：把 getMinioUrl 抓成 Blob URL，绕过 Content-Disposition: attachment 导致的白屏。
// 非 web：原样返回，WebView 走原生内核。
import '../../utils/preview_url_helper.dart'
    if (dart.library.html) '../../utils/preview_url_helper_web.dart';
// WebView 面板：原生端用 webview_flutter，web 端用占位兜底（webview_flutter 不支持 web）。
import '../widgets/webview_pane_native.dart'
    if (dart.library.html) '../widgets/webview_pane_web.dart';

/// 文件预览（在 APP 内打开，不跳外部浏览器）。
/// - 图片（png/jpg/...）：原生 Image.network，体验最佳。
/// - 其余（pdf / doc / xls / ppt / html / txt 等）：先把 URL 解析成可被 iframe 渲染的
///   地址（web 端用 Blob URL 绕开 attachment 头），再交给内嵌 WebView 加载。
/// - WebView 长时间不出图（>10s）→ 自动切到「在浏览器打开」兜底页。
/// - 顶栏始终提供「在浏览器打开」按钮，用户随时可外跳。
class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({
    super.key,
    required this.url,
    required this.name,
    required this.ext,
  });

  /// 文件预览地址（getMinioUrl 完整链接）。
  final String url;

  /// 文件名（仅 UI 标题用）。
  final String name;

  /// 扩展名（不含点），决定用原生图片视图还是 WebView。
  final String ext;

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  static const List<String> _imageExts = [
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp',
  ];

  late final Future<String> _resolvedUrlFuture;

  bool get _isImage => _imageExts.contains(widget.ext.toLowerCase());

  @override
  void initState() {
    super.initState();
    // 图片不需要 resolve；非图片在 web 端走 Blob 抓包，非 web 走原始 URL。
    _resolvedUrlFuture =
        _isImage ? Future.value(widget.url) : resolvePreviewUrl(widget.url);
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法在外部浏览器打开')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage;
    return Scaffold(
      backgroundColor: isImage ? Colors.black : AppColors.background,
      appBar: AppBar(
        backgroundColor: isImage ? Colors.black : Colors.white,
        foregroundColor: isImage ? Colors.white : AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.name.isEmpty ? '预览' : widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: '在浏览器打开',
            icon: const Icon(Icons.open_in_browser, size: 20),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: isImage ? _imageView() : _webPreview(),
    );
  }

  Widget _imageView() {
    return Center(
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          );
        },
        errorBuilder: (ctx, error, stack) => _fallback(
          '图片加载失败（可能跨域或链接失效）',
        ),
      ),
    );
  }

  Widget _webPreview() {
    return FutureBuilder<String>(
      future: _resolvedUrlFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          );
        }
        final url = snap.data ?? widget.url;
        return WebViewPane(
          url: url,
          originalUrl: widget.url,
          onOpenExternal: _openExternal,
        );
      },
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
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('在浏览器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
