import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models/excursion.dart';
import '../../data/models/user.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';
import '../seller/widgets/booking_dialog.dart';
import 'widgets/users_tab.dart';
import 'widgets/assign_staff_sheet.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Администратор — ${user.name}'),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Добавить экскурсию',
                onPressed: () async {
                  final created = await showDialog<Excursion>(
                    context: context,
                    builder: (dialogContext) => const _CreateExcursionDialog(),
                  );
                  if (created == null || !context.mounted) {
                    return;
                  }
                  ref.invalidate(excursionsFutureProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Экскурсия "${created.title}" добавлена'),
                    ),
                  );
                },
              ),
            ),
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
              Tab(text: 'Бронирование'),
              Tab(text: 'Кошелёк'),
              Tab(text: 'Статистика'),
              Tab(text: 'Расписание'),
              Tab(text: 'Сотрудники'),
              Tab(text: 'Цены'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AdminBookingTab(),
            _AdminWalletTab(),
            _PlaceholderTab(message: 'Статистика в разработке'),
            _PlaceholderTab(message: 'Расписание в разработке'),
            UsersTab(currentUserId: user.id),
            _PlaceholderTab(message: 'Цены в разработке'),
          ],
        ),
      ),
    );
  }
}

class _AdminBookingTab extends ConsumerWidget {
  const _AdminBookingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy • HH:mm');

    return excursionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Не удалось загрузить: $error')),
      data: (excursions) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(excursionsFutureProvider);
            ref.invalidate(bookingsFutureProvider);
            await Future.wait([
              ref.read(excursionsFutureProvider.future),
              ref.read(bookingsFutureProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (excursions.isEmpty)
                const Center(child: Text('Экскурсии отсутствуют'))
              else ...[
                for (final excursion in excursions)
                  _AdminExcursionCard(
                    key: ValueKey('admin-excursion-${excursion.id}'),
                    excursion: excursion,
                    formatter: formatter,
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                'Мои бронирования',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              bookingsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Не удалось загрузить бронирования: $error'),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Text('Нет активных бронирований');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final subFormatter = DateFormat('dd.MM.yyyy HH:mm');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(group.excursion.title),
                          subtitle: Text(
                            '${subFormatter.format(group.excursion.dateTime)} • ${group.bookings.length} мест',
                          ),
                          children: group.bookings
                              .map(
                                (booking) => ListTile(
                                  title:
                                      Text('Место ${booking.seat.seatNumber}'),
                                  subtitle: Text(
                                    'Бронировано: ${subFormatter.format(booking.bookedAt)}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.cancel),
                                    tooltip: 'Отменить',
                                    onPressed: () => _cancelBooking(
                                      context,
                                      ref,
                                      booking.id,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelBooking(
    BuildContext context,
    WidgetRef ref,
    int bookingId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(bookingsRepositoryProvider).cancelBooking(bookingId);
      ref.invalidate(bookingsFutureProvider);
      ref.invalidate(excursionsFutureProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Бронирование отменено')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось отменить: $error')),
      );
    }
  }
}

class _AdminExcursionCard extends ConsumerWidget {
  const _AdminExcursionCard(
      {super.key, required this.excursion, required this.formatter});

  final Excursion excursion;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(excursion.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Дата: ${formatter.format(excursion.dateTime)}'),
            Text('Цена: ${excursion.price.toStringAsFixed(2)} ₽'),
            Text(
                'Свободно мест: ${excursion.availableSeatsCount} / ${excursion.maxSeats}'),
            if (excursion.assignedStaff.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: excursion.assignedStaff
                    .map(
                      (staff) => Chip(
                        avatar: Icon(
                          staff.roleInExcursion == 'driver'
                              ? Icons.directions_bus
                              : Icons.record_voice_over,
                          size: 16,
                        ),
                        label: Text(staff.name),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (excursion.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(excursion.description),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.event_seat),
                  label: const Text('Забронировать'),
                  onPressed: () => _book(context, ref),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text('Места'),
                  onPressed: excursion.busSeats.isEmpty
                      ? null
                      : () => _showSeatSheet(context),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: const Text('Назначить персонал'),
                  onPressed: () => _assignStaff(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final stops = await ref.read(stopsFutureProvider.future);
    final result = await showDialog<BookingDialogResult>(
      context: context,
      builder: (dialogContext) => BookingDialog(stops: stops),
    );

    if (result == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await ref.read(bookingsRepositoryProvider).bookSeats(
            BookSeatPayload(
              excursionId: excursion.id,
              seatNumbers: result.seatNumbers,
              price: result.price,
              customerName: result.customerName,
              customerPhone: result.customerPhone,
              passengerType: result.passengerType,
              stopId: result.stopId,
            ),
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            response.message.isNotEmpty
                ? response.message
                : 'Бронирование выполнено',
          ),
        ),
      );
      ref.invalidate(bookingsFutureProvider);
      ref.invalidate(excursionsFutureProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка бронирования: $error')),
      );
    }
  }

  Future<void> _showSeatSheet(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Схема мест'),
        content: SingleChildScrollView(
          child: Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: excursion.busSeats
                  .map(
                    (seat) => Chip(
                      label: Text('Место ${seat.seatNumber}'),
                      backgroundColor: seat.status == 'booked'
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignStaff(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => AssignStaffSheet(excursion: excursion),
    );
    if (result == true) {
      ref.invalidate(excursionsFutureProvider);
    }
  }
}

class _AdminWalletTab extends ConsumerWidget {
  const _AdminWalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Не удалось загрузить: $error')),
      data: (groups) {
        final bookings = groups
            .expand((group) => group.bookings)
            .toList()
          ..sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
        final total = bookings.fold<double>(0, (sum, item) => sum + item.price);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  title: const Text('Баланс'),
                  subtitle: const Text('Сумма подтверждённых продаж'),
                  trailing: Text(
                    '${total.toStringAsFixed(2)} ₽',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'История продаж',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: bookings.isEmpty
                    ? const Center(child: Text('Продаж пока нет'))
                    : ListView.separated(
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = bookings[index];
                          return ListTile(
                            title: Text(entry.excursion.title),
                            subtitle: Text(
                              '${formatter.format(entry.excursion.dateTime)} • Место ${entry.seat.seatNumber}',
                            ),
                            trailing:
                                Text('${entry.price.toStringAsFixed(2)} ₽'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, textAlign: TextAlign.center),
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
