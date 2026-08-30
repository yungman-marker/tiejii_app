import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../widgets/brand_logo.dart';

/// 登录页（千问 / DeepSeek 风格：白底 + 居中品牌 + 浅蓝主按钮）。
///
/// 登录方式：
/// - 手机号一键登录：需后端验证码接口，当前测试环境未开放，仅占位
/// - 账号密码登录：**真实对接** `/auth/publicKey` → RSA 加密 → `/auth/login`
/// - 企业微信 / 铁建通：需 OAuth 中转页，占位
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscure = true;
  int _tabIndex = 0; // 0 = 手机号一键登录，1 = 账号密码登录

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
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 52),
              const Center(child: BrandLogo()),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  '铁骥大模型',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _buildTabs(),
              const SizedBox(height: 22),
              if (_tabIndex == 0) ..._buildPhoneForm() else ..._buildPasswordForm(),
              const SizedBox(height: 18),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    auth.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              _buildSubmitButton(auth.loading),
              const SizedBox(height: 28),
              _buildThirdParty(),
              const SizedBox(height: 24),
              const Text(
                '登录即代表同意《用户协议》与《隐私政策》',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _TabItem(
          text: '手机号一键登录',
          selected: _tabIndex == 0,
          onTap: () => setState(() => _tabIndex = 0),
        ),
        const SizedBox(width: 24),
        _TabItem(
          text: '账号密码登录',
          selected: _tabIndex == 1,
          onTap: () => setState(() => _tabIndex = 1),
        ),
      ],
    );
  }

  List<Widget> _buildPasswordForm() {
    return [
      TextField(
        controller: _userController,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: '请输入账号'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordController,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: '请输入密码',
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textTertiary,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPhoneForm() {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: '请输入手机号'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: '请输入验证码',
          suffixText: '获取验证码',
          suffixStyle: TextStyle(color: AppColors.primary, fontSize: 13),
        ),
      ),
    ];
  }

  Widget _buildSubmitButton(bool loading) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
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
            : const Text(
                '登 录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildThirdParty() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ThirdPartyButton(
          label: '企业微信',
          color: AppColors.wechatGreen,
          background: AppColors.wechatGreenSoft,
          onTap: () => _showTip('企业微信登录需 OAuth 中转页，待联调后开放'),
        ),
        const SizedBox(width: 34),
        _ThirdPartyButton(
          label: '铁建通',
          color: AppColors.brandBlue,
          background: AppColors.brandBlueSoft,
          onTap: () => _showTip('铁建通登录需 OAuth 中转页，待联调后开放'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_tabIndex == 0) {
      _showTip('手机号一键登录需后端验证码接口，当前环境暂未开放');
      return;
    }

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

  void _showTip(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 2,
            width: 28,
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _ThirdPartyButton extends StatelessWidget {
  const _ThirdPartyButton({
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
