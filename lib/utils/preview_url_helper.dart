// 非 web 平台的占位实现：原样返回原 URL。
//
// 真正干活的是 `preview_url_helper_web.dart`，通过条件导入只在 web 端生效。
Future<String> resolvePreviewUrl(String url) async => url;
