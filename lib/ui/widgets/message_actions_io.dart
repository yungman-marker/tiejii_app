import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 模块级单例：避免每次朗读都 new 实例导致 completion 回调错乱。
final FlutterTts _tts = FlutterTts();

/// 朗读指定文本。
///
/// - 移动端（Android / iOS）：用 `flutter_tts` 调系统离线 TTS（支持中文 zh-CN），
///   返回 `true` 表示已开始朗读，[onEnd] 在自然结束或 [stopReading] 取消时回调。
/// - 桌面端：保持原行为——复制到剪贴板并返回 `false`，由业务侧提示
///   「朗读功能仅在移动端可用」，桌面行为零改动。
Future<bool> readAloud(String text, {void Function()? onEnd}) async {
  if (text.trim().isEmpty) return false;

  final isMobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (!isMobile) {
    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }

  try {
    // 先停掉上一段，避免连点叠加
    await _tts.stop();
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(1.0);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    if (onEnd != null) {
      _tts.setCompletionHandler(() => onEnd());
    }
    await _tts.speak(text);
    return true;
  } catch (_) {
    // TTS 不可用兜底：复制到剪贴板
    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }
}

/// 主动停止朗读（移动端停 TTS；桌面端无真实播放，no-op）。
Future<void> stopReading() async {
  try {
    await _tts.stop();
  } catch (_) {}
}

/// 分享指定文本。
///
/// 非 Web 端暂未接入 share SDK（`share_plus` 等），先复制到剪贴板
/// 并返回 `false`。
Future<bool> shareText(String text) async {
  if (text.trim().isEmpty) return false;
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
