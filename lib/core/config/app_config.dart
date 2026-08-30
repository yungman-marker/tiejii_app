/// 全局配置。
///
/// 运行环境可用 `--dart-define=API_BASE=https://<生产域名>/backendapi` 覆盖，
/// 无需改代码即可在测试 / 生产之间切换。
class AppConfig {
  const AppConfig._();

  /// 后端网关地址（与《移动端接口对接文档》一致）。
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue:
        'http://kygl-crcc-tj-ai-front-vue.test.cdcgy-gw.com/backendapi',
  );

  /// 企业标识（中国铁建 = crcc），来自前端登录表单默认值。
  static const String enterpriseName = 'crcc';

  /// 客户端类型：移动端必须传 MOBILE，PC 端为 PC。
  static const String clientType = 'MOBILE';

  static const Duration requestTimeout = Duration(seconds: 60);
  static const Duration streamTimeout = Duration(seconds: 120);

  /// 账号体系来源（登录接口要求）。
  static const String loginSource = 'jg';
}
