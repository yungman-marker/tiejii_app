/// 选中的文件（字节 + 文件名）。
class PickedFile {
  const PickedFile({required this.bytes, required this.name});
  final List<int> bytes;
  final String name;
}

/// 非 Web（Android / iOS / 桌面）兜底实现。
///
/// 原生平台没有内置文件选择器，需引入 `file_picker` 包后在此实现：
///   final result = await FilePicker.platform.pickFiles();
///   return PickedFile(bytes: result!.files.single.bytes!, name: result.files.single.name);
/// 在 pubspec.yaml 加入 `file_picker: ^8.0.0` 并 `flutter pub get` 后即可生效。
Future<PickedFile?> pickFile({List<String>? extensions}) async {
  throw UnsupportedError('移动端文件选择请引入 file_picker 包（见 file_picker_helper_io.dart）');
}
