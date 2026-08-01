import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/storage/local_store.dart';
import '../models/user.dart';

enum AuthStatus { initial, unauthenticated, authenticating, authenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final api = ref.read(apiClientProvider);
    api.setOnUnauthorized(() {
      _forceLogout();
    });
    return const AuthState();
  }

  Future<void> restoreSession() async {
    final token = await LocalStore.getToken();
    final user = await LocalStore.getUser();
    if (token != null && user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return;
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> login(String email, String password, {String? fcmToken}) async {
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email, password, fcmToken: fcmToken);
      await LocalStore.saveSession(result.token, result.user);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // best effort - clear local session regardless
    }
    await LocalStore.clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _forceLogout() async {
    await LocalStore.clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshProfile() async {
    try {
      final user = await ref.read(authRepositoryProvider).getProfile();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      final token = await LocalStore.getToken();
      if (token != null) await LocalStore.saveSession(token, user);
    } catch (_) {
      // ignore refresh failures
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<User?>((ref) => ref.watch(authControllerProvider).user);

final currentRoleProvider = Provider<String>((ref) {
  final user = ref.watch(authControllerProvider).user;
  return user?.role ?? 'manager';
});
