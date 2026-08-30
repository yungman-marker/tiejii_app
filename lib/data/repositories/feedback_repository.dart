import '../models/models.dart';
import '../../core/network/api_client.dart';

/// 意见反馈仓库。
///
/// 接口（实测，见《移动端接口对接文档》6.4 / 6.5）：
/// - POST /ai/chat/feedback/querySetting  反馈设置（问题类型 / 答复方式下拉）
/// - POST /ai/chat/feedback/submit        提交反馈
/// - POST /ai/chat/feedback/query         我的反馈列表（type: 1=我提交的, 2=我的回复）
class FeedbackRepository {
  FeedbackRepository(this._api);

  final ApiClient _api;

  /// 反馈设置：问题类型、答复方式下拉选项。
  Future<FeedbackSetting> querySetting() async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/feedback/querySetting',
      body: {},
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (data == null) return const FeedbackSetting();

    // 字段名不统一，逐个兜底尝试。
    final qt = _options(data['questionTypeList'] ??
        data['questionTypes'] ??
        data['questionType'] ??
        data['questionTypeOptions']);
    final at = _options(data['answerTypeList'] ??
        data['answerTypes'] ??
        data['answerType'] ??
        data['answerTypeOptions']);
    return FeedbackSetting(questionTypes: qt, answerTypes: at);
  }

  /// 提交反馈。
  /// [contact] 为选填联系方式（电话 / 邮箱）。
  Future<void> submit({
    required String questionTypeCode,
    required String answerTypeCode,
    required String content,
    String contact = '',
  }) async {
    await _api.post(
      '/ai/chat/feedback/submit',
      body: {
        'questionType': questionTypeCode,
        'answerType': answerTypeCode,
        'content': content,
        'contact': contact,
      },
    );
  }

  /// 我的反馈列表。
  /// [kind]=1 我提交的，[kind]=2 我的回复。
  Future<List<FeedbackItem>> query({required int kind}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/feedback/query',
      body: {'type': kind},
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    final raw = data?['items'] ?? data?['records'] ?? data?['list'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FeedbackItem.fromJson)
        .toList();
  }

  static List<FeedbackOption> _options(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FeedbackOption.fromJson)
        .toList();
  }
}
