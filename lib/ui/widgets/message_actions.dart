/// 消息气泡操作（朗读 / 分享）的跨平台实现。
///
/// - Web 端：`message_actions_web.dart`，用 `dart:html` 调用浏览器
///   `SpeechSynthesis` 与 `navigator.share`，零三方依赖。
/// - 其他平台：`message_actions_io.dart` 走兜底（暂用 `Clipboard`，
///   后续可接入 `flutter_tts` / `share_plus` 后替换实现）。
///
/// 业务侧直接 `import 'package:tiejii_app/ui/widgets/message_actions.dart';`
/// 调 [readAloud] / [shareText] 即可。
library;

export 'message_actions_io.dart'
    if (dart.library.html) 'message_actions_web.dart';
