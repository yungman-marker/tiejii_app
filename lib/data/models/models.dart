// 领域模型：字段结构与《移动端接口对接文档》完全对齐。

import 'dart:developer' as developer;

/// 后端字段名试探不到的诊断包（控制台输出 + UI 兜底文案）。
/// - 模块：knowledge_file_field_mismatch
/// - 触发：KnowledgeFile.fromJson 走到 name 兜底（"未命名文件"）。
/// - 内容：原始 JSON + keys 列表（按出现顺序），方便后续人工或自动扩展。
void _logUnknownNameField(Object raw) {
  try {
    if (raw is Map<String, dynamic>) {
      final keys = raw.keys.toList();
      developer.log(
        'KnowledgeFile 从后端解析时未命中 name 兜底链，原始 JSON keys=$keys；\n'
        '完整数据=$raw',
        name: 'knowledge_file_field_mismatch',
      );
    }
  } catch (_) {
    /* log 失败不影响主流程 */
  }
}

/// 把诊断 keys 拼成短串，给 UI「副标题」做兜底展示用。
///   keys=[fileType, fileSize, updateTime, createTime, ...]
String _formatKeysForDebug(Object raw) {
  if (raw is! Map<String, dynamic>) return '';
  final keys = raw.keys.toList();
  return keys.join(', ');
}

enum ChatRole { user, assistant }

enum MessageStatus { sending, streaming, done, failed }

/// 单条对话消息。
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thinking,
    this.status = MessageStatus.done,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final ChatRole role;

  /// 正文（流式过程中逐帧追加）
  String content;

  /// 思考过程（thinkEnable 为真时由服务端下发）
  String? thinking;

  MessageStatus status;
  final DateTime createdAt;

  bool get isUser => role == ChatRole.user;

  Map<String, String> toRequestJson() => {
        'role': isUser ? 'user' : 'assistant',
        'content': content,
      };
}

/// 模型（`/ai/chat/model/list`）。
class ChatModel {
  const ChatModel({
    required this.id,
    required this.code,
    required this.name,
    this.feeType = 'free',
    this.inputModel = const [],
    this.supportThinking = false,
    this.thinkingProtocol,
    this.serviceType,
    this.modelIcon,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) => ChatModel(
        id: (json['id'] ?? '').toString(),
        code: (json['chatModelCode'] ?? '').toString(),
        name: (json['name'] ?? json['chatModelCode'] ?? '未命名模型').toString(),
        feeType: (json['feeType'] ?? 'free').toString(),
        inputModel: (json['inputModel'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        supportThinking: json['supportThinking'] == true,
        thinkingProtocol: json['thinkingProtocol']?.toString(),
        serviceType: json['serviceType']?.toString(),
        modelIcon: json['modelIcon']?.toString(),
      );

  final String id;
  final String code;
  final String name;
  final String feeType;
  final List<String> inputModel;
  final bool supportThinking;
  final String? thinkingProtocol;
  final String? serviceType;
  final String? modelIcon;

  /// 是否支持图片输入（控制输入区「+图片」入口显隐）
  bool get supportsImage => inputModel.contains('image');

  bool get isCharge => feeType == 'charge';
}

/// 历史会话条目（`/ai/chat/his/record/list`，游标分页）。
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.title,
    this.createTime,
    this.chatModelId,
    this.chatModelCode,
    this.usedKnowledge = false,
    this.sourceType,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        sessionId: (json['chatSessionId'] ?? '').toString(),
        title: (json['titleName'] ?? '未命名对话').toString(),
        createTime: json['createTime']?.toString(),
        chatModelId: json['chatModelId']?.toString(),
        chatModelCode: json['chatModelCode']?.toString(),
        usedKnowledge: json['usedKnowledge'] == true,
        sourceType: json['sourceType']?.toString(),
      );

  final String sessionId;
  final String title;
  final String? createTime;
  final String? chatModelId;
  final String? chatModelCode;
  final bool usedKnowledge;
  final String? sourceType;
}

/// 用户信息（`/system/user/getInfo`）。
class UserProfile {
  const UserProfile({
    required this.userName,
    this.nickName,
    this.avatar,
    this.enterprise,
    this.roles = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map<String, dynamic> ? rawUser : json;
    return UserProfile(
      userName: (user['userName'] ?? '').toString(),
      nickName: user['nickName']?.toString(),
      avatar: user['avatar']?.toString(),
      enterprise: json['enterprise']?.toString(),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final String userName;
  final String? nickName;
  final String? avatar;
  final String? enterprise;
  final List<String> roles;

  String get displayName =>
      (nickName != null && nickName!.isNotEmpty) ? nickName! : userName;
}

/// ============= 智能体（/ai/chat/agent/center/*） =============

/// 智能中心筛选参数（`GET /ai/chat/agent/center/param`）。
/// 用于动态渲染「智能体模式 / 业务领域 / 状态 / 可见性 / 第三方模式」等下拉。
class AgentCenterParams {
  const AgentCenterParams({
    this.visibilityTypes = const [],
    this.agentModes = const [],
    this.domains = const [],
    this.ownershipTypes = const [],
    this.statuses = const [],
    this.thirdPartyModes = const [],
    this.favoriteCount = 0,
  });

  factory AgentCenterParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AgentCenterParams();
    return AgentCenterParams(
      visibilityTypes: _options(json['visibilityTypes']),
      agentModes: _options(json['agentModes']),
      domains: _options(json['domains']),
      ownershipTypes: _options(json['ownershipTypes']),
      statuses: _options(json['statuses']),
      thirdPartyModes: _options(json['thirdPartyModes']),
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
    );
  }

  final List<LabeledValue> visibilityTypes;
  final List<LabeledValue> agentModes;
  final List<LabeledValue> domains;
  final List<LabeledValue> ownershipTypes;
  final List<LabeledValue> statuses;
  final List<LabeledValue> thirdPartyModes;

  /// 收藏总数（侧边栏「我的收藏」徽标用）。
  final int favoriteCount;

  static List<LabeledValue> _options(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LabeledValue.fromJson)
        .toList(growable: false);
  }
}

/// 通用 `{label, value}` 字典项（筛选下拉选项）。
class LabeledValue {
  const LabeledValue({required this.label, required this.value});
  factory LabeledValue.fromJson(Map<String, dynamic> json) => LabeledValue(
        label: (json['label'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
      );
  final String label;
  final String value;
}

/// 智能体分页结果（`POST /ai/chat/agent/center/page`）。
class AgentPage {
  const AgentPage({required this.items, this.total = 0, this.hasMore = false});
  final List<AgentSkill> items;
  final int total;
  final bool hasMore;
}

/// 单个智能体（技能）。
///
/// 字段名对齐 web 端 `/ai/chat/agent/center/page` 实测响应（2026-08-30）：
///   - id              id
///   - name            agentName（不是 name / skillName）
///   - description     description
///   - icon            icon / avatarUrl（两个字段都返回相同 URL）
///   - tags            tags（数组）
///   - status          "PUBLISHED" | "PENDING_AUDIT" | "PENDING_ONLINE"
///                   | "REJECTED" | "OFFLINE"   ← 字符串，不是布尔
///   - favoriteFlag    true/false             ← 收藏用的是这个，不是 favorite
///   - agentType       "GENERAL" / 其它
///   - agentMode       "DIALOGUE" | "THIRD_PARTY" | ...
///   - thirdPartyMode  "INTERNAL" / "EXTERNAL"（仅 THIRD_PARTY 有）
///   - domainCode      "survey_design" / "construction_production" / ...
///   - visibilityType  "PUBLIC" | "PRIVATE"
///   - recommendFlag   0/1（推荐 tab 过滤）
///   - useCount / userCount / likeCount / liked / disliked  使用与互动数据
///   - thirdPartyUrl   第三方智能体跳转 URL（DIALOGUE 为 null）
///   - canViewDetail / canEdit / canDelete / canPublishNow  权限位
class AgentSkill {
  const AgentSkill({
    required this.id,
    this.name = '',
    this.description = '',
    this.icon,
    this.avatarUrl,
    this.tags = const [],
    this.published = false,
    this.favorite = false,
    this.prompt,
    this.greeting,
    this.useCases = const [],
    this.debugKeys,
    // ↓ 智能中心真实契约补全
    this.agentType,
    this.agentTypeName,
    this.agentMode,
    this.agentModeName,
    this.thirdPartyMode,
    this.thirdPartyModeName,
    this.domainCode,
    this.domainName,
    this.status,
    this.statusName,
    this.visibilityType,
    this.visibilityName,
    this.favoriteFlag = false,
    this.recommendFlag = 0,
    this.recommendSort = 0,
    this.recommendScene,
    this.likeCount = 0,
    this.useCount = 0,
    this.userCount = 0,
    this.liked = false,
    this.disliked = false,
    this.thirdPartyUrl,
    this.canViewDetail = true,
    this.canEdit = false,
    this.canDelete = false,
    this.canPublishNow = false,
    this.createdBy,
    this.createdTime,
    // ↓ 详情/卡片展示字段（联系人、截图、发布等）
    this.contactName,
    this.contactPhone,
    this.contactUnit,
    this.screenshotUrls = const [],
    this.rejectReason,
    this.publishMode,
    this.publishTime,
    this.trialEnabled = false,
    this.publicFlag = 0,
  });

  factory AgentSkill.fromJson(Map<String, dynamic> json) {
    // name 兜底命中时把原始 keys 一并保留，给 UI 诊断展示用。
    final rawName = json['agentName'] ??
        json['name'] ??
        json['skillName'] ??
        json['title'];
    final nameStr = rawName == null ? '' : rawName.toString();
    final fallbackHit = nameStr.isEmpty;
    if (fallbackHit) _logUnknownSkillNameField(json);
    final status = json['status']?.toString();
    return AgentSkill(
      id: (json['id'] ?? json['skillId'] ?? '').toString(),
      name: nameStr,
      description: (json['description'] ?? json['remark'] ?? json['intro'] ?? '')
          .toString(),
      icon: json['icon']?.toString() ?? json['avatarUrl']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['icon']?.toString(),
      tags: _strList(json['tags']),
      // published：实测是字符串 "PUBLISHED"，兼容旧布尔
      published: status == 'PUBLISHED' || json['published'] == true,
      // favorite：实测是 favoriteFlag，兼容旧 favorite
      favorite: json['favoriteFlag'] == true || json['favorite'] == true,
      prompt: json['prompt']?.toString(),
      greeting: json['greeting']?.toString() ?? json['prologue']?.toString(),
      useCases: _strList(json['useCases']) + _strList(json['scenes']),
      debugKeys: fallbackHit ? _formatKeysForDebug(json) : null,
      agentType: json['agentType']?.toString(),
      agentTypeName: json['agentTypeName']?.toString(),
      agentMode: json['agentMode']?.toString(),
      agentModeName: json['agentModeName']?.toString(),
      thirdPartyMode: json['thirdPartyMode']?.toString(),
      thirdPartyModeName: json['thirdPartyModeName']?.toString(),
      domainCode: json['domainCode']?.toString(),
      domainName: json['domainName']?.toString(),
      status: status,
      statusName: json['statusName']?.toString(),
      visibilityType: json['visibilityType']?.toString(),
      visibilityName: json['visibilityName']?.toString(),
      favoriteFlag: json['favoriteFlag'] == true,
      recommendFlag: (json['recommendFlag'] as num?)?.toInt() ?? 0,
      recommendSort: (json['recommendSort'] as num?)?.toInt() ?? 0,
      recommendScene: json['recommendScene']?.toString(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] == true,
      disliked: json['disliked'] == true,
      thirdPartyUrl: json['thirdPartyUrl']?.toString(),
      canViewDetail: json['canViewDetail'] != false,
      canEdit: json['canEdit'] == true,
      canDelete: json['canDelete'] == true,
      canPublishNow: json['canPublishNow'] == true,
      createdBy: json['createdBy']?.toString(),
      createdTime: json['createdTime']?.toString(),
      contactName: json['contactName']?.toString(),
      contactPhone: json['contactPhone']?.toString(),
      contactUnit: json['contactUnit']?.toString(),
      screenshotUrls: _strList(json['screenshotUrls']),
      rejectReason: json['rejectReason']?.toString(),
      publishMode: json['publishMode']?.toString(),
      publishTime: json['publishTime']?.toString(),
      trialEnabled: json['trialEnabled'] == true,
      publicFlag: (json['publicFlag'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String description;
  final String? icon;
  final String? avatarUrl;
  final List<String> tags;
  final bool published;
  final bool favorite;
  final String? prompt;
  final String? greeting;
  final List<String> useCases;

  /// 兜底命中时记录下来的「原始 JSON keys 拼接」，供 UI 诊断展示用。
  final String? debugKeys;

  final String? agentType;
  final String? agentTypeName;
  final String? agentMode;
  final String? agentModeName;
  final String? thirdPartyMode;
  final String? thirdPartyModeName;
  final String? domainCode;
  final String? domainName;
  final String? status;
  final String? statusName;
  final String? visibilityType;
  final String? visibilityName;
  final bool favoriteFlag;
  final int recommendFlag;
  final int recommendSort;
  final String? recommendScene;
  final int likeCount;
  final int useCount;
  final int userCount;
  final bool liked;
  final bool disliked;
  final String? thirdPartyUrl;
  final bool canViewDetail;
  final bool canEdit;
  final bool canDelete;
  final bool canPublishNow;
  final String? createdBy;
  final String? createdTime;

  // ↓ 详情/卡片展示字段（联系人、截图、发布等）
  final String? contactName;
  final String? contactPhone;
  final String? contactUnit;
  final List<String> screenshotUrls;
  final String? rejectReason;
  final String? publishMode;
  final String? publishTime;
  final bool trialEnabled;
  final int publicFlag;

  /// 用作展示图标（优先远程图标，缺省时由 UI 用首字/默认图标兜底）。
  String? get displayIcon => avatarUrl ?? icon;

  /// 第三方智能体（需要跳转外部 URL）
  bool get isThirdParty => agentMode == 'THIRD_PARTY';

  /// 草稿/已驳回/已下线 等不可用状态
  bool get isAvailable => status == 'PUBLISHED' || status == null;

  static List<String> _strList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }
}

/// 智能体 name 字段未命中的诊断日志（独立模块，方便过滤）。
void _logUnknownSkillNameField(Object raw) {
  try {
    if (raw is Map<String, dynamic>) {
      final keys = raw.keys.toList();
      developer.log(
        'AgentSkill 从后端解析时未命中 name 兜底链，原始 JSON keys=$keys；\n'
        '完整数据=$raw',
        name: 'agent_skill_field_mismatch',
      );
    }
  } catch (_) {
    /* log 失败不影响主流程 */
  }
}

/// ============= 知识库（/ai/chat/knowledgebase/*） =============

/// 知识库目录树节点（`GET /ai/chat/knowledgebase/file/queryAllDirectoryList`）。
///
/// 真实响应字段（2026-08-30 抓 web 端确认，无参 GET）：
///   id               string  目录 id
///   fileOriginalName string  目录显示名（兜底：name/fileName/originalName/...）
///   parentId         string  父目录 id（"0" = 根级）
///   fullPath         string? 完整路径（type=0 时允许 null）
///   type             int     0=共享/外部 1=个人 2=企业
///   children         array   子节点（递归同构）
class KnowledgeDirectory {
  const KnowledgeDirectory({
    required this.id,
    required this.name,
    this.parentId = '0',
    this.fullPath,
    this.type = 0,
    this.children = const [],
    this.debugKeys,
  });

  factory KnowledgeDirectory.fromJson(Map<String, dynamic> json) {
    // name 兜底链：实测 fileOriginalName 必有，留几个常见异名兜底。
    final name = _firstString(json, const [
      'fileOriginalName', 'name', 'fileName', 'originalName',
      'originalFileName', 'dirName', 'displayName', 'title',
    ]) ?? '';
    // id 兜底链。
    final id = _firstString(json, const [
      'id', 'fileId', 'dirId', 'knowledgeId',
    ]) ?? '';
    // type：实测是数字 0/1/2。
    final typeRaw = json['type'];
    final type = typeRaw is int
        ? typeRaw
        : typeRaw is num
            ? typeRaw.toInt()
            : int.tryParse(typeRaw?.toString() ?? '') ?? 0;
    // children：递归解析。
    final childrenRaw = json['children'];
    final children = childrenRaw is List
        ? childrenRaw
            .whereType<Map<String, dynamic>>()
            .map(KnowledgeDirectory.fromJson)
            .toList(growable: false)
        : const <KnowledgeDirectory>[];
    return KnowledgeDirectory(
      id: id,
      name: name,
      parentId: json['parentId']?.toString() ?? '0',
      fullPath: json['fullPath']?.toString(),
      type: type,
      children: children,
      debugKeys: name.isEmpty ? _formatKeysForDebug(json) : null,
    );
  }

  final String id;
  final String name;
  final String parentId;
  final String? fullPath;
  final int type;
  final List<KnowledgeDirectory> children;

  /// name 兜底命中时记录原始 JSON keys，给 UI 副标题做诊断展示。
  final String? debugKeys;

  bool get hasChildren => children.isNotEmpty;

  /// 把 [KnowledgeDirectory] 拍平成带深度信息的列表，
  /// 仅展开 [expanded] 集合里出现的节点，方便 UI 用 Padding 控制缩进。
  List<({KnowledgeDirectory node, int depth})> flatten(Set<String> expanded) {
    final out = <({KnowledgeDirectory node, int depth})>[];
    void walk(KnowledgeDirectory d, int depth) {
      out.add((node: d, depth: depth));
      if (expanded.contains(d.id)) {
        for (final c in d.children) {
          walk(c, depth + 1);
        }
      }
    }
    for (final root in this.children) {
      walk(root, 0);
    }
    return out;
  }
}

/// 知识库文件（`POST /ai/chat/knowledgebase/file/list` 真实字段）。
///
/// 列表页（S5 知识库管理）点进某个目录后拉取本类型；智能搜索来源列表
/// （searchPage）也复用本类。真实响应（2026-08-30 抓 web 端确认）：
///   id               string  文件 id
///   fileOriginalName string  文件名（含扩展名）
///   fileType         string  "pdf" / "docx" / "xlsx" ...（即扩展名）
///   path             string  预览 URL（getMinioUrl，完整地址，可直接打开）
///   fileSize         int     字节数
///   fileSecretLevel  int     密级（5 等）
///   handleStatus     int     1=已入库处理成功；0/null=处理中/未处理
///   handleMsg        string  处理详情（JSON 串，含 md5/ragId）
///   isShared         dynamic 是否共享
///   createTime       string  创建时间
///   documentNo       string? 文号
///   updatedTime      string  更新时间
///   parentId         string  所属目录 id
///   sort             int     排序
///   labelList        array   标签
class KnowledgeFile {
  const KnowledgeFile({
    required this.id,
    required this.name,
    required this.ext,
    this.fileUrl,
    this.fileSizeBytes = 0,
    this.secretLevel = 0,
    this.handleStatus = 0,
    this.handleMsg,
    this.isShared,
    this.createTime,
    this.documentNo,
    this.updateTime,
    this.type,
    this.sort = 0,
    this.labelList = const [],
    this.debugKeys,
  });

  factory KnowledgeFile.fromJson(Map<String, dynamic> json) {
    // 防御式兜底链：覆盖项目里实际见过的字段命名 + 业务常见异名。
    // 真实接口（file/list / searchPage）第一优先 fileOriginalName。
    final name = _firstString(json, const [
      'fileOriginalName', 'name', 'fileName', 'fileNameReal', 'displayName',
      'originalName', 'originalFileName', 'documentName', 'docName',
      'dirName', 'realName', 'title', 'filename', 'sourceName',
      'knowledgeFileName', 'docFileName', 'sourceFileName',
      'attachmentName', 'attachmentFileName', 'originName', 'originFileName',
      'documentTitle', 'fileTitle', 'original_filename', 'file_name',
    ]);
    final fallbackHit = name == null;
    if (fallbackHit) _logUnknownNameField(json);
    return KnowledgeFile(
      id: (json['id'] ?? json['fileId'] ?? json['dirId'] ?? '').toString(),
      name: name ?? '未命名文件',
      ext: _firstString(json, const ['fileType', 'ext', 'suffix', 'docType']) ?? '',
      fileUrl: json['path']?.toString(),
      fileSizeBytes: json['fileSize'] is num
          ? (json['fileSize'] as num).toInt()
          : int.tryParse(json['fileSize']?.toString() ?? '') ?? 0,
      secretLevel: json['fileSecretLevel'] is num
          ? (json['fileSecretLevel'] as num).toInt()
          : 0,
      handleStatus: json['handleStatus'] is num
          ? (json['handleStatus'] as num).toInt()
          : int.tryParse(json['handleStatus']?.toString() ?? '') ?? 0,
      handleMsg: json['handleMsg']?.toString(),
      isShared: json['isShared'],
      createTime: json['createTime']?.toString(),
      documentNo: json['documentNo']?.toString(),
      updateTime:
          _firstString(json, const ['updatedTime', 'updateTime', 'createTime']) ??
              null,
      type: json['type']?.toString() ?? json['knowledgeType']?.toString(),
      sort: json['sort'] is num ? (json['sort'] as num).toInt() : 0,
      labelList: json['labelList'] is List
          ? (json['labelList'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      // 兜底时把 keys 灌进 debugKeys，给 UI 副标题"原始字段：xxx"做诊断提示
      debugKeys: fallbackHit ? _formatKeysForDebug(json) : null,
    );
  }

  final String id;
  final String name;

  /// 文件扩展名（pdf / docx / xlsx ...）
  final String ext;
  final String? fileUrl;
  final int fileSizeBytes;
  final int secretLevel;
  final int handleStatus;
  final String? handleMsg;
  final dynamic isShared;
  final String? createTime;
  final String? documentNo;
  final String? updateTime;
  final String? type;
  final int sort;
  final List<String> labelList;

  /// 兜底命中时记录下来的「原始 JSON keys 拼接」，供 UI 诊断展示用。
  /// 命中正常时为 null。
  final String? debugKeys;

  String get displayName =>
      ext.isNotEmpty && !name.toLowerCase().endsWith('.$ext') ? '$name.$ext' : name;

  /// 人类可读的文件大小（如 1.9 MB）。
  String get displaySize {
    final b = fileSizeBytes;
    if (b <= 0) return '';
    const kb = 1024, mb = 1024 * 1024;
    if (b >= mb) return '${(b / mb).toStringAsFixed(1)} MB';
    if (b >= kb) return '${(b / kb).toStringAsFixed(1)} KB';
    return '$b B';
  }

  /// 是否已入库处理完成（handleStatus == 1）。
  bool get isHandled => handleStatus == 1;
}

/// 按 [keys] 顺序返回首个「非空字符串」。空串与 null 都算"没有"。
String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return v.toString();
  }
  return null;
}

/// 知识库容量（getCapacity/{dirId}）。
class KnowledgeCapacity {
  const KnowledgeCapacity({
    this.usePercent,
    this.remainPercent,
    this.fileNum,
    this.totalSize,
  });

  factory KnowledgeCapacity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const KnowledgeCapacity();
    return KnowledgeCapacity(
      usePercent: json['usePercent']?.toString() ??
          json['usedPercent']?.toString() ??
          json['usedRatio']?.toString(),
      // 历史 Bug：第 1 版这里把两个 key 都写成 'remainPercent'（同一字段写了两次）
      // → 后端若只返回 remainingPercent / leftPercent 会拿不到值。已扩展兜底链。
      remainPercent: json['remainPercent']?.toString() ??
          json['remainingPercent']?.toString() ??
          json['leftPercent']?.toString() ??
          json['freePercent']?.toString(),
      fileNum: json['fileNum']?.toString() ??
          json['documentCount']?.toString(),
      totalSize:
          json['totalSize']?.toString() ?? json['allSize']?.toString() ?? json['capacity']?.toString(),
    );
  }

  final String? usePercent;
  final String? remainPercent;
  final String? fileNum;
  final String? totalSize;
}

/// 文件分页结果（`searchPage` 共用，仅用于智能搜索来源列表）。
class KnowledgePage {
  const KnowledgePage({
    required this.items,
    this.total = 0,
    this.hasMore = false,
  });

  final List<KnowledgeFile> items;
  final int total;
  final bool hasMore;
}

/// ============= 反馈（/ai/chat/feedback/*） =============

/// 单条反馈（我提交的 / 我的回复）。
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    this.questionType,
    this.content = '',
    this.status,
    this.createTime,
    this.answer,
    this.replyTime,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
        id: (json['id'] ?? '').toString(),
        questionType: json['questionType']?.toString() ??
            json['typeName']?.toString(),
        content: (json['content'] ?? json['question'] ?? '').toString(),
        status: json['status']?.toString() ?? json['statusName']?.toString(),
        createTime: json['createTime']?.toString(),
        answer: json['answer']?.toString() ?? json['replyContent']?.toString(),
        replyTime: json['replyTime']?.toString(),
      );

  final String id;
  final String? questionType;
  final String content;
  final String? status;
  final String? createTime;
  final String? answer;
  final String? replyTime;

  bool get replied => answer != null && answer!.isNotEmpty;
}

/// 反馈下拉选项（querySetting 返回）。
class FeedbackOption {
  const FeedbackOption({required this.code, required this.name});

  factory FeedbackOption.fromJson(Map<String, dynamic> json) => FeedbackOption(
        code: (json['code'] ?? json['value'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? json['label'] ?? json['dictLabel'] ?? '')
            .toString(),
      );

  final String code;
  final String name;
}

/// 反馈设置（问题类型 + 答复方式选项）。
class FeedbackSetting {
  const FeedbackSetting({
    this.questionTypes = const [],
    this.answerTypes = const [],
  });

  final List<FeedbackOption> questionTypes;
  final List<FeedbackOption> answerTypes;
}

/// ============= 智能搜索（S6） =============

/// 搜索命中的知识库来源。
class SearchSource {
  const SearchSource({
    required this.title,
    this.snippet,
    this.fileId,
    this.fileName,
  });

  factory SearchSource.fromJson(Map<String, dynamic> json) => SearchSource(
        title: (json['fileName'] ?? json['title'] ?? '相关文档').toString(),
        snippet: json['snippet']?.toString() ?? json['content']?.toString(),
        fileId: json['fileId']?.toString() ?? json['id']?.toString(),
        fileName: json['fileName']?.toString(),
      );

  final String title;
  final String? snippet;
  final String? fileId;
  final String? fileName;
}

/// 搜索结果：AI 总结 + 来源列表。
class SearchResult {
  const SearchResult({this.summary = '', this.sources = const []});

  final String summary;
  final List<SearchSource> sources;
}
