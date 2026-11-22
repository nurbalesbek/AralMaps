import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/auth_service.dart';

/// Two steps: email → 6-digit code from the email.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// Null: entering the email. Set: waiting for the code sent there.
  String? _sentTo;
  bool _busy = false;
  String? _error;

  /// Supabase allows a new code only after a while.
  static const _resendAfter = Duration(seconds: 60);
  int _resendIn = 0;
  Timer? _resendTimer;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendAfter.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Введите адрес почты, например name@mail.kz');
      return;
    }
    await _run(() async {
      await ref.read(authServiceProvider).sendCode(email);
      setState(() {
        _sentTo = email;
        _code.clear();
      });
      _startResendCountdown();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Введите код из письма');
      return;
    }
    await _run(() async {
      await ref.read(authServiceProvider).verifyCode(_sentTo!, code);
      if (mounted) context.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentTo = _sentTo;

    return Scaffold(
      appBar: AppBar(title: const Text('Вход в AralMap')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (sentTo == null) ...[
            Text(
              'Войдите, чтобы избранное хранилось в аккаунте и было на всех '
              'ваших телефонах. Пароль не нужен — пришлём код на почту.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendCode(),
              decoration: const InputDecoration(
                labelText: 'Почта',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Text(
              'Мы отправили код на $sentTo. Письмо может прийти через минуту; '
              'проверьте и папку «Спам».',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
              decoration: const InputDecoration(
                labelText: 'Код из письма',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : (sentTo == null ? _sendCode : _verify),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(sentTo == null ? 'Получить код' : 'Войти'),
          ),
          if (sentTo != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || _resendIn > 0 ? null : _sendCode,
              child: Text(
                _resendIn > 0
                    ? 'Отправить код ещё раз через $_resendIn с'
                    : 'Отправить код ещё раз',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sentTo = null;
                      _error = null;
                    }),
              child: const Text('Изменить почту'),
            ),
          ],
        ],
      ),
    );
  }
}
