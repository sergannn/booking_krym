import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.signIn(
      _loginController.text,
      _passwordController.text,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный логин или пароль')),
      );
    }
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вход в систему',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        hintText: 'Введите логин',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Укажите логин';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        hintText: 'Введите пароль',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Укажите пароль';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Войти'),
                      ),
                    ),
                    if (users.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Доступные аккаунты (демо):',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final user in users)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(user.displayName),
                          subtitle: Text(
                              'Логин: ${user.login}, пароль: ${user.password}'),
                          trailing: Text(_roleLabel(user.role)),
                        ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Администратор';
      case UserRole.seller:
        return 'Продавец';
      case UserRole.partnerSeller:
        return 'Продавец-партнер';
      case UserRole.driver:
        return 'Водитель';
      case UserRole.guide:
        return 'Экскурсовод';
    }
  }
}
