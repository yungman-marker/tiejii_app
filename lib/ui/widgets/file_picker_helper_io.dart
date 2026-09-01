import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'pick_mode.dart';

/// 选中的文件（字节 + 文件名）。
class PickedFile {
  const PickedFile({required this.bytes, required this.name});
  final List<int> bytes;
  final String name;
}

/// 非 Web（Android / iOS / 桌面）实现。
///
/// - 移动端（android / iOS）：拍照/相册走 `image_picker`，任意文件走 `file_picker`。
/// - 桌面端：文件模式走 `file_picker`（跨平台可用）；拍照/相册在桌面无意义，
///   直接抛 [UnsupportedError]，由调用方提示「当前平台不支持」，保持桌面行为不变。
Future<PickedFile?> pickFile({
  List<String>? extensions,
  PickMode mode = PickMode.file,
}) async {
  final isMobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (mode == PickMode.camera || mode == PickMode.gallery) {
    if (!isMobile) {
      throw UnsupportedError('桌面端不支持拍照/相册，请使用文件上传');
    }
    final picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: mode == PickMode.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    return PickedFile(bytes: bytes, name: xfile.name);
  }

  // 任意文件模式：移动端 / 桌面端都用 file_picker
  final result = await FilePicker.platform.pickFiles(
    type: extensions == null ? FileType.any : FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.single;
  final bytes = f.bytes;
  if (bytes == null) return null;
  return PickedFile(bytes: bytes, name: f.name);
}
