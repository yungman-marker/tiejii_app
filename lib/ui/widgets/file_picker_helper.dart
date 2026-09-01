/// 文件选择器（跨平台）。
///
/// 仅做条件导出：Web 端用 `dart:html` 实现，非 Web（移动端 / 桌面）用
/// `file_picker_helper_io.dart` 的兜底（需引入 file_picker 包后实现）。
/// 业务侧直接 `import` 本文件，使用导出的 [pickFile] 与 [PickedFile] 即可。
library;

export 'pick_mode.dart';
export 'file_picker_helper_io.dart' if (dart.library.html) 'file_picker_helper_web.dart';
