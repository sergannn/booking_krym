import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models/excursion.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Администратор — ${user.name}'),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Выйти',
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Экскурсии'),
              Tab(text: 'Бронирование'),
              Tab(text: 'Статистика'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExcursionsTab(),
            _ActionsTab(),
            _StatsTab(),
          ],
        ),
      ),
    );
  }
}

class _ExcursionsTab extends ConsumerWidget {
  const _ExcursionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('dd.MM.yyyy • HH:mm');
    final excursionsAsync = ref.watch(excursionsFutureProvider);

    return excursionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Не удалось загрузить: $error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Экскурсии отсутствуют'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(excursionsFutureProvider);
            await ref.read(excursionsFutureProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _AdminExcursionTile(
                excursion: items[index], formatter: formatter),
          ),
        );
      },
    );
  }
}

class _AdminExcursionTile extends StatelessWidget {
  const _AdminExcursionTile({required this.excursion, required this.formatter});

  final Excursion excursion;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(excursion.title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${formatter.format(excursion.dateTime)} • Свободно ${excursion.availableSeatsCount}/${excursion.maxSeats}',
        ),
        children: [
          if (excursion.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(excursion.description),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Цена: ${excursion.price.toStringAsFixed(2)} ₽'),
                const SizedBox(height: 4),
                Text('Забронировано мест: ${excursion.bookedSeatsCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsTab extends ConsumerWidget {
  const _ActionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleAddExcursion() async {
      final created = await showDialog<Excursion>(
        context: context,
        builder: (dialogContext) => const _CreateExcursionDialog(),
      );
      if (created == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      ref.invalidate(excursionsFutureProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Экскурсия "${created.title}" добавлена')),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Быстрые действия',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: handleAddExcursion,
          icon: const Icon(Icons.event_available),
          label: const Text('Добавить экскурсию'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.group_add),
          label: const Text('Назначить персонал'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.monetization_on),
          label: const Text('Обновить тарифы'),
        ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.insights, size: 48),
          SizedBox(height: 12),
          Text('Статистика в разработке'),
        ],
      ),
    );
  }
}

class _CreateExcursionDialog extends ConsumerStatefulWidget {
  const _CreateExcursionDialog();

  @override
  ConsumerState<_CreateExcursionDialog> createState() =>
      _CreateExcursionDialogState();
}

class _CreateExcursionDialogState
    extends ConsumerState<_CreateExcursionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxSeatsController = TextEditingController();
  DateTime? _dateTime;
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxSeatsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    if (_dateTime == null) {
      setState(() => _errorMessage = 'Выберите дату и время экскурсии');
      return;
    }

    final normalizedPrice = _priceController.text.replaceAll(',', '.');
    final price = double.parse(normalizedPrice);
    final maxSeats = int.parse(_maxSeatsController.text);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final excursion =
          await ref.read(excursionsRepositoryProvider).createExcursion(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                dateTime: _dateTime!,
                price: price,
                maxSeats: maxSeats,
                isActive: _isActive,
              );
      if (mounted) {
        Navigator.of(context).pop(excursion);
      }
    } catch (error) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return AlertDialog(
      title: const Text('Новая экскурсия'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Название'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Дата и время'),
                subtitle: Text(
                  _dateTime == null
                      ? 'Не выбрано'
                      : formatter.format(_dateTime!),
                ),
                trailing: TextButton(
                  onPressed: _isSubmitting ? null : _pickDateTime,
                  child: const Text('Выбрать'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Цена'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите цену';
                  }
                  final numeric = value.replaceAll(',', '.');
                  final parsed = double.tryParse(numeric);
                  if (parsed == null || parsed <= 0) {
                    return 'Некорректное значение цены';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxSeatsController,
                decoration: const InputDecoration(labelText: 'Количество мест'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Введите положительное число мест';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _isActive = value),
                title: const Text('Экскурсия активна'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
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
}
