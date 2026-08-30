import 'package:flutter/material.dart';

/// 智能问答输入区的「快捷工具胶囊」。
///
/// 设计稿中这些入口由后端「AI工具列表」动态下发（智能体 / AI生图 / 拍图答疑 / AI搜索…）。
/// 当前测试环境未提供该 list 接口，详见 [quickEntriesProvider] 的默认实现与接入说明。
class QuickEntry {
  const QuickEntry({
    required this.icon,
    required this.label,
    this.route,
    this.action,
  });

  final IconData icon;
  final String label;

  /// 点击后推送的路由（如 '/agents'、'/knowledge/search'）。
  final String? route;

  /// 本地动作标识：'image' = 图片生图、'camera' = 拍图答疑（需移动端摄像头）。
  /// 有 [action] 无 [route] 时，点击打开附件选择流程。
  final String? action;
}
