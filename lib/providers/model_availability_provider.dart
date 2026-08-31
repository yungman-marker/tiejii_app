import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 模型可用性状态。
///
/// 服务端不同模型的可用状态参差（实测：TJ1.0-multi / Qwen3.8-chat 可用，
/// 部分模型返回 400、或长时间无内容、或仅下发控制帧），需要**实时**反映给用户。
///
/// 状态来源是「对话实测」：发起一次对话即标记为 checking，拿到首个增量正文即
/// available；出现 400 / 超时 / ERROR 帧 / 空响应则标记为 unavailable 并给出提示。
enum ModelAvailability { unknown, checking, available, unavailable }

/// 模型可用性全局状态。
class ModelAvailabilityState {
  const ModelAvailabilityState({
    this.status = const {},
    this.reason = const {},
    this.notice,
    this.noticeModelId,
  });

  /// 每个模型 id 的可用性。
  final Map<String, ModelAvailability> status;

  /// 不可用原因（仅 unavailable 时有值）。
  final Map<String, String> reason;

  /// 给用户的全局提示（例如「模型 X 当前不可用，请切换」）。
  final String? notice;

  /// 该提示针对的模型 id，便于在该模型恢复可用时自动清除提示。
  final String? noticeModelId;

  ModelAvailabilityState copyWith({
    Map<String, ModelAvailability>? status,
    Map<String, String>? reason,
    String? notice,
    bool clearNotice = false,
    String? noticeModelId,
  }) =>
      ModelAvailabilityState(
        status: status ?? this.status,
        reason: reason ?? this.reason,
        notice: clearNotice ? null : (notice ?? this.notice),
        noticeModelId: clearNotice ? null : (noticeModelId ?? this.noticeModelId),
      );
}

class ModelAvailabilityController extends StateNotifier<ModelAvailabilityState> {
  ModelAvailabilityController() : super(const ModelAvailabilityState());

  /// 发起一次对话 → 进入「检测中」。同时清掉旧的提示（新的请求即新的开始）。
  void markChecking(String id) {
    final status = {...state.status, id: ModelAvailability.checking};
    state = state.copyWith(status: status, clearNotice: true);
  }

  /// 拿到首个正文 → 可用。若之前提示是针对该模型，清除提示。
  void markAvailable(String id) {
    final status = {...state.status, id: ModelAvailability.available};
    final reason = {...state.reason}..remove(id);
    final clearNotice = state.noticeModelId == id;
    state = state.copyWith(
      status: status,
      reason: reason,
      clearNotice: clearNotice,
    );
  }

  /// 检测失败 → 不可用，并生成给用户的提示。
  ///
  /// [reason] 是简短原因（如「HTTP 400：该模型暂未开通」），
  /// [modelName] 用于拼接提示文案。
  void markUnavailable(String id, {required String reason, String? modelName}) {
    final status = {...state.status, id: ModelAvailability.unavailable};
    final reasonMap = {...state.reason, id: reason};
    final name = modelName ?? id;
    final notice =
        '模型「$name」当前不可用：$reason。请切换其他模型，或在模型面板重试。';
    state = state.copyWith(
      status: status,
      reason: reasonMap,
      notice: notice,
      noticeModelId: id,
    );
  }

  /// 用户手动清除提示横幅。
  void clearNotice() => state = state.copyWith(clearNotice: true);

  /// 清掉某模型的所有可用性痕迹（status / reason / 若 notice 是该模型也一并清）。
  ///
  /// 使用场景：用户在模型面板切换到一个"被标暂不可用"的模型时（实际可能是
  /// 之前的网络/CORS 错误被错误标记），重置为 unknown，让下次对话有机会
  /// 通过 markAvailable / markUnavailable 重新判定。
  void clear(String id) {
    final status = {...state.status}..remove(id);
    final reason = {...state.reason}..remove(id);
    final clearNotice = state.noticeModelId == id;
    state = state.copyWith(
      status: status,
      reason: reason,
      clearNotice: clearNotice,
    );
  }
}

final modelAvailabilityProvider =
    StateNotifierProvider<ModelAvailabilityController, ModelAvailabilityState>(
        (ref) => ModelAvailabilityController());

/// 便捷读取某模型当前可用性。
final modelStatusProvider = Provider.family<ModelAvailability, String>((ref, id) {
  return ref.watch(modelAvailabilityProvider).status[id] ??
      ModelAvailability.unknown;
});
