import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/widgets/quick_entry.dart';

/// 智能问答输入区「快捷工具胶囊」列表。
///
/// 设计稿（铁骥原型_设计稿.html · 智能问答输入区）中，这一行胶囊是
/// **由后端「AI工具列表」动态下发**的（示例：智能体 / AI生图 / 拍图答疑 / AI搜索）。
///
/// 当前对接文档（铁骥大模型_移动端接口对接文档.md）**未收录**该 list 接口
/// （仅有 `/ai-tool/*` 提示词类与 `/system/module/getRouteList` 账号可见模块），
/// 为避免瞎猜端点导致 404 刷屏，这里先按设计稿示例固定 4 个入口。
///
/// ★ 接入真实列表时：把下面这个 Provider 改为调用后端接口
///   （建议 `GET /ai/chat/quickTools` 之类，需与后端确认路径/字段），
///   将返回数据映射为 [QuickEntry] 即可，UI 层无需改动。
final quickEntriesProvider = Provider<List<QuickEntry>>((ref) => const [
      QuickEntry(
        icon: Icons.smart_toy_outlined,
        label: '智能体',
        route: '/agents',
      ),
      QuickEntry(
        icon: Icons.auto_awesome_outlined,
        label: 'AI生图',
        action: 'image',
      ),
      QuickEntry(
        icon: Icons.camera_alt_outlined,
        label: '拍图答疑',
        action: 'camera',
      ),
      QuickEntry(
        icon: Icons.search_outlined,
        label: 'AI搜索',
        route: '/knowledge/search',
      ),
    ]);
