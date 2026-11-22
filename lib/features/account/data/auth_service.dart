import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';

class AppUser {
  const AppUser({required this.id, this.email});
  final String id;
  final String? email;
}

/// A failure the user can understand and act on.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sign-in by a one-time code sent to the email. An interface so tests and
/// builds without Supabase keys work.
abstract interface class AuthService {
  bool get isAvailable;
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();

  /// Deletes the account and its cloud data (supabase/schema.sql).
  Future<void> deleteAccount();
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AppConfig.accountsEnabled
      ? SupabaseAuthService(sb.Supabase.instance.client)
      : const UnavailableAuthService(),
);

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final sb.SupabaseClient _client;

  static AppUser? _map(sb.User? u) =>
      u == null ? null : AppUser(id: u.id, email: u.email);

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Future<void> sendCode(String email) => _guard(
    () => _client.auth.signInWithOtp(email: email, shouldCreateUser: true),
  );

  @override
  Future<void> verifyCode(String email, String code) => _guard(
    () => _client.auth.verifyOTP(
      email: email,
      token: code,
      type: sb.OtpType.email,
    ),
  );

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _client.rpc<void>('delete_my_account');
    // The server session is gone with the user; clear the local one.
    await _client.auth.signOut(scope: sb.SignOutScope.local);
  });

  /// Turns library and network errors into messages for people.
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on sb.AuthRetryableFetchException {
      throw const AuthFailure('Нет связи с сервером. Проверьте интернет.');
    } on sb.AuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on SocketException {
      throw const AuthFailure('Нет связи с сервером. Проверьте интернет.');
    } on TimeoutException {
      throw const AuthFailure('Сервер не отвечает. Попробуйте ещё раз.');
    } on sb.PostgrestException {
      throw const AuthFailure('Ошибка сервера. Попробуйте позже.');
    }
  }

  static String _messageFor(sb.AuthException e) => switch (e.code) {
    'otp_expired' => 'Код неверный или устарел. Запросите новый.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Слишком много попыток. Подождите немного и попробуйте снова.',
    'email_address_invalid' => 'Проверьте адрес почты.',
    'otp_disabled' || 'signup_disabled' => 'Вход по коду отключён на сервере.',
    _ => 'Не удалось войти. Попробуйте ещё раз.',
  };
}

/// Used when the build has no Supabase keys: the app works offline only.
class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  static const _failure = AuthFailure('Аккаунты недоступны в этой версии.');

  @override
  bool get isAvailable => false;
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
  @override
  Future<void> sendCode(String email) => Future.error(_failure);
  @override
  Future<void> verifyCode(String email, String code) => Future.error(_failure);
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() => Future.error(_failure);
}

/// The signed-in user, or null. Follows sign-in, sign-out and token refresh.
final currentUserProvider = NotifierProvider<CurrentUser, AppUser?>(
  CurrentUser.new,
);

class CurrentUser extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final service = ref.watch(authServiceProvider);
    final sub = service.userChanges.listen((user) {
      if (user?.id != state?.id) state = user;
    });
    ref.onDispose(sub.cancel);
    return service.currentUser;
  }
}
