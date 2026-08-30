import 'dart:html' as html;

/// 选中的文件（字节 + 文件名）。
class PickedFile {
  const PickedFile({required this.bytes, required this.name});
  final List<int> bytes;
  final String name;
}

/// Web 端实现：使用 <input type="file"> 读取字节。
Future<PickedFile?> pickFile({List<String>? extensions}) async {
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
