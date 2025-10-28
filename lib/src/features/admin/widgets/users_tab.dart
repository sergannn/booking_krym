import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_summary.dart';
import '../../../data/providers.dart';
import '../../../core/api/api_exception.dart';

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersFutureProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Поиск по имени или email',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    // пока просто инвалидация по требованию
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
                onPressed: () async {
                  final created = await showDialog<UserSummary?>(
                    context: context,
                    builder: (context) => const _CreateUserDialog(),
                  );
                  if (created != null && context.mounted) {
                    ref.invalidate(allUsersFutureProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Пользователь "${created.name}" создан. Логин: ${created.email}',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _UsersError(message: '$error'),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text('Сотрудников пока нет'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allUsersFutureProvider);
                    await ref.read(allUsersFutureProvider.future);
                  },
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(user.name),
                        subtitle: Text('${user.email} • ${user.roleName}'),
                        trailing: Text('ID ${user.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersError extends StatelessWidget {
  const _UsersError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int? _selectedRoleId;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _passwordController.text = _generatePassword();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(userRolesFutureProvider);

    return AlertDialog(
      title: const Text('Новый сотрудник'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя и инициалы'),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    value == null || value.trim().length < 2
                        ? 'Введите имя'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email/логин'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите email';
                  }
                  final emailRegex =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Некорректный email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Сгенерировать пароль',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(
                              () => _passwordController.text =
                                  _generatePassword(),
                            ),
                  ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Минимум 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              rolesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => Text('Ошибка загрузки ролей: $error'),
                data: (roles) {
                  if (roles.isEmpty) {
                    return const Text('Нет доступных ролей');
                  }
                  _selectedRoleId ??= roles.first.id;
                  return DropdownButtonFormField<int>(
                    value: _selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Роль'),
                    items: roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role.id,
                            child: Text(role.name),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _selectedRoleId = value),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedRoleId == null) {
      setState(() => _error = 'Выберите роль');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repository = ref.read(usersRepositoryProvider);
      final created = await repository.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        roleId: _selectedRoleId!,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } on ApiException catch (error) {
      setState(() {
        _isSubmitting = false;
        _error = error.message;
      });
    } catch (error) {
      setState(() {
        _isSubmitting = false;
        _error = '$error';
      });
    }
  }

  String _generatePassword() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final codeUnits = List.generate(
      8,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    );
    return String.fromCharCodes(codeUnits);
  }
}
