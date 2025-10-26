import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/models/excursion.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';

class SellerHomePage extends ConsumerStatefulWidget {
  const SellerHomePage({super.key, required this.user});

  final User user;

  @override
  ConsumerState<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends ConsumerState<SellerHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ExcursionsTab(),
      const _BookingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Продавец — ${widget.user.name}'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(excursionsFutureProvider);
              ref.invalidate(bookingsFutureProvider);
            },
          ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Экскурсии'),
          NavigationDestination(icon: Icon(Icons.event_seat), label: 'Бронирования'),
        ],
      ),
    );
  }
}

class _ExcursionsTab extends ConsumerWidget {
  const _ExcursionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return excursionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Нет доступных экскурсий'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(excursionsFutureProvider);
            await ref.read(excursionsFutureProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _ExcursionTile(excursion: items[index], formatter: formatter),
          ),
        );
      },
    );
  }
}

class _ExcursionTile extends ConsumerWidget {
  const _ExcursionTile({required this.excursion, required this.formatter});

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
            Text(excursion.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Дата: ${formatter.format(excursion.dateTime)}'),
            Text('Цена: ${excursion.price.toStringAsFixed(2)} ₽'),
            Text('Свободно мест: ${excursion.availableSeatsCount} / ${excursion.maxSeats}'),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final seats = await _promptSeatNumbers(context);
    if (seats == null) {
      return;
    }
    // После диалога проверяем, что текущий BuildContext всё ещё активен
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (seats.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Введите номера мест через запятую.')),
      );
      return;
    }

    try {
      // ref.read(...) — обращение к провайдеру Riverpod, чтобы вызвать API бронирований
      final response = await ref.read(bookingsRepositoryProvider).bookSeats(
            excursionId: excursion.id,
            seatNumbers: seats,
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

  Future<List<int>?> _promptSeatNumbers(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Бронирование мест'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Номера мест',
              hintText: 'Например: 3,7,11',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Забронировать'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return null;
    }

    return result
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
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
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(child: Text('Вы ещё не бронировали места'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingsFutureProvider);
            await ref.read(bookingsFutureProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(group.excursion.title),
                  subtitle: Text(
                    '${formatter.format(group.excursion.dateTime)} • ${group.seats.length} мест',
                  ),
                  children: group.seats
                      .map(
                        (seat) => ListTile(
                          title: Text('Место ${seat.seatNumber}'),
                          subtitle: Text('Бронировано: ${formatter.format(seat.bookedAt)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            tooltip: 'Отменить',
                            onPressed: () => _cancel(context, ref, seat.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, int bookingId) async {
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

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }
}
