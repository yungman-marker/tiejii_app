import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// web 端文件预览兜底。
///
/// `webview_flutter` 不支持 web 平台，内嵌预览在浏览器里不可用，
/// 因此这里直接引导用户点「在浏览器打开」（由 [FilePreviewScreen] 顶栏提供）。
/// 命名与 [webview_pane_native.dart] 保持一致，通过条件导入二选一。
class WebViewPane extends StatelessWidget {
  const WebViewPane({
    required this.url,
    required this.originalUrl,
    required this.onOpenExternal,
  });

  final String url;
  final String originalUrl;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_browser, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              '网页端暂不支持内嵌预览，请点右上角「在浏览器打开」',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('在浏览器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
