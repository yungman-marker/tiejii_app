import '../models/models.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/file_repository.dart';

/// 知识库仓库。
///
/// 已确认接口（实测，2026-08-30 抓 web 端确认）：
/// - POST /ai/chat/knowledgebase/file/queryAllDirectoryList
///       空 body（用户 16:39 截图确认是 POST），返回全量目录树
///       （id/fileOriginalName/parentId/fullPath/type/children）。
/// - GET  /ai/chat/knowledgebase/getCapacity/{dirId}
///       容量（dirId='0' = 根）。
/// - POST /ai/chat/knowledgebase/file/searchPage
///       检索分页（智能搜索结果页用，item 是文件粒度）。
///
/// 待联调确认（前端逆向未覆盖写操作，路径按命名惯例推断）：
/// - POST /ai/chat/knowledgebase/file/upload        上传
class KnowledgeRepository {
  KnowledgeRepository(this._api, this._fileRepo);

  final ApiClient _api;
  final FileRepository _fileRepo;

  /// 拉全量目录树（一次返回所有根 → 子 → 孙，递归）。
  ///
  /// **2026-08-30 用户截图确认是 POST**（服务端 405: "Request method 'GET' not supported"）
  /// body 传空 `{}`，type 过滤在客户端做。
  Future<List<KnowledgeDirectory>> queryAllDirectoryList() async {
    final data = await _api.post<List<dynamic>>(
      '/ai/chat/knowledgebase/file/queryAllDirectoryList',
      body: const <String, dynamic>{},
      parser: (raw) => raw is List<dynamic> ? raw : null,
    );
    if (data == null) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(KnowledgeDirectory.fromJson)
        .toList(growable: false);
  }

  /// 目录文件列表（点进某个目录后拉该目录下的文件）。
  ///
  /// 真实接口（用户 2026-08-30 抓 web 端确认）：
  ///   POST /ai/chat/knowledgebase/file/list?page=1&pageSize=20&search=
  ///   body: { fileType: null, type: "<目录type>", parentId: "<dirId>",
  ///           orderField: "createdTime", orderSn: "desc" }
  ///   返回 data: { total: int, items: [<文件>] }
  Future<KnowledgePage> fileList({
    required String parentId,
    required String type,
    int page = 1,
    int pageSize = 20,
    String search = '',
    String? fileType,
    String orderField = 'createdTime',
    String orderSn = 'desc',
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/knowledgebase/file/list'
      '?page=$page&pageSize=$pageSize&search=${Uri.encodeComponent(search)}',
      body: {
        'fileType': fileType,
        'type': type,
        'parentId': parentId,
        'orderField': orderField,
        'orderSn': orderSn,
      },
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    final items = _files(data?['items']);
    final total = _toInt(data?['total']);
    return KnowledgePage(
      items: items,
      total: total,
      hasMore: items.length >= pageSize,
    );
  }

  /// 容量（dirId 默认 '0' 表示根目录）。
  Future<KnowledgeCapacity> capacity([String dirId = '0']) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/ai/chat/knowledgebase/getCapacity/$dirId',
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    return KnowledgeCapacity.fromJson(data);
  }

  /// 检索分页（智能搜索来源列表）。
  Future<KnowledgePage> searchPage({
    required int type,
    required String search,
    int page = 1,
    int pageSize = 10,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/knowledgebase/file/searchPage',
      body: {
        'page': page,
        'pageSize': pageSize,
        'search': search,
        'type': type,
      },
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    final items = _files(data?['items'] ?? data?['records']);
    return KnowledgePage(
      items: items,
      total: _toInt(data?['total']),
      hasMore: items.length >= pageSize,
    );
  }

  /// 上传文件到知识库。
  ///
  /// 复用 [FileRepository] 的多部件上传（POST /file/upload），
  /// 业务字段带 `type` / `dirId`（与知识库接口对齐）。
  Future<Map<String, dynamic>> upload({
    required int type,
    required List<int> bytes,
    required String fileName,
    String dirId = '0',
  }) =>
      _fileRepo.upload(
        bytes: bytes,
        fileName: fileName,
        fields: {'type': type.toString(), 'dirId': dirId},
      );

  static List<KnowledgeFile> _files(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(KnowledgeFile.fromJson)
        .toList();
  }

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
