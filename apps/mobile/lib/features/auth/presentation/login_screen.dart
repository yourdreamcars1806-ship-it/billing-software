import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/businesses.dart';
import '../../../models/business.dart';
import '../../../shared/widgets/business_logo.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberSession = true;
  bool _busy = false;
  String _busyMessage = 'Signing in…';
  String _selectedSlug = BusinessConfig.all.first.slug;

  Business get _selectedBusiness =>
      BusinessConfig.findBySlug(_selectedSlug) ?? BusinessConfig.all.first;

  @override
  void initState() {
    super.initState();
    _applyBusinessLogin(_selectedSlug);
    _loadRememberSession();
  }

  void _applyBusinessLogin(String slug) {
    final creds = BusinessConfig.logins[slug];
    if (creds == null) return;
    _emailController.text = creds.email;
    _passwordController.clear();
  }

  Future<void> _loadRememberSession() async {
    final remember = await ref.read(rememberSessionProvider.future);
    if (mounted) setState(() => _rememberSession = remember);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Signing in…';
    });

    try {
      await ref.read(loginControllerProvider.notifier).signIn(
            email: _emailController.text,
            password: _passwordController.text,
            rememberSession: _rememberSession,
          );

      final state = ref.read(loginControllerProvider);
      if (!mounted) return;

      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error.toString())),
        );
        return;
      }

      setState(() => _busyMessage = 'Opening workspace…');
      await ref
          .read(activeBusinessProvider.notifier)
          .setActiveBusiness(_selectedBusiness);

      if (!mounted) return;
      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = _busy || loginState.isLoading;
    final isClothing = _selectedBusiness.isClothing;
    final brand = AppColors.brand(_selectedBusiness.businessType);
    final soft = AppColors.brandSoft(_selectedBusiness.businessType);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  soft,
                  const Color(0xFFEEF0F3),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const _BrandMark(),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Billing Atelier',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Secure staff login',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isClothing ? 'Clothing' : 'Cars',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.slate200),
                          boxShadow: [
                            BoxShadow(
                              color: brand.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroStrip(isClothing: isClothing),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 22),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Welcome back',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate900,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Pick your desk, then sign in with staff email.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.slate500,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: BusinessConfig.all.map((b) {
                                        final selected =
                                            b.slug == _selectedSlug;
                                        final color =
                                            AppColors.brand(b.businessType);
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: b.isClothing ? 6 : 0,
                                              left: b.isCar ? 6 : 0,
                                            ),
                                            child: InkWell(
                                              onTap: isLoading
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _selectedSlug = b.slug;
                                                        _applyBusinessLogin(
                                                          b.slug,
                                                        );
                                                      });
                                                    },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? AppColors.brandSoft(
                                                          b.businessType,
                                                        )
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    10,
                                                  ),
                                                  border: Border.all(
                                                    color: selected
                                                        ? color
                                                        : AppColors.slate200,
                                                    width: selected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    BusinessLogo(
                                                      business: b,
                                                      size: 36,
                                                      padding: 3,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      b.name,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: selected
                                                            ? AppColors
                                                                .brandDark(
                                                                b.businessType,
                                                              )
                                                            : AppColors
                                                                .slate700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _emailController,
                                      enabled: !isLoading,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          size: 20,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Email is required';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      enabled: !isLoading,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined,
                                          ),
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  );
                                                },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberSession,
                                          activeColor: brand,
                                          onChanged: isLoading
                                              ? null
                                              : (value) {
                                                  setState(
                                                    () => _rememberSession =
                                                        value ?? true,
                                                  );
                                                },
                                        ),
                                        const Text(
                                          'Remember session',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    LoadingButton(
                                      backgroundColor: brand,
                                      loading: isLoading,
                                      loadingLabel: _busyMessage,
                                      onPressed: _handleLogin,
                                      label:
                                          'Login to ${_selectedBusiness.name}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          LoadingOverlay(isVisible: isLoading, message: _busyMessage),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'BA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({required this.isClothing});

  final bool isClothing;

  @override
  Widget build(BuildContext context) {
    final color = isClothing ? AppColors.clothingSolid : AppColors.carSolid;
    final soft = isClothing ? AppColors.clothingSoft : AppColors.carSoft;
    return Container(
      height: 132,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.82),
            soft,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isClothing
                      ? Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            'assets/images/drape-and-dream-logo.png',
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          Icons.directions_car,
                          color: color,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isClothing ? 'Drape & Dream' : 'Your Dream Cars',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isClothing
                            ? 'Barcode clothing billing'
                            : 'Automobile invoice desk',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
