import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../data/repositories/agent_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/feedback_repository.dart';
import '../data/repositories/file_repository.dart';
import '../data/repositories/knowledge_repository.dart';
import '../data/repositories/model_repository.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore.instance);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final modelRepositoryProvider =
    Provider<ModelRepository>((ref) => ModelRepository(ref.watch(apiClientProvider)));

/// 智能体（智能中心）仓库。
final agentRepositoryProvider =
    Provider<AgentRepository>((ref) => AgentRepository(ref.watch(apiClientProvider)));

/// 知识库仓库。
final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) =>
    KnowledgeRepository(
      ref.watch(apiClientProvider),
      ref.watch(fileRepositoryProvider),
    ));

/// 意见反馈仓库。
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
    (ref) => FeedbackRepository(ref.watch(apiClientProvider)));

/// 文件上传仓库（对话附件 / 知识库上传）。
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final repo = FileRepository(tokenStore: ref.watch(tokenStoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});
