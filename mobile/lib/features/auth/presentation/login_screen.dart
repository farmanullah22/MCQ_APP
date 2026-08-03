import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../models/login_preview.dart';
import '../providers/auth_providers.dart';

/// Premium luxury login screen — black & gold, carpet photo backdrop,
/// frosted glass card with a golden gradient border.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFE9CE7A);
  static const _goldDark = Color(0xFFB8860B);
  static const _black = Color(0xFF050505);
  static const _rememberKey = 'login_remember_email';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  Timer? _previewTimer;
  LoginPreview? _preview;
  bool _previewLoading = false;
  String? _selectedShopId;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeOut),
  );
  late final Animation<double> _cardFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
  );
  late final Animation<Offset> _cardSlide = Tween<Offset>(
    begin: const Offset(0, 0.16),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
    ),
  );
  late final Animation<double> _trustFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_schedulePreview);
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _controller.dispose();
    _previewTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberKey);
    if (email == null || email.isEmpty) return;
    _emailController.text = email;
    if (mounted) setState(() => _rememberMe = true);
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    if (Validators.email(_emailController.text.trim()) != null) {
      if (_preview != null || _previewLoading) {
        setState(() {
          _preview = null;
          _selectedShopId = null;
          _previewLoading = false;
        });
      }
      return;
    }
    _previewTimer = Timer(const Duration(milliseconds: 450), _lookupPreview);
  }

  Future<void> _lookupPreview() async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final preview = await ref
          .read(authRepositoryProvider)
          .previewLogin(_emailController.text);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewLoading = false;
        if (preview.isManager && preview.shops.isNotEmpty) {
          _selectedShopId = _selectedShopId ?? preview.shops.first.id;
        } else {
          _selectedShopId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewLoading = false;
        _selectedShopId = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isManager = _preview?.isManager == true;
    if (isManager && _selectedShopId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your shop to continue.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final fcmToken = await FcmService.instance.getToken();
    final ok = await ref.read(authControllerProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
          shopId: isManager ? _selectedShopId : null,
          fcmToken: fcmToken,
        );
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(_rememberKey, _emailController.text.trim());
      } else {
        await prefs.remove(_rememberKey);
      }
      return;
    }
    final error =
        ref.read(authControllerProvider).error ?? 'Login failed. Please try again.';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.danger, size: 36),
        title: const Text('Login Failed'),
        content: Text(
          _friendlyError(error),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('unauthorized') ||
        lower.contains('invalid email') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('selected shop') || lower.contains('assigned shop')) {
      return 'The selected shop is not valid for this account.';
    }
    if (lower.contains('deactivated')) {
      return 'This account has been deactivated. Contact the admin.';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Could not reach the server. Check your internet connection and that the backend is running.';
    }
    return error;
  }

  void _onForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please contact your administrator to reset your password.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      authControllerProvider.select((s) => s.status == AuthStatus.authenticating),
    );
    final isManager = _preview?.isManager == true;
    final showShop = _previewLoading || isManager;

    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/images/backgrounimg.jfif',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _black.withValues(alpha: 0.92),
                  _black.withValues(alpha: 0.55),
                  _black.withValues(alpha: 0.9),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: _logoFade,
                        child: AppLogo(
                          size: 104,
                          dark: true,
                          imagePath: 'lib/images/logo2.jfif',
                        ),
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: _buildGlassCard(loading, showShop, isManager),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _trustFade,
                        child: const _TrustRow(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Demo — Admin: admin@muallimcarpets.com\n'
                        'Managers: israr@ / farooq@ / dostmuhammad@muallimcarpets.com\n'
                        'Password: Admin@123 / Manager@123',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(bool loading, bool showShop, bool isManager) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: 0.25),
            blurRadius: 34,
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.all(1.4),
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6121212), Color(0xF0050505)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ).createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your business',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 26),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _gold,
                        validator: Validators.email,
                        decoration: _luxeDecoration(
                          'Email',
                          Icons.mail_outline,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (showShop)
                        _ShopDropdown(
                          loading: _previewLoading,
                          shops: _preview?.shops ?? const [],
                          value: _selectedShopId,
                          enabled: _previewLoading == false &&
                              (_preview?.shops.isNotEmpty ?? false),
                          onChanged: (v) => setState(() => _selectedShopId = v),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _gold,
                        validator: (v) => Validators.required(v, 'Password is required'),
                        decoration: _luxeDecoration(
                          'Password',
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: _gold,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _RememberMe(
                            checked: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v),
                          ),
                          TextButton(
                            onPressed: _onForgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: _goldLight,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildSignInButton(loading),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _luxeDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
      ),
      floatingLabelStyle: const TextStyle(
        color: _gold,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      errorStyle: const TextStyle(color: AppColors.premiumRedLight),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: _gold.withValues(alpha: 0.85),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.premiumRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.premiumRedLight, width: 1.4),
      ),
    );
  }

  Widget _buildSignInButton(bool loading) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: loading ? 0.12 : 0.5),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: loading ? null : _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black87,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login, size: 20, color: Colors.black87),
                      const SizedBox(width: 10),
                      Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShopDropdown extends StatelessWidget {
  const _ShopDropdown({
    required this.loading,
    required this.shops,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool loading;
  final List<ShopOption> shops;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
    );
    final decoration = InputDecoration(
      labelText: 'Branch',
      prefixIcon: const Icon(Icons.store_outlined, color: _gold, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      floatingLabelStyle: const TextStyle(color: _gold, fontWeight: FontWeight.w600),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.85), width: 1.4),
      ),
    );

    if (loading) {
      return InputDecorator(
        decoration: decoration,
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
            ),
            const SizedBox(width: 12),
            Text(
              'Checking your branch...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(shops.map((s) => s.id).join(',')),
      initialValue: shops.any((s) => s.id == value) ? value : null,
      dropdownColor: const Color(0xF0111111),
      icon: const Icon(Icons.arrow_drop_down, color: _gold),
      borderRadius: BorderRadius.circular(16),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: decoration,
      items: shops
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(
                s.name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? (v) => onChanged(v) : null,
    );
  }
}

class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: checked
                    ? const LinearGradient(
                        colors: [_gold, Color(0xFFB8860B)],
                      )
                    : null,
                border: Border.all(
                  color: checked ? _gold : Colors.white.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 15, color: Colors.black87)
                  : null,
            ),
            const SizedBox(width: 9),
            Text(
              'Remember me',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _TrustItem(Icons.verified_outlined, 'Trusted Quality'),
        _TrustItem(Icons.support_agent_outlined, 'Best Service'),
        _TrustItem(Icons.sentiment_satisfied_alt_outlined, 'Customer Satisfaction'),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

