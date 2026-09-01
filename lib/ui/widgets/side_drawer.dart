
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/model_provider.dart';
import 'model_sheet.dart';
import 'settings_dialog.dart';
import 'top_bar_icons.dart';

/// 左侧滑动抽屉（全局，挂在各 Shell 子屏的 Scaffold 上）。
///
/// [embedded] = true 时（桌面端宽屏）：不包 [Drawer] 遮罩，直接返回内容本体，
/// 由 [MainShell] 以常驻侧栏形式放在 [Row] 左侧常驻显示；点击导航项不再 pop（无抽屉可关）。
/// [embedded] = false 时（移动/窄屏）：保持原 overlay [Drawer] 行为。
///
/// 千问式下拉刷新：
/// - Drawer 内容整体跟手指下移（Transform.translate）
/// - 顶部 80px 区为手势触发区（Stack Positioned + GestureDetector）
/// - 松手时如果拉过阈值（≥80）触发刷新，否则 snap-back 回原位
/// - Loading 圆圈钉在 SafeArea padding 之内的顶部位置；
///   drawer 内容下移时视觉上"留在抽屉外面那块新出现的空白处"
///
/// 入口（按设计稿调整，忽略「模型广场 / AI工具 / 智能机器人」）：
///   新建对话 / 智能体 / 知识库 / 模型选择 / (个人中心)设置
///   历史对话（游标分页，今天·更早）
class SideDrawer extends ConsumerStatefulWidget {
  final bool embedded;
  const SideDrawer({super.key, this.embedded = false});

  @override
  ConsumerState<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends ConsumerState<SideDrawer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// 抽屉滚动控制器。
  final ScrollController _scrollController = ScrollController();

  /// 多端实时同步轮询间隔：10s。「准实时」——其他设备新建的会话，本端最多
  /// 10s 后自动出现；流量极小（只拉 summary，不含消息明细）。
  static const Duration _pollInterval = Duration(seconds: 10);

  /// 多端实时同步轮询定时器（应用在前台时运行；切后台由
  /// [didChangeAppLifecycleState] 暂停，省流量）。
  Timer? _pollTimer;

  /// 抽屉是否处于「搜索模式」（点头部搜索 icon 进入；点取消退出）。
  /// 搜索模式下整抽屉切到 iOS 风搜索视图：顶栏变圆角胶囊+取消，
  /// body 只显示匹配的历史结果；**抽屉保持打开不动**。
  bool _searching = false;

  /// 搜索模式下顶部搜索框的控制器 + 焦点 + 当前查询。
  /// 实时按会话标题（不区分大小写）过滤下方历史。
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  /// 历史对话"客户端虚拟分页"——后端不分页（一次返回 30 条），所以抽屉内自己
  /// 按 [kHistoryPageSize] 一批一批渲染；下滑到底部 +15，UI 上自动扩展。
  static const int kHistoryPageSize = 15;
  int _historyShown = kHistoryPageSize;
  bool _historyLoadingMore = false;

  /// snap-back 动画驱动器（drawer 抽屉松手后回归原位的缓动）。
  late final AnimationController _snapController;

  /// 当前下拉距离（dy，正数=drawer 向下平移）。松手后被 snap 动画重置为 0。
  double _dragDy = 0.0;

  /// snap-back 起点（_dragDy 在 snap 启动时的值）。
  double _snapStart = 0.0;

  /// 是否正在下拉跟踪（手指按着 / 移动）。
  bool _pulling = false;

  /// 拉到这个距离松手即触发刷新。
  static const double _triggerDist = 80.0;

  /// 最大可下拉距离（防止抽屉过度拉出屏外）。
  static const double _maxDist = 130.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(_onSnapTick);
    // 监听列表滚动：滚到底部自动加载下一页（无限滚动，替代「加载更多」手动按钮）
    _scrollController.addListener(_onScroll);
    // 搜索模式：搜索框文本变化时把查询同步到 _searchQuery 触发 rebuild（过滤历史列表）
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
    // 短列表（内容未溢出抽屉，但服务端仍 hasMore）自动级联加载下一页，
    // 直到列表溢出或没有更多，避免历史被分页"卡住"需要手动操作。
    // 仅当本次加载确实新增了条目才继续级联，防止服务端异常返回相同数据导致死循环。
    ref.listenManual<ChatState>(chatControllerProvider, (prev, next) {
      // 1) 短列表级联加载（现有逻辑）：本次加载新增了条目且服务端仍有更多、
      //    且列表未溢出，自动再拉一页直到溢出或没有更多。
      if (prev?.sessionsLoading == true &&
          next.sessionsLoading == false &&
          (next.sessions.length > (prev?.sessions.length ?? 0)) &&
          next.hasMore &&
          next.sessions.isNotEmpty &&
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(chatControllerProvider.notifier).loadSessions();
        });
      }
      // 2) 实时同步历史（新增）：当前会话 id 变化（新建 / 切换到别的会话 /
      //    流式首帧回填 chatSessionId）时，自动刷新列表，让抽屉立刻反映最新
      //    数据，无需手动下拉。
      final prevId = prev?.sessionId;
      final nextId = next.sessionId;
      if (prevId != nextId && nextId != null && nextId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _safeRefresh();
        });
      }
    });
    // 首次进入抽屉默认拉取一次历史会话
    Future.microtask(() => _safeRefresh());
    // 注册生命周期监听：App 从后台 / 窗口失焦重新回到前台时，自动拉一次
    // 最新历史（桌面端常驻抽屉只 mount 一次，这条是"实时看到新数据"的关键兜底）。
    WidgetsBinding.instance.addObserver(this);
    // 多端实时同步：周期性静默轮询历史列表，让其他设备新建的会话在本端自动
    // 出现。轮询走 pollSessions（无 loading 圈、无变化不刷新 UI，不闪烁）。
    _pollTimer = Timer.periodic(_pollInterval, (_) => _safePoll());
  }

  /// 安全刷新历史列表（mounted 守卫，避免异步回调里 setState 报错）。
  void _safeRefresh() {
    if (!mounted) return;
    ref.read(chatControllerProvider.notifier).loadSessions(refresh: true);
  }

  /// 静默轮询（无 loading 圈、无变化不刷新 UI）：用于多端实时同步。
  void _safePoll() {
    if (!mounted) return;
    ref.read(chatControllerProvider.notifier).pollSessions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台 / 窗口重新聚焦：立即拉一次最新历史，并恢复轮询。
      _safeRefresh();
      _pollTimer ??= Timer.periodic(_pollInterval, (_) => _safePoll());
    } else if (state == AppLifecycleState.paused) {
      // 切到后台：暂停轮询，省流量。
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _snapController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- 千问式下拉刷新（基于 ListView 顶部越界 overscroll 驱动） ----------
  // 旧实现只在顶部 80px 盖了一层 GestureDetector，而那块几乎被「新建对话」按钮占满，
  // 其余区域是 ListView 自己滚动消费了手势，所以从列表里拖完全抓不到 → 下滑没反应。
  // 改为监听 ScrollNotification：在列表顶部继续向下拖（overscroll < 0）时，把整抽屉
  // 跟手指下移；松手（ScrollEndNotification）时判断是否过阈值触发刷新并 snap-back。

  bool _handleScroll(ScrollNotification n) {
    if (n is OverscrollNotification) {
      // 顶部下拉越界：overscroll < 0（手指拉到顶部之上）
      if (n.overscroll < 0 && _scrollController.position.pixels <= 0) {
        setState(() {
          _dragDy = (_dragDy + (-n.overscroll) * 0.5).clamp(0.0, _maxDist);
          _pulling = true;
        });
      }
    } else if (n is ScrollEndNotification) {
      // 仅在发生过下拉时才处理 snap-back / 刷新
      if (_pulling) _onRelease();
    }
    return false; // 不消费事件，保留 ListView 自身滚动
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final chat = ref.read(chatControllerProvider);
    // 内容可滚动且接近底部：客户端虚拟分页：把"下一批 +kHistoryPageSize"
    // 渲染到历史列表（不依赖后端分页）。
    // 阈值放到 300px：让"快滚到底时"提前触发，避免手抖停在 90px 位置时
    // 用户没意识到已经在自动加载；同时 `_historyLoadingMore` 互斥防抖。
    final reachedBottom = pos.maxScrollExtent > 0 &&
        pos.pixels >= pos.maxScrollExtent - 300;
    if (!reachedBottom) return;
    if (chat.sessions.isEmpty) return;

    // 路径 A：客户端还有未渲染的（_historyShown < sessions.length）
    //   —— 直接 +pageSize 渲染更多。
    // 路径 B：客户端已渲染完，聊天状态里还有 hasMore=true —— 触发后端翻页。
    // 路径 C：都没了 —— footer "已全部加载" 自然显示，无需处理。
    if (_historyShown < chat.sessions.length) {
      if (_historyLoadingMore) return;
      setState(() => _historyLoadingMore = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _historyShown =
              (_historyShown + kHistoryPageSize).clamp(0, chat.sessions.length);
          _historyLoadingMore = false;
        });
      });
      return;
    }

    // 客户端已渲染完；尝试后端翻页。
    if (chat.hasMore && !chat.sessionsLoading) {
      ref.read(chatControllerProvider.notifier).loadSessions();
    }
  }

  void _onRelease() {
    if (!_pulling) return;
    _pulling = false;

    // 拉到阈值：触发刷新（provider 会把 sessionsLoading 置为 true）
    if (_dragDy >= _triggerDist) {
      ref.read(chatControllerProvider.notifier).loadSessions(refresh: true);
    }

    // 不论是否触发，都 snap-back 到原位（刷新在后台跑，顶部 loading 圈继续显示）
    _snapStart = _dragDy;
    _snapController.forward(from: 0);
  }

  void _onSnapTick() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_snapController.value);
    setState(() {
      _dragDy = _snapStart * (1.0 - t);
    });
  }

  /// 抽屉内的导航跳转：从抽屉底部入口跳到 /me 等全屏页面时，**不要**主动 pop。
  ///
  /// ## 旧实现的坑（已修）
  ///
  /// 旧代码：
  /// ```dart
  /// if (!widget.embedded) Navigator.pop(context);  // ← 这行
  /// ```
  ///
  /// 看起来像是"关闭 drawer"，但实际上 `Navigator.pop(context)` 找的是 **最近的
  /// NavigatorScope 祖先**——也就是 rootNavigator（Material 自带的）。
  /// 直接从 rootNavigator 的栈顶弹走，**会顺手把当前页面（比如正在呈现的 MeScreen
  /// 或 ChatScreen）误关掉**——这就是用户反馈的"从抽屉底部进入个人中心、退出登录时
  /// 点击取消没反应"的根因之一。
  ///
  /// 抽屉本身就是 Flutter `Drawer` widget，由 Scaffold 内部控制动画；
  /// 想关抽屉应该找该 Scaffold（不是 rootNavigator）。**这里只负责路由器跳转，**
  /// 抽屉的开关交由用户下次手动操作：
  ///
  /// - 进入 /me 等全屏覆盖页 → me_screen 视觉上覆盖整个屏幕（包括抽屉区域）；
  /// - 用户点 ← 返回 /chat 时 → drawer 仍然保留在原来的 state（包括打开状态），
  ///   而不是被无声销毁后再开。
  ///
  /// 注意：drawer 自身的状态切换（打开 / 关闭）由 Scaffold 在用户滑动手势 /
  /// 点击顶栏 drawer 按钮时驱动，与此函数无关。
  /// 抽屉内的跳转统一入口。
  ///
  /// - [closeDrawer]：true 时在跳转前收起左侧抽屉（替代之前误用的
  ///   `Navigator.pop`，pop 会弹掉 rootNavigator 栈顶的 ChatScreen 而非关抽屉）。
  ///   仅"历史对话 / 开启新对话 / 智能问答"需要关抽屉；"个人中心"保持不关
  ///   （之前的修复：进入 /me 返回时抽屉应保留）。
  void _nav(String path, {bool push = false, bool closeDrawer = false}) {
    // embedded（桌面端常驻侧栏）模式下 SideDrawer 直接挂在 MainShell 的
    // Row 下，外层没有 Scaffold.drawer——`Scaffold.of(context)` 会抛
    // "no Scaffold" 异常并中断后续路由跳转（桌面端点击无反应的根因）。
    // 因此只有非 embedded（移动端 overlay 抽屉）才关抽屉。
    if (closeDrawer && !widget.embedded) Scaffold.of(context).closeDrawer();
    // 跳转前先释放抽屉内搜索框焦点，避免焦点被新页面（聊天输入框）继承、键盘自动弹出
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    if (push) {
      router.push(path);
    } else {
      router.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final auth = ref.watch(authControllerProvider);
    final mq = MediaQuery.of(context);

    // loading 圈显示条件：刷新中 或 下拉到一定距离
    final showLoading = chat.sessionsLoading || (_pulling && _dragDy > 16);

    final drawerContent = Stack(
      children: [
        // 抽屉整体跟手指下移；顶部 80px 手势触发区放在 inner Stack 里覆盖 ListView
        Transform.translate(
          offset: Offset(0, _dragDy),
          child: SafeArea(
            child: Column(
              children: [
                // 头部固定（不随历史列表滚动）：搜索模式 = iOS 风圆角胶囊+取消；
                // 普通模式 = logo+搜索 icon。移出 ListView 后，滑历史时顶部不再被带走。
                if (_searching)
                  _buildSearchHeader()
                else
                  _buildDrawerHeader(),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScroll,
                    child: ListView(
                      controller: _scrollController,
                      // AlwaysScrollableScrollPhysics：即便内容没溢出也允许顶部 overscroll，
                      // 保证短列表下拉刷新同样能触发
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        // body：搜索模式 = 匹配结果；普通模式 = 新建对话 + 功能项 + 历史列表
                        if (!_searching) ...[
                          _buildNewChat(),
                          _buildFeatures(selectedModel),
                          _buildHistory(chat),
                        ] else
                          _buildSearchResults(chat),
                      ],
                    ),
                  ),
                ),
                _buildAccountEntry(auth),
              ],
            ),
          ),
        ),
        if (showLoading)
          Positioned(
            top: mq.padding.top + 8,
            left: 0,
            right: 0,
            height: 28,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
      ],
    );

    // 桌面端宽屏：常驻左侧栏（不遮罩），固定宽 300；点击导航由 _nav 处理，不再 pop。
    // 注意：原 Drawer 隐式提供 Material 祖先，去掉 Drawer 后必须自己包一层 Material，
    // 否则下面的 InkWell / ListTile 都会报 "No Material widget found"。
    if (widget.embedded) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(width: 300, child: drawerContent),
      );
    }

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // 抽屉宽度：移动端按屏宽 78%，桌面/平板上限 300（参考 DeepSeek 的紧凑窄抽屉）。
      // 上限避免宽屏（1920+）下抽屉被拉成 ~1497 的巨宽，列表行也跟着过宽不好读。
      width: () {
        final w = mq.size.width * 0.78;
        return w > 300 ? 300.0 : w;
      }(),
      child: drawerContent,
    );
  }

  /// 抽屉头部：左侧品牌 logo + 右侧搜索图标按钮（DeepSeek 风格）。
  ///
  /// 不是胶囊搜索框而是 36×36 圆形浅灰底图标按钮：点击后关抽屉并
  /// `push SessionSearchScreen`（全屏搜索页）。
  /// 整 header 行高 44，便于与下面的"新建对话"主按钮视觉上拉开。
  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 26,
            child: Image.asset(
              'assets/title.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          const Spacer(),
          // 搜索图标按钮：圆形 36×36 浅灰底，水波纹，hover/press 时颜色变深
          InkWell(
            onTap: _enterSearchMode,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6F8),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: TopBarIcons.search(
                size: 18,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 进入抽屉内嵌的「搜索模式」：抽屉保持打开（不 pop），
/// 整抽屉切到 iOS 风搜索视图（顶栏 = 圆角胶囊+取消，body = 匹配结果）。
  ///
  /// 为什么不在这里 push 全屏搜索页：
  /// `Navigator.push` 通常要先去 pop 抽屉（否则路由栈会很怪），
  /// 会造成"点搜索 → 抽屉突然关上 → 闪一个全屏页"的体验割裂。
  /// 内嵌到抽屉里一气呵成，且天然满足"取消不关抽屉"的诉求
  /// —— 我们全程没动过抽屉的开关状态。
  void _enterSearchMode() {
    setState(() => _searching = true);
    // 等下一帧渲染完成后再聚焦搜索框、弹起键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  /// 退出搜索模式：清空查询 + 取消聚焦，恢复常规抽屉视图。
  /// 整个过程**不动 `Navigator`**：取消只是状态切换，不会"关闭抽屉"。
  void _exitSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searching = false;
      _searchQuery = '';
    });
  }

  /// 抽屉内嵌搜索视图的顶部（iOS 风）：
  /// 左侧圆角胶囊搜索框（带放大镜 + hint "搜索对话内容"，有内容时显示 × 清空）；
  /// 右侧「取消」文本按钮，点击调 _exitSearch 退出搜索模式（不动 Navigator）。
  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECEEF1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '搜索对话内容',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.cancel,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 「取消」按钮：紧凑、无内边距撑开，跟搜索框等高（36），
          // tapTargetSize 收紧避免高度超出搜索框。
          TextButton(
            onPressed: _exitSearch,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('取消', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// 搜索模式 body：实时按标题（不区分大小写）过滤历史，仍按今天/更早分组；
  /// 复用 `_sessionTile` 与 `_groupLabel`，视觉与 `_buildHistory` 一致；
  /// 选中态（当前会话）会保留 primarySoft 高亮。
  Widget _buildSearchResults(ChatState chat) {
    final query = _searchQuery.trim().toLowerCase();
    final sessions = query.isEmpty
        ? chat.sessions
        : chat.sessions
            .where((s) => s.title.toLowerCase().contains(query))
            .toList();

    final today = <SessionSummary>[];
    final earlier = <SessionSummary>[];
    final now = DateTime.now();
    for (final s in sessions) {
      final t = _parseTime(s.createTime);
      if (t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day) {
        today.add(s);
      } else {
        earlier.add(s);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Center(
              child: Text(
                '没有匹配的对话',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        if (today.isNotEmpty) ...[
          _groupLabel('今天'),
          ...today.map(
            (s) => _sessionTile(s, selected: s.sessionId == chat.sessionId),
          ),
        ],
        if (earlier.isNotEmpty) ...[
          _groupLabel('更早'),
          ...earlier.map(
            (s) => _sessionTile(s, selected: s.sessionId == chat.sessionId),
          ),
        ],
      ],
    );
  }

  Widget _buildNewChat() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: SizedBox(
        height: 42,
        // 参考 DeepSeek：浅灰圆角胶囊 + 圆圈加号图标 + 深色文字"开启新对话"，内容水平居中。
        // 不用蓝色描边（旧版千问风），改用中性浅灰底，hover/press 由 OutlinedButton 自动加深。
        child: OutlinedButton.icon(
          onPressed: () {
            // 关抽屉前先释放搜索框焦点，避免键盘被聊天输入框继承
            _searchFocusNode.unfocus();
            FocusScope.of(context).unfocus();
            // 收起左侧抽屉（用 Scaffold.closeDrawer，而非 Navigator.pop——
            // pop 会误弹 rootNavigator 栈顶的 ChatScreen）。
            // embedded（桌面常驻侧栏）无 Scaffold.drawer，跳过避免抛异常。
            if (!widget.embedded) Scaffold.of(context).closeDrawer();
            final router = GoRouter.of(context);
            router.go('/chat');
            ref.read(chatControllerProvider.notifier).newChat();
          },
          icon: TopBarIcons.newChat(
            size: 16,
            color: AppColors.textPrimary,
          ),
          label: const Text('开启新对话'),
          style: OutlinedButton.styleFrom(
            // 关键：Drawer 背景是 0xFFF4F4F6（浅灰），按钮若用更浅的灰就没框感。
            // 这里用「比背景更深的浅灰填充 + 比填充更深的 1px 描边」，
            // 让按钮在浅灰抽屉上明显浮出来（对应 DeepSeek 浅灰底+细边框的「开启新对话」）。
            backgroundColor: const Color(0xFFECEEF1),
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: Color(0xFFDDE1E6), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatures(ChatModel? selectedModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _featureTile(
          icon: Icons.chat_bubble_outline,
          label: '智能问答',
          onTap: () => _nav('/chat', closeDrawer: true),
        ),
        _featureTile(
          icon: Icons.smart_toy_outlined,
          label: '智能体',
          onTap: () => _nav('/agents'),
        ),
        _featureTile(
          icon: Icons.menu_book_outlined,
          label: '知识库',
          onTap: () => _nav('/knowledge'),
        ),
        _featureTile(
          icon: Icons.tune_outlined,
          label: '模型选择',
          trailing: selectedModel?.name,
          onTap: () {
            // 千问风：底部弹出模型面板，左侧抽屉保持打开。
            // ModelSheet 自身会在首次打开且未加载时实时拉取。
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const ModelSheet(),
            );
          },
        ),
      ],
    );
  }

  /// 抽屉底部的「个人中心」入口：圆形头像（取 [AuthState.displayName] 首字）+
  /// 昵称 + 设置图标（[assets/icons/settings.svg]），整行可点击。
  /// 桌面端（embedded = true）走 master-detail：直接 anchor 到账号管理；
  /// 移动端 [MeScreen] 全屏 push 转场。
  Widget _buildAccountEntry(AuthState auth) {
    final scheme = Theme.of(context).colorScheme;
    final name = auth.displayName.isEmpty ? '未登录' : auth.displayName;
    final initial = name.characters.first;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: () {
          if (isDesktop(context)) {
            // 桌面端：仿 WorkBuddy 弹出"设置"弹层（左侧 11 个分类 + 右侧内容）。
            // 抽屉自身在弹层显示期间保持打开（不是路由跳转），关掉弹层即退出，
            // 最大化减少界面跳转带来的"重置感"。
            SettingsDialog.show(context);
          } else {
            // 移动端：全屏 push 个人中心（MeScreen），不再弹桌面 720px 弹窗，
            // 杜绝「桌面布局泄漏到 APP 端」。
            _nav('/me', push: true);
          }
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 圆形头像：取 displayName 首字（无网络依赖，离线/无头像也好看）。
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 工具栏风格：单色灰调 SVG（用 ColorFiltered 把原色统一到 onSurfaceVariant），
              // 与 ListTile 视觉对齐；"设置"二字放进 Tooltip，节省横向空间。
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  scheme.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
                child: SvgPicture.asset(
                  'assets/icons/settings.svg',
                  width: 20,
                  height: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(ChatState chat) {
    // 排序在 provider 提交前完成（_sortSessions：去重 + createTime 倒序 + sessionId 兜底 + title 兜底），
    // 这里直接消费 state.sessions，不再二次排序，避免双重排序逻辑不一致导致乱序。
    // 客户端虚拟分页：只渲染前 [_historyShown] 条（详情见 [_onScroll]）。
    final sessions = chat.sessions;
    final visible = sessions.take(_historyShown).toList();
    final hasMoreLocal = sessions.length > _historyShown;

    final today = <SessionSummary>[];
    final earlier = <SessionSummary>[];
    final now = DateTime.now();

    for (final session in visible) {
      final time = _parseTime(session.createTime);
      if (time != null &&
          time.year == now.year &&
          time.month == now.month &&
          time.day == now.day) {
        today.add(session);
      } else {
        earlier.add(session);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            '历史对话',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '暂无历史对话',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
        if (today.isNotEmpty) ...[
          _groupLabel('今天'),
          ...today.map(
            (s) => _sessionTile(s, selected: s.sessionId == chat.sessionId),
          ),
        ],
        if (earlier.isNotEmpty) ...[
          _groupLabel('更早'),
          ...earlier.map(
            (s) => _sessionTile(s, selected: s.sessionId == chat.sessionId),
          ),
        ],
        // 自动滚动到底部时由 [_onScroll] 客户端虚拟分页；这里不再展示
        // 「加载更多」按钮（已隐藏），仅在没有更多时显示一个轻量 footer。
        if (_historyLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          )
        else if (!hasMoreLocal && sessions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                '— 已全部加载 · 共 ${sessions.length} 条 —',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _sessionTile(SessionSummary session, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      // 当前正在查看的会话：标题着色 + 轻量高亮背景（刷新后 sessionId 不变，高亮保留）
      tileColor: selected ? AppColors.primarySoft : null,
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          color: selected ? scheme.primary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () {
        // 切换到该历史会话并路由回 /chat。
        // 点击历史对话要收起抽屉：用 Scaffold.closeDrawer（不是 Navigator.pop——
        // pop 会误弹 rootNavigator 栈顶的 ChatScreen，导致返回后栈不一致）。
        // embedded（桌面常驻侧栏）无 Scaffold.drawer，跳过避免抛异常。
        _searchFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        if (!widget.embedded) Scaffold.of(context).closeDrawer();
        ref.read(chatControllerProvider.notifier).openSession(session.sessionId);
        GoRouter.of(context).go('/chat');
      },
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      // 收紧 icon ↔ 文字 间距（默认 16 显得太散；DeepSeek 行内 icon 与文字几乎贴在一起）
      horizontalTitleGap: 10,
      // leading 强制最少占 0，避免被 ListTile 自动撑到 40 让真实 icon 显得很挤
      minLeadingWidth: 0,
      leading: Icon(icon, size: 19, color: scheme.onSurface),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: scheme.onSurface),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 16, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }

  static DateTime? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    // 后端（Java/Spring）常把时间以毫秒时间戳 Long 返回，dart fromJson 已 toString()，
    // 需单独处理，否则 DateTime.parse 失败 → 排序全部失效 → 列表乱序。
    final millis = int.tryParse(value);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    try {
      return DateTime.parse(value.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }
}
