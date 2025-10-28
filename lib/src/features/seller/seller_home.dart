import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/models/excursion.dart';
import '../../data/repositories/bookings_repository.dart';
import '../seller/widgets/booking_dialog.dart';
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
      const _SellerWalletTab(),
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
          NavigationDestination(
              icon: Icon(Icons.event_seat), label: 'Бронирования'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Кошелёк'),
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
    final formatter = DateFormat('HH:mm');

    return excursionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (items) {
        final upcoming =
            items.where((excursion) => !excursion.isPast).toList();
        if (upcoming.isEmpty) {
          return const Center(child: Text('Нет доступных экскурсий'));
        }
        upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        final groups = <DateTime, List<Excursion>>{};
        for (final excursion in upcoming) {
          final key = DateTime(excursion.dateTime.year, excursion.dateTime.month,
              excursion.dateTime.day);
          groups.putIfAbsent(key, () => []).add(excursion);
        }
        final sortedDates = groups.keys.toList()..sort();
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(excursionsFutureProvider);
            await ref.read(excursionsFutureProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final dayItems = groups[date]!;
              return _ExcursionDaySection(
                date: DateFormat('EEEE, dd MMMM', 'ru_RU').format(date),
                excursions: dayItems,
                formatter: formatter,
              );
            },
          ),
        );
      },
    );
  }
}

class _ExcursionDaySection extends StatelessWidget {
  const _ExcursionDaySection({
    required this.date,
    required this.excursions,
    required this.formatter,
  });

  final String date;
  final List<Excursion> excursions;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final excursion in excursions)
          _ExcursionTile(excursion: excursion, formatter: formatter),
        const SizedBox(height: 24),
      ],
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
            Text(
              '${formatter.format(excursion.dateTime)} — ${excursion.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (excursion.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  excursion.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Цена: ${excursion.price.toStringAsFixed(2)} ₽'),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Свободно ${excursion.availableSeatsCount} из ${excursion.maxSeats}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
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
    final stopsAsync = await ref.read(stopsFutureProvider.future);
    final result = await showDialog<BookingDialogResult>(
      context: context,
      builder: (context) => BookingDialog(stops: stopsAsync),
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
                    '${formatter.format(group.excursion.dateTime)} • ${group.bookings.length} мест',
                  ),
                  children: group.bookings
                      .map(
                        (booking) => ListTile(
                          title: Text('Место ${booking.seat.seatNumber}'),
                          subtitle: Text(
                              'Бронировано: ${formatter.format(booking.bookedAt)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            tooltip: 'Отменить',
                            onPressed: () =>
                                _cancel(context, ref, booking.id),
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

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, int bookingId) async {
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

class _SellerWalletTab extends ConsumerWidget {
  const _SellerWalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (groups) {
        final bookings = groups
            .expand((group) => group.bookings)
            .toList()
          ..sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
        final total = bookings.fold<double>(
          0,
          (sum, item) => sum + item.price,
        );

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
                            trailing: Text(
                              '${entry.price.toStringAsFixed(2)} ₽',
                            ),
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
