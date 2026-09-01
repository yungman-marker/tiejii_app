import 'dart:html' as html;

import 'pick_mode.dart';

/// 选中的文件（字节 + 文件名）。
class PickedFile {
  const PickedFile({required this.bytes, required this.name});
  final List<int> bytes;
  final String name;
}

/// Web 端实现：使用 <input type="file"> 读取字节。
///
/// Web 无法调起系统相机/相册，[mode] 仅作接口对齐，统一用文件选择。
Future<PickedFile?> pickFile({
  List<String>? extensions,
  PickMode mode = PickMode.file,
}) async {
  final input = html.FileUploadInputElement();
  input.accept = extensions?.map((e) => '.$e').join(',') ?? '*/*';
  input.click();

  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  final bytes = reader.result as List<int>?;
  if (bytes == null) return null;
  return PickedFile(bytes: bytes, name: file.name);
}
