/// 文件选择来源：相机拍照 / 相册选图 / 任意文件。
///
/// 跨平台统一枚举，移动端（image_picker + file_picker）与 Web（<input type=file>）
/// 共用同一调用签名。
enum PickMode { camera, gallery, file }
