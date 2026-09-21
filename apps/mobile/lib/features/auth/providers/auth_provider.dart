import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../repositories/auth_repository.dart';
import '../../../repositories/business_repository.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (state) => state.session != null,
    orElse: () => ref.watch(authRepositoryProvider).isAuthenticated,
  );
});

class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
            rememberSession: rememberSession,
          );
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resetPassword(email);
    });
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

final userBusinessesProvider = FutureProvider((ref) async {
  ref.watch(isAuthenticatedProvider);
  return ref.watch(businessRepositoryProvider).getUserBusinesses();
});

final rememberSessionProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).shouldRememberSession();
});
