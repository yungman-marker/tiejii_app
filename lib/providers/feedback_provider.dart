import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/models/models.dart';
import '../data/repositories/feedback_repository.dart';
import 'core_providers.dart';

/// 反馈仓库。
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
    (ref) => FeedbackRepository(ref.watch(apiClientProvider)));

/// 反馈分段：0=我提交的 1=我的回复。
class FeedbackState {
  const FeedbackState({
    this.tab = 0,
    this.submitted = const [],
    this.replies = const [],
    this.setting = const FeedbackSetting(),
    this.loading = false,
    this.submitting = false,
    this.error,
  });

  final int tab;
  final List<FeedbackItem> submitted;
  final List<FeedbackItem> replies;
  final FeedbackSetting setting;
  final bool loading;
  final bool submitting;
  final String? error;

  List<FeedbackItem> get current => tab == 0 ? submitted : replies;

  FeedbackState copyWith({
    int? tab,
    List<FeedbackItem>? submitted,
    List<FeedbackItem>? replies,
    FeedbackSetting? setting,
    bool? loading,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      FeedbackState(
        tab: tab ?? this.tab,
        submitted: submitted ?? this.submitted,
        replies: replies ?? this.replies,
        setting: setting ?? this.setting,
        loading: loading ?? this.loading,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class FeedbackController extends StateNotifier<FeedbackState> {
  FeedbackController(this._ref) : super(const FeedbackState());

  final Ref _ref;

  FeedbackRepository get _repo => _ref.read(feedbackRepositoryProvider);

  void setTab(int tab) {
    state = state.copyWith(tab: tab);
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.query(kind: 1),
        _repo.query(kind: 2),
      ]);
      state = state.copyWith(
        submitted: results[0],
        replies: results[1],
        loading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: _describe(e));
    }
  }

  /// 拉取反馈设置（提交前调用，确保下拉有选项）。
  Future<void> ensureSetting() async {
    if (state.setting.questionTypes.isNotEmpty) return;
    try {
      final setting = await _repo.querySetting();
      state = state.copyWith(setting: setting);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: _describe(e));
    }
  }

  Future<bool> submit({
    required String questionTypeCode,
    required String answerTypeCode,
    required String content,
    String contact = '',
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await _repo.submit(
        questionTypeCode: questionTypeCode,
        answerTypeCode: answerTypeCode,
        content: content,
        contact: contact,
      );
      state = state.copyWith(submitting: false);
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(submitting: false, error: _describe(e));
      return false;
    }
  }

  static String _describe(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('cors') || t.contains('cross-origin')) {
      return '浏览器跨域被拦截（Web 端限制），桌面/移动端不受影响';
    }
    if (t.contains('timeout')) return '请求超时';
    if (t.contains('socket') || t.contains('connection')) return '网络连接失败';
    return e.toString();
  }
}

final feedbackControllerProvider = StateNotifierProvider<FeedbackController,
    FeedbackState>((ref) => FeedbackController(ref));
