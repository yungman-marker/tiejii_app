import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/repositories/model_repository.dart';
import 'core_providers.dart';

/// 模型状态。
class ModelState {
  const ModelState({
    this.models = const [],
    this.selectedId,
    this.loading = false,
    this.error,
  });

  final List<ChatModel> models;
  final String? selectedId;
  final bool loading;
  final String? error;

  ModelState copyWith({
    List<ChatModel>? models,
    String? selectedId,
    bool? loading,
    String? error,
  }) =>
      ModelState(
        models: models ?? this.models,
        selectedId: selectedId ?? this.selectedId,
        loading: loading ?? this.loading,
        error: error ?? this.error,
      );
}

class ModelController extends StateNotifier<ModelState> {
  ModelController(this._repository) : super(const ModelState());

  final ModelRepository _repository;

  /// 拉取模型列表，并优先选中默认模型。
  ///
  /// 注意：web 端**不调用** `/ai/chat/model/getDefault`，默认模型直接从
  /// list 响应里的 `isDefault==1` 取。之前为"选中默认"多加的 getDefault
  /// 请求被后端严格校验 body 而 500，因此这里直接复用 list 响应挑选，
  /// 不再发第二个请求。
  Future<void> load() async {
    state = const ModelState(loading: true);
    try {
      final models = await _repository.fetchModels();
      final selected = _pickDefaultId(models);
      state = ModelState(models: models, selectedId: selected);
    } catch (e) {
      // 把真实异常带出来（HTTP 状态码、后端 msg、网络异常类型等），
      // 方便排查"web 能调、exe 不能调"的根因。原先 catch(_) 直接吞了。
      state = ModelState(error: '模型列表加载失败：$e');
    }
  }

  /// 从 list 响应里挑默认模型：优先 isDefault==1，否则取第一个。
  /// 与 web 端行为对齐（web 不调 getDefault，全靠 list 返回的字段）。
  static String? _pickDefaultId(List<ChatModel> models) {
    for (final m in models) {
      if (m.isDefault == 1) return m.id;
    }
    return models.isNotEmpty ? models.first.id : null;
  }

  void select(String id) => state = state.copyWith(selectedId: id);
}

final modelControllerProvider =
    StateNotifierProvider<ModelController, ModelState>(
        (ref) => ModelController(ref.watch(modelRepositoryProvider)));

/// 当前选中的模型对象。
final selectedModelProvider = Provider<ChatModel?>((ref) {
  final state = ref.watch(modelControllerProvider);
  for (final model in state.models) {
    if (model.id == state.selectedId) return model;
  }
  return state.models.isEmpty ? null : state.models.first;
});
