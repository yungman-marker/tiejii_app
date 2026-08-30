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

  /// 拉取模型列表，并优先选中移动端默认模型。
  Future<void> load() async {
    state = const ModelState(loading: true);
    try {
      final models = await _repository.fetchModels();
      final defaultId = await _repository.fetchDefaultMobileModelId();
      final selected =
          defaultId ?? (models.isNotEmpty ? models.first.id : null);
      state = ModelState(models: models, selectedId: selected);
    } catch (_) {
      state = const ModelState(error: '模型列表加载失败，请检查网络');
    }
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
