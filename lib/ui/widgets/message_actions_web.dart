import 'dart:html' as html;
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';

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
///
/// 注：Flutter 3.47 起 `dart:js_util` 已从 SDK 移除，这里改用 `dart:js_interop`
/// + `dart:js_interop_unsafe` 完成 onend 回调与 navigator.share 的调用。
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
    // 用 js_interop 设置 onend（Dart 闭包需转成 JS 函数才能被 JS 回调）
    final utterJs = utter as js.JSObject;
    utterJs.setProperty('onend'.toJS, onEnd.toJS);
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

  final navJs = nav as js.JSObject;
  // navigator.share 在 dart:html 类型层未声明，用 js_interop 探测并调用
  final shareFn = navJs['share'];
  if (shareFn != null) {
    try {
      // 手动构造 share 入参对象，避免依赖 jsify 的扩展签名差异
      final shareObj = js.JSObject();
      shareObj.setProperty('title'.toJS, '铁骥大模型'.toJS);
      shareObj.setProperty('text'.toJS, text.toJS);

      final promise = navJs.callMethod('share'.toJS, shareObj);
      await (promise as js.JSPromise).toDart;
      return true;
    } catch (_) {
      // 用户取消分享面板 / 权限拒绝 → 继续走剪贴板兜底
    }
  }

  // 兜底：写入剪贴板
  try {
    final cb = nav.clipboard;
    if (cb == null) return false;
    await cb.writeText(text);
    return true;
  } catch (_) {
    return false;
  }
}
