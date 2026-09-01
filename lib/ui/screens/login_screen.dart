import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// 登录页（浅色科技风：左侧 3D 插画背景 + 右侧白色登录卡）
///
/// 设计参考 ui-ux-pro-max 数据 + 用户提供的实际素材：
/// - 左侧大图直接引用 `assets/login_bg.png`（3D 仪表盘插画原稿）
/// - 顶部 logo 用 `assets/title.png`（铁骥大模型横长品牌标）
/// - 表单走极简 SaaS 风：蓝色实色按钮 + 浅灰输入框 + 胶囊 tab
/// - 登录方式仅保留"账号密码 / 铁建通"两种（与铁建集团内部系统一致）
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _enterpriseController = TextEditingController();

  bool _obscure = true;
  bool _remember = false;
  int _tabIndex = 0; // 0 = 账号密码登录，1 = 铁建通登录

  @override
  void initState() {
    super.initState();
    // 冷启动尝试恢复本地 JWT
    Future.microtask(() => ref.read(authControllerProvider.notifier).restore());
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _enterpriseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isWide = isDesktop(context);

    return Scaffold(
      // 桌面端保留原浅灰底（_Light.bgPage），移动端用 body 同色 #EDF1FC
      // 把整屏（含底部 home indicator 安全区）一起填上，避免安全区
      // 透出黑色窗口背景。桌面端分支完全不动。
      backgroundColor: isWide ? _Light.bgPage : const Color(0xFFEDF1FC),
      body: isWide ? _buildDesktop(auth) : _buildMobile(auth),
    );
  }

  // ---------- 桌面端：背景图全屏铺满 + 表单卡悬浮在右侧 ----------

  Widget _buildDesktop(AuthState auth) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 第 1 层：背景图全屏铺满（BoxFit.cover 居中裁剪，整屏都被填满）
        const _LoginBackground(),
        // 第 2 层：左侧留空让背景图完整可见 + 右侧悬浮白色表单卡
        Row(
          children: [
            const Expanded(flex: 11, child: SizedBox.shrink()),
            Expanded(
              flex: 9,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _FormCard(
                      isWide: true,
                      child: _buildFormColumn(auth),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- 移动端：顶部背景图 + 下方白色卡片 ----------

  Widget _buildMobile(AuthState auth) {
    // 用与图片最底行边缘一致的色 #EDF1FC（采自 login_mobile_top.png 底部两侧 1/3 区域），
    // 把整个 body 容器填成这个色，让图片下沿与下方背景完全无缝衔接，
    // 视觉上看起来「一整张图片作为页面背景」。桌面端 _buildDesktop 不动。
    // 关键：整页（顶部图 + 表单卡）包在同一个 SingleChildScrollView 里，
    // 键盘弹起时二者作为一个整体一起上滑，表单不会被键盘遮挡、顶部图也不会固定不动。
    // （Scaffold 默认 resizeToAvoidBottomInset=true，会自动把 body 高度减去键盘高度，
    // 再由这个滚动容器接管剩余内容的滚动。）
    return Container(
      color: const Color(0xFFEDF1FC),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 移动端顶部图：与桌面端 _LoginBackground 完全解耦。
            // 新素材 assets/login_mobile_top.png 原比例 602×396 ≈ 1.52:1，
            // 用 AspectRatio 自适应屏宽、保持比例渲染；
            // 桌面端代码（_LoginBackground / login_bg.png）完全不变。
            AspectRatio(
              aspectRatio: 602 / 396,
              child: Image.asset(
                'assets/login_mobile_top.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: _FormCard(
                isWide: false,
                child: _buildFormColumn(auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 表单主体 ----------

  Widget _buildFormColumn(AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部品牌 logo（铁骥大模型横长标）
        Center(
          child: Image.asset(
            'assets/title.png',
            width: 280,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        // 标题文案："欢迎登录"做大做蓝做强作主视觉
        const Text(
          '欢迎登录',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _Light.primary,
            letterSpacing: 2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '请选择登录方式',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: _Light.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 22),
        // 登录方式切换（账号密码 / 铁建通）
        _buildTabs(),
        const SizedBox(height: 18),
        // 不同 tab 渲染不同表单
        if (_tabIndex == 0) ..._buildPasswordForm() else ..._buildEnterpriseForm(),
        const SizedBox(height: 6),
        if (_tabIndex == 0) _buildRememberRow(),
        const SizedBox(height: 14),
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              auth.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _Light.danger, fontSize: 13),
            ),
          ),
        _buildSubmitButton(auth.loading, _tabIndex == 0),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: _Light.bgPage,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _TabPill(
            text: '账号密码登录',
            selected: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
          _TabPill(
            text: '铁建通登录',
            selected: _tabIndex == 1,
            onTap: () => setState(() => _tabIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberRow() {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            activeColor: _Light.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: _Light.cardBorder, width: 1.2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '记住我',
          style: TextStyle(fontSize: 13, color: _Light.textSecondary),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _showTip('找回密码功能待联调后开放'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '忘记密码?',
            style: TextStyle(
              fontSize: 13,
              color: _Light.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPasswordForm() {
    return [
      _LightInput(
        controller: _userController,
        hintText: '请输入账号',
        prefixIcon: Icons.person_outline,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      _LightInput(
        controller: _passwordController,
        hintText: '请输入密码',
        prefixIcon: Icons.lock_outline,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitPassword(),
        suffix: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _Light.textTertiary,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    ];
  }

  List<Widget> _buildEnterpriseForm() {
    return [
      // 铁建通简介
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Light.primaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _Light.primarySoft, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined,
                color: _Light.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '使用铁建集团统一身份认证，无需重复注册',
                style: TextStyle(
                  fontSize: 12,
                  color: _Light.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _LightInput(
        controller: _enterpriseController,
        hintText: '请输入铁建通账号',
        prefixIcon: Icons.business_outlined,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitEnterprise(),
      ),
    ];
  }

  Widget _buildSubmitButton(bool loading, bool isPassword) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: loading
            ? null
            : (isPassword ? _submitPassword : _submitEnterprise),
        style: FilledButton.styleFrom(
          backgroundColor: _Light.primary,
          disabledBackgroundColor: _Light.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                isPassword ? '登 录' : '铁建通登录',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
      ),
    );
  }

  Future<void> _submitPassword() async {
    final userName = _userController.text.trim();
    final password = _passwordController.text;
    if (userName.isEmpty || password.isEmpty) {
      _showTip('请输入账号和密码');
      return;
    }

    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .login(userName: userName, password: password);
  }

  Future<void> _submitEnterprise() async {
    final code = _enterpriseController.text.trim();
    if (code.isEmpty) {
      _showTip('请输入铁建通账号');
      return;
    }
    // 铁建通 SSO 真实接入需对接集团 OAuth 平台（cas.crcc.cn / idp.crcc.cn）
    _showTip('铁建通 SSO 中转页待联调（需对接集团统一身份认证）');
  }

  void _showTip(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
  }
}

// =====================================================================
// 登录页背景：直接用素材图铺满（桌面端左半屏 / 移动端顶部）
// =====================================================================

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      // 桌面端左半屏底色兜底：图片加载未完成时显示浅蓝
      color: const Color(0xFFEFF6FF),
      child: Image.asset(
        'assets/login_bg.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        // 加载失败兜底：仍显示浅蓝底色，不破坏整体观感
        errorBuilder: (ctx, err, st) => Container(
          color: const Color(0xFFDBEAFE),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF93C5FD),
            size: 48,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 浅色主题色板（局部常量，避免污染 app_theme.dart 的原色板）
// =====================================================================

class _Light {
  const _Light._();
  static const bgPage = Color(0xFFF8FAFC); // slate-50
  static const cardBg = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE2E8F0); // slate-200
  static const inputFill = Color(0xFFF8FAFC);
  static const inputBorder = Color(0xFFE2E8F0);

  static const textPrimary = Color(0xFF1E293B); // slate-800
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textTertiary = Color(0xFF94A3B8); // slate-400

  static const primary = Color(0xFF3B82F6); // blue-500
  static const primaryLight = Color(0xFFEFF6FF); // blue-50
  static const primarySoft = Color(0xFFDBEAFE); // blue-100

  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
}

// =====================================================================
// 白色登录卡片
// =====================================================================

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child, required this.isWide});
  final Widget child;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      decoration: BoxDecoration(
        color: _Light.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Light.cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F3B82F6), // 6% 蓝色辉光
            blurRadius: 32,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

// =====================================================================
// 浅色输入框
// =====================================================================

class _LightInput extends StatelessWidget {
  const _LightInput({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: _Light.primary,
      style: const TextStyle(
        color: _Light.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _Light.textTertiary,
          fontSize: 14,
        ),
        filled: true,
        fillColor: _Light.inputFill,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: _Light.textTertiary, size: 18),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _Light.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _Light.primary, width: 1.5),
        ),
      ),
    );
  }
}

// =====================================================================
// Tab 胶囊切换
// =====================================================================

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? _Light.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : _Light.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
