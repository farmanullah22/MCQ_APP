import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/carpet_pattern.dart';
import '../../../core/widgets/status_views.dart';
import '../models/login_preview.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  Timer? _previewTimer;
  LoginPreview? _preview;
  bool _previewLoading = false;
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_schedulePreview);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      final preview = await ref.read(authRepositoryProvider).previewLogin(_emailController.text);
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
    if (ok) return;
    final error = ref.read(authControllerProvider).error ?? 'Login failed. Please try again.';
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
    if (lower.contains('unauthorized') || lower.contains('invalid email') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('selected shop') || lower.contains('assigned shop')) {
      return 'The selected shop is not valid for this account.';
    }
    if (lower.contains('deactivated')) {
      return 'This account has been deactivated. Contact the admin.';
    }
    if (lower.contains('network') || lower.contains('connection') || lower.contains('timeout')) {
      return 'Could not reach the server. Check your internet connection and that the backend is running.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loading = ref.watch(authControllerProvider.select((s) => s.status == AuthStatus.authenticating));
    final isManager = _preview?.isManager == true;
    final showShop = _previewLoading || isManager;

    return Scaffold(
      body: PremiumBackground(
        isDark: isDark,
        watermarkSize: 360,
        watermarkOpacity: 0.05,
        watermarkAlignment: Alignment.center,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppLogo(size: 120, dark: isDark),
                  const SizedBox(height: 40),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to manage your business',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
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
                          validator: Validators.email,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (showShop)
                          _ShopDropdown(
                            loading: _previewLoading,
                            shops: _preview?.shops ?? const [],
                            value: _selectedShopId,
                            enabled: _previewLoading == false && (_preview?.shops.isNotEmpty ?? false),
                            onChanged: (v) => setState(() => _selectedShopId = v),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => Validators.required(v, 'Password is required'),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        LoadingButton(
                          loading: loading,
                          label: 'Sign In',
                          icon: Icons.login,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Demo accounts — Admin: admin@muallimcarpets.com\nManagers: israr@ / farooq@ / dostmuhammad@muallimcarpets.com\nPassword: Admin@123 / Manager@123',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    return loading
        ? const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Shop',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Checking your shop...'),
              ],
            ),
          )
        : DropdownButtonFormField<String>(
            key: ValueKey(shops.map((s) => s.id).join(',')),
            initialValue: shops.any((s) => s.id == value) ? value : null,
            decoration: const InputDecoration(
              labelText: 'Shop',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            items: shops
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: enabled ? (v) => onChanged(v) : null,
          );
  }
}
