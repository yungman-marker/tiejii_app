import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 外放声音（语音播报）开关：
/// - UI 层在 ChatScreen 顶栏显示 🔊 / 🔈 状态；
/// - 开启后，每一条助手回复在流式生成结束时自动朗读（Web 走浏览器 SpeechSynthesis）。
final voiceOutputEnabledProvider = StateProvider<bool>((ref) => false);
