import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../../../repositories/auth_repository.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _email;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await ref.read(authRepositoryProvider).currentEmail();
    if (mounted) setState(() => _email = email);
  }

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _success = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final next = _newPassword.text;
    if (next.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (next != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(next);
      if (!mounted) return;
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _success = 'Password updated successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst(
              'AuthException: ',
              '',
            );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);

    return Stack(
      children: [
        AppScaffold(
          title: 'Change password',
          showBusinessSwitcher: false,
          fallbackRoute: '/dashboard',
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                DeskHeader(
                  title: 'Change password',
                  subtitle: _email == null || _email!.isEmpty
                      ? 'Update your login password'
                      : 'Signed in as $_email',
                ),
                const SizedBox(height: 14),
                SoftSurface(
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'NEW PASSWORD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: brand,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: _obscureNew,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.slate50,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter a new password';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'CONFIRM PASSWORD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: brand,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Re-enter password',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.slate50,
                          prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (v != _newPassword.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _success!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _submit,
                        child: const Text(
                          'Update password',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        LoadingOverlay(
          isVisible: _saving,
          message: 'Updating password…',
        ),
      ],
    );
  }
}
