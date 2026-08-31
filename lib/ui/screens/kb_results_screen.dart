import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/sse.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/model_provider.dart';

/// 智能搜索的 searchType（复用 /ai/chat/model/experience:stream 做检索增强）。
const String kSearchTypeKnowledge = 'knowledge_search';

/// 搜索结果 · AI 总结（S6 真实接口）。
/// - 来源列表：POST /ai/chat/knowledgebase/file/searchPage
/// - AI 总结：POST /ai/chat/model/experience:stream（searchType=knowledge_search）
class KbResultsScreen extends ConsumerStatefulWidget {
  const KbResultsScreen({super.key, required this.query});
  final String query;

  @override
  ConsumerState<KbResultsScreen> createState() => _KbResultsScreenState();
}

class _KbResultsScreenState extends ConsumerState<KbResultsScreen> {
  String _summary = '';
  bool _streaming = false;
  bool _loadingSources = true;
  List<SearchSource> _sources = const [];
  String? _error;
  SseSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    _fetchSources();
    _streamSummary();
  }

  Future<void> _fetchSources() async {
    try {
      final page = await ref
          .read(knowledgeRepositoryProvider)
          .searchPage(type: 1, search: widget.query, pageSize: 20);
      if (mounted) {
        setState(() => _sources = page.items
            .map((f) => SearchSource(title: f.displayName, snippet: null, fileName: f.name))
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingSources = false);
    }
  }

  void _streamSummary() {
    final repo = ref.read(chatRepositoryProvider);
    final modelId = ref.read(modelControllerProvider).selectedId;
    if (repo == null) {
      setState(() => _error = '登录状态已失效，请重新登录');
      return;
    }
    if (modelId == null || modelId.isEmpty) {
      setState(() => _error = '请先在「对话」页选择一个模型，再使用智能搜索');
      return;
    }

    setState(() {
      _streaming = true;
      _summary = '';
      _error = null;
    });

    _sub = repo.streamChat(
      modelId: modelId,
      messages: [
        {'role': 'user', 'content': widget.query}
      ],
      searchType: kSearchTypeKnowledge,
      onFrame: (frame) {
        if (frame.isError) {
          setState(() {
            _error = frame.raw['msg']?.toString() ?? '生成失败，请重试';
            _streaming = false;
          });
          return;
        }
        if (!frame.isDelta) return;
        final d = frame.content;
        if (d != null && d.isNotEmpty) {
          setState(() => _summary = _summary + d);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = e is ApiException ? e.message : e.toString();
            _streaming = false;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _streaming = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              _searchResultTitle(widget.query),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _searchResultTitle(String query) {
    final q = query.length > 18 ? '${query.substring(0, 18)}…' : query;
    return '"$q" 的搜索结果';
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _summaryCard(),
        SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('知识库来源（${_sources.length}）',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        if (_loadingSources)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          )
        else if (_sources.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Text('未检索到相关来源', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          ..._sources.map(_sourceTile),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x1A4F7DF9), Color(0x1AA855F7)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x338B5CF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text('AI 总结',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              if (_streaming) ...[
                SizedBox(width: 8),
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              ],
            ],
          ),
          SizedBox(height: 8),
          if (_error != null)
            Text(_error!,
                style: TextStyle(fontSize: 12.5, color: AppColors.danger, height: 1.6))
          else if (_summary.isEmpty && _streaming)
            Text('正在生成总结…',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6))
          else if (_summary.isEmpty)
            Text('暂无总结', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6))
          else
            SelectableText(_summary,
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
        ],
      ),
    );
  }

  Widget _sourceTile(SearchSource s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x140F766E), borderRadius: BorderRadius.circular(4)),
                child: Text('已入库',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (s.snippet != null && s.snippet!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(s.snippet!,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
          ],
        ],
      ),
    );
  }
}
