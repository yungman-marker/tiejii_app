import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// 朗读指定文本（浏览器 SpeechSynthesis API）。
///
/// 每次调用先 `cancel()` 当前朗读再 `speak()` 新内容，保证「再点一次」会
/// 重头读而不会叠加。
///
/// 返回 `true` 表示浏览器支持并已开始调度朗读，`false` 表示不支持（如
/// 极个别浏览器未实现 SpeechSynthesis），由业务侧决定要不要兜底。
///
/// [onEnd] 在朗读自然结束、被 `stopReading()` 取消或被下一次 `readAloud`
/// 顶掉时都会触发（Web 的 `onend` 事件，cancel 也会派发）。业务侧用它来
/// 把「正在播放」状态还原回气泡上的图标。
Future<bool> readAloud(String text, {void Function()? onEnd}) async {
  if (text.trim().isEmpty) return false;

  final synth = html.window.speechSynthesis;
  // 取消之前可能正在播放的（无 cancel 时连点会排队）
  try {
    synth?.cancel();
  } catch (_) {}

  if (synth == null) return false;

  // dart:html 的 SpeechSynthesisUtterance 构造直接传字符串
  final utter = html.SpeechSynthesisUtterance(text);
  utter.lang = 'zh-CN';
  utter.rate = 1.0;
  utter.pitch = 1.0;
  utter.volume = 1.0;

  if (onEnd != null) {
    // 用 js_util 设置 onend（Dart 闭包需 allowInterop 才能被 JS 回调）
    js_util.setProperty(utter, 'onend', js_util.allowInterop((_) {
      onEnd();
    }));
  }

  try {
    synth.speak(utter);
    return true;
  } catch (_) {
    return false;
  }
}

/// 主动停止当前正在播放的朗读（调用 SpeechSynthesis.cancel）。
///
/// 取消会触发被取消 utterance 的 `onend`，所以 [readAloud] 传入的 onEnd
/// 也会被回调，业务侧可借此统一清理「正在播放」状态。
Future<void> stopReading() async {
  try {
    html.window.speechSynthesis?.cancel();
  } catch (_) {}
}

/// 分享指定文本（Web Share API → 剪贴板兜底）。
///
/// 优先用 `navigator.share({text, title})`（会唤起系统分享面板，
/// 含微信/QQ/复制等入口）；如果浏览器不支持或用户拒绝，回退到
/// `navigator.clipboard.writeText`，保证文本至少能「到手」。
///
/// 返回 `true` 表示分享面板已弹出 / 文本已写入剪贴板。
Future<bool> shareText(String text) async {
  if (text.trim().isEmpty) return false;
  final nav = html.window.navigator;
  if (nav == null) return false;

  // 用 js_util 调用以避免 dart:html 类型层面不存在的兼容问题
  // （部分 Flutter 内置的 dart:html Navigator 类型不一定带 share 字段）
  final hasShare = js_util.hasProperty(nav, 'share');
  if (hasShare == true) {
    try {
      await js_util.promiseToFuture<void>(
        js_util.callMethod(nav, 'share', [
          js_util.jsify(<String, String>{
            'title': '铁骥大模型',
            'text': text,
          }),
        ]),
      );
      return true;
    } catch (_) {
      // 用户取消分享面板 / 权限拒绝 → 继续走剪贴板兜底
    }
  }

  // 兜底：写入剪贴板
  try {
    final cb = nav.clipboard;
    if (cb == null) return false;
    await js_util.promiseToFuture<void>(
      js_util.callMethod(cb, 'writeText', [text]),
    );
    return true;
  } catch (_) {
    return false;
  }
}