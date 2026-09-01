import 'package:flutter/foundation.dart';
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

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS 的 speechRate 范围 0(最慢)~1(最快)，正常语速约 0.5；
      // 之前用 1.0 正是“最快”档，所以耳机里听到的语速过快。
      await _tts.setSpeechRate(0.5);
      // iOS 音频路由默认走听筒(receiver)，无耳机时外放无声。
      // 用共享 session + playback + defaultToSpeaker：无耳机时走主扬声器，
      // 插耳机/蓝牙时自动切换（defaultToSpeaker 只覆盖“无外接设备”的情况）。
      // 另外语音输入(speech_to_text)会把 AVAudioSession 设为 playAndRecord 占用
      // 路由，这里每次朗读前重设一遍可强制修正回扬声器。
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
      );
    } else {
      // Android 的 speechRate 范围 0~2，1.0 为正常语速
      await _tts.setSpeechRate(1.0);
    }

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
