# 铁骥大模型 · 移动端 / 桌面端客户端（Flutter 原生）

按**正式企业级应用**标准开发，真实对接后端 `/backendapi` 接口，
交互与视觉对齐千问 / DeepSeek。

---

## 一、技术选型与理由

| 维度 | 选型 | 说明 |
|---|---|---|
| 框架 | **Flutter 3.29（Dart 3）** | 编译为原生机器码 + Skia 原生渲染，**无 WebView、无 JS Bridge**；一套代码覆盖 iOS / Android / Windows / macOS / Linux |
| 状态管理 | Riverpod 2 | 编译期安全、可测试，适合企业级分层 |
| 路由 | go_router | 声明式路由 + 登录守卫 |
| 网络 | http | REST 请求 + SSE 流式读取 |
| 加密 | pointycastle | RSA / PKCS#1 v1.5，与服务端 `PKCS1_v1_5` 完全一致 |
| 本地存储 | shared_preferences | 仅缓存 JWT，**不保存明文密码** |

**为什么必须是 Flutter（原生）而非 WebView 方案：**

作业明确要求「原生 APP」。此前评估过的 Capacitor / WebView 方案属于**混合应用**，
在手势、键盘、滚动惯性、触摸反馈、低端机性能上与原生存在差距，不满足要求。
Flutter 编译为原生代码、原生渲染，可达到与千问 / DeepSeek 相同的流畅度
（60fps 流式打字、原生手势与导航）。

---

## 二、目录结构

```
lib/
├── main.dart                     入口（恢复本地 JWT）
├── app.dart                      MaterialApp.router + 主题
├── core/
│   ├── config/app_config.dart    基站址 / 企业标识 / 客户端类型
│   ├── network/api_client.dart   统一响应拦截 + 401 自动续期
│   ├── network/sse.dart          SSE 流式客户端（增量帧 / 停止 / 心跳）
│   ├── crypto/rsa_util.dart      RSA / PKCS#1 v1.5 加密
│   ├── storage/token_store.dart  JWT 持久化
│   └── theme/app_theme.dart      千问 / DeepSeek 风格设计 token
├── data/
│   ├── models/models.dart        ChatMessage / ChatModel / SessionSummary / UserProfile
│   └── repositories/             auth / chat / model 三个仓库
├── providers/                    Riverpod：auth / chat / model
├── router/app_router.dart        登录守卫路由
└── ui/
    ├── screens/                  login_screen / chat_screen
    └── widgets/                  brand_logo / chat_bubble / chat_input_bar / side_drawer / model_sheet
```

---

## 三、运行方式

### 1. 下载并安装 Flutter SDK

当前稳定版：**3.47.2**（约 1.8 GB）。三选一，国内推荐前两个镜像：

| 来源 | 地址 |
|---|---|
| **Flutter 中国镜像（推荐）** | https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip |
| 腾讯云镜像 | https://mirrors.cloud.tencent.com/flutter/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip |
| 官方（需外网） | https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip |

> 建议用下载工具（迅雷 / IDM / Motrix）下载，浏览器直下 1.8GB 容易中断。

**解压位置**：必须避免中文与空格路径（Gradle 易报错），推荐解压到：

```
D:\flutter\          → 得到 D:\flutter\flutter\bin\flutter.bat
```

### 2. 配置环境变量（国内必须，否则后续会非常慢）

在「用户变量」中新增两项：

```
PUB_HOSTED_URL           = https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL = https://storage.flutter-io.cn
```

PATH 追加一条：`D:\flutter\flutter\bin`

### 3. 验证（首次运行会自动下载 Dart SDK，走上面配的镜像）

```bash
flutter doctor
```

按提示补齐缺失项：

- **Windows 桌面端**：Visual Studio 2022（勾选「使用 C++ 的桌面开发」）
- **Android**：Android Studio + Android SDK
- **iOS**：需 macOS + Xcode

### 4. 生成平台目录（首次）

工程只提交了 `lib/` 与配置，首次需生成各平台原生壳目录
（`--project-name` 需与 pubspec 的 `name` 一致，不会覆盖 `lib/`）：

```bash
cd tiejii_app
flutter create --platforms=android,ios,windows --project-name tiejii_app .
```

### 5. 安装依赖并运行

```bash
flutter pub get

# 桌面端（Windows）
flutter run -d windows

# 移动端
flutter run -d <设备ID>

# 生产环境（覆盖测试基站址）
flutter run --dart-define=API_BASE=https://<生产域名>/backendapi
```

### 6. 打包

```bash
flutter build windows          # 桌面端
flutter build apk --release    # Android
flutter build ipa              # iOS（需 Xcode）
```

---

## 四、真实接口对接对照

| 能力 | 接口 | 实现位置 | 状态 |
|---|---|---|---|
| RSA 公钥 | `GET /auth/publicKey` | `auth_repository.dart` | ✅ 真实 |
| 账号密码登录 | `POST /auth/login` | `auth_repository.dart` | ✅ 真实 |
| 用户信息 | `GET /system/user/getInfo` | `auth_repository.dart` | ✅ 真实 |
| 权限菜单 | `POST /system/chat/role/menu/allPermission` | `auth_repository.dart` | ✅ 真实 |
| **流式对话** | `POST /ai/chat/model/experience:stream` | `sse.dart` + `chat_repository.dart` | ✅ 真实 SSE |
| 模型列表 | `POST /ai/chat/model/list` | `model_repository.dart` | ✅ 真实 |
| 移动端默认模型 | `POST /ai/chat/model/getDefault` | `model_repository.dart` | ✅ 真实 |
| 历史会话（游标分页） | `POST /ai/chat/his/record/list` | `chat_repository.dart` | ✅ 真实 |
| Token 续期 | `POST /refresh-token` | `api_client.dart` | ✅ 自动 |

**占位待后端就绪后补齐：**

- 手机号一键登录（需验证码接口）
- 企业微信 / 铁建通 OAuth（需 `/oauthLogin/*`、`/midPageCrcc` 中转页）
- 附件上传（`/file/upload` 分片 → `/file/upload/merge`）
- 知识库、推送消息、意见反馈、长期记忆（测试环境部分接口未部署）
- 个人中心 / 设置子页

---

## 五、测试环境注意事项（重要）

当前基站址为 **HTTP（非 HTTPS）** 且域名含 `.test`，上线前需处理：

1. **Android**：`android/app/src/main/AndroidManifest.xml` 的 `<application>` 增加
   `android:usesCleartextTraffic="true"`
2. **iOS**：`ios/Runner/Info.plist` 配置 `NSAppTransportSecurity` 放行该域名
   （生产环境切 HTTPS 后应移除例外）
3. **桌面端**：无此限制
4. 生产部署时用 `--dart-define=API_BASE=https://<生产域名>/backendapi` 覆盖，
   **无需改动代码**

---

## 六、已实现的千问 / DeepSeek 交互

- 流式打字机（`ANSWER_DELTA` 增量追加，自动滚到底）
- **停止生成**（取消 SSE 订阅）
- 思考过程展示 / 排队态提示
- 重新生成、复制
- 空态大字 + 快捷提问（千问风）
- 左滑抽屉：新建对话 / AI工具 / 个人中心 / 智能体 / 知识库 / 模型选择 / 历史对话（今天·更早）
- 历史会话**游标分页**加载更多
- 模型切换面板（标注「计费 / 思考 / 图片」能力）
- 依 `supportThinking` 与 `inputModel` 控制思考开关与图片入口显隐
