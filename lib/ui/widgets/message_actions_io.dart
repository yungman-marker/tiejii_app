import 'package:flutter/services.dart';

/// 朗读指定文本。
///
/// 非 Web 端暂未接入 TTS SDK（`flutter_tts` 等），这里先复制到剪贴板
/// 并返回 `false`，由业务侧决定是否提示「朗读功能仅在 Web 端可用」。
/// 业务侧可以拿这个返回值判断是否要弹 SnackBar。
///
/// [onEnd] 在非 Web 端不会被回调（没有真实播放），保留参数仅为接口对齐。
Future<bool> readAloud(String text, {void Function()? onEnd}) async {
  if (text.trim().isEmpty) return false;
  // 兜底：把文本复制到剪贴板，至少让用户能贴到外部 TTS 工具里听。
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

/// 主动停止朗读。非 Web 端无真实播放，此处为 no-op，保持接口一致。
Future<void> stopReading() async {}

/// 分享指定文本。
///
/// 非 Web 端暂未接入 share SDK（`share_plus` 等），先复制到剪贴板
/// 并返回 `false`。
Future<bool> shareText(String text) async {
  if (text.trim().isEmpty) return false;
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}