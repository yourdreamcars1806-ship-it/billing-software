import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../core/errors/app_exception.dart';
import '../services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseServiceProvider));
});

class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseService _supabase;

  bool get isAuthenticated => _supabase.isAuthenticated;

  Stream<AuthState> get authStateChanges => _supabase.authStateChanges;

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    try {
      await _supabase.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.rememberSessionKey, rememberSession);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> signOut() async {
    await _supabase.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.activeBusinessIdKey);
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw AuthException('Failed to send reset email: $e');
    }
  }

  Future<String?> currentEmail() async {
    return _supabase.client.auth.currentUser?.email;
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final res = await _supabase.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (res.user == null) {
        throw AuthException('Could not update password. Try signing in again.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<bool> shouldRememberSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.rememberSessionKey) ?? true;
  }
}
