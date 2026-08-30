// web 端：将原 URL（getMinioUrl）抓成 Blob，再生成 Blob URL 喂给 WebView。
//
// 原因：minio 的预览链接经常带 `Content-Disposition: attachment`，
// 浏览器在 iframe/WebView 里加载时不会渲染、只走下载，画面就是一片白。
// 抓成 Blob 后变成同源 blob: URL，浏览器内置 PDF 阅读器能正常出图。
//
// 失败/不支持（状态码非 200 / fetch 抛错）→ 退回原 URL，让 WebView 自己试。

import 'dart:async';
import 'dart:html' as html;

Future<String> resolvePreviewUrl(String url) async {
  try {
    final completer = Completer<String>();
    final xhr = html.HttpRequest();
    xhr.open('GET', url);
    xhr.responseType = 'blob';
    xhr.onLoadEnd.listen((_) {
      try {
        if (xhr.status == 200 && xhr.response is html.Blob) {
          final blob = xhr.response as html.Blob;
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          completer.complete(blobUrl);
        } else {
          completer.complete(url);
        }
      } catch (_) {
        completer.complete(url);
      }
    });
    xhr.onError.listen((_) => completer.complete(url));
    xhr.send();
    return completer.future;
  } catch (_) {
    return url;
  }
}
