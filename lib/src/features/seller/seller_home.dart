import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/models/excursion.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/bookings_repository.dart';
import '../seller/widgets/booking_dialog.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';
import '../common/utils/ticket_generator.dart';
import '../common/widgets/cancellation_reason_dialog.dart';

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
      _SellerWalletTab(user: widget.user),
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
              ref.invalidate(userWalletFutureProvider(widget.user.id));
              ref.invalidate(userSalesFutureProvider(widget.user.id));
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
                date: DateFormat('EEEE, dd MMMM yyyy', 'ru_RU').format(date),
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
                Text(
                  'Цена (взрослый): ${excursion.priceFor('adult').toStringAsFixed(2)} ₽',
                ),
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
                      : () => _showSeatSheet(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book(
    BuildContext context,
    WidgetRef ref, {
    List<int>? preselectedSeats,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final stopsAsync = await ref.read(stopsFutureProvider.future);
    final result = await showDialog<BookingDialogResult>(
      context: context,
      builder: (context) => BookingDialog(
        stops: stopsAsync,
        tariffs: excursion.tariffs,
        initialSeatNumbers: preselectedSeats ?? const [],
        lockSeatSelection: (preselectedSeats?.isNotEmpty ?? false),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      final response = await ref.read(bookingsRepositoryProvider).bookSeats(
            BookSeatPayload(
              excursionId: excursion.id,
              seatNumbers: result.seatNumbers,
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
      final authState = ref.read(authControllerProvider);
      final bookedBy = authState.value?.name ?? 'Неизвестный продавец';
      try {
        await TicketGenerator.generateAndShare(
          excursion: excursion,
          seatNumbers: result.seatNumbers,
          pricePerSeat: result.pricePerSeat,
          customerName: result.customerName,
          customerPhone: result.customerPhone,
          passengerType: result.passengerType,
          stop: result.stop,
          bookedBy: bookedBy,
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Не удалось сформировать билет: $error')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка бронирования: $error')),
      );
    }
  }

  Future<void> _showSeatSheet(BuildContext context, WidgetRef ref) async {
    final seatNumber = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Схема мест'),
        content: SingleChildScrollView(
          child: Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: excursion.busSeats.map((seat) {
                final isAvailable = seat.status == 'available';
                final color = isAvailable
                    ? Colors.green.shade200
                    : Colors.red.shade200;
                return InkWell(
                  onTap: isAvailable
                      ? () => Navigator.of(dialogContext).pop(seat.seatNumber)
                      : null,
                  child: Chip(
                    label: Text('Место ${seat.seatNumber}'),
                    backgroundColor: color,
                  ),
                );
              }).toList(),
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

    if (seatNumber != null) {
      await _book(context, ref, preselectedSeats: [seatNumber]);
    }
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
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const CancellationReasonDialog(),
    );

    if (reason == null) {
      return;
    }

    try {
      await ref
          .read(bookingsRepositoryProvider)
          .cancelBooking(bookingId, reason: reason);
      ref.invalidate(bookingsFutureProvider);
      ref.invalidate(excursionsFutureProvider);
      final authState = ref.read(authControllerProvider);
      final currentUserId = authState.value?.id;
      if (currentUserId != null) {
        ref.invalidate(userWalletFutureProvider(currentUserId));
        ref.invalidate(userSalesFutureProvider(currentUserId));
      }
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
  const _SellerWalletTab({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletFutureProvider(user.id));
    final salesAsync = ref.watch(userSalesFutureProvider(user.id));
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return walletAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (wallet) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userWalletFutureProvider(user.id));
            ref.invalidate(userSalesFutureProvider(user.id));
            ref.invalidate(bookingsFutureProvider);
            await Future.wait([
              ref.read(userWalletFutureProvider(user.id).future),
              ref.read(userSalesFutureProvider(user.id).future),
              ref.read(bookingsFutureProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Баланс'),
                  subtitle: const Text('Текущий остаток по кошельку'),
                  trailing: Text(
                    '${wallet.balance.toStringAsFixed(2)} ₽',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'История транзакций',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (wallet.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Транзакций пока нет'),
                )
              else
                ...wallet.transactions.map(
                  (transaction) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: transaction.amount >= 0
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        transaction.amount >= 0
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: transaction.amount >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    title: Text(transaction.description),
                    subtitle: Text(
                      formatter.format(transaction.createdAt),
                    ),
                    trailing: Text(
                      '${transaction.amount.toStringAsFixed(2)} ₽',
                      style: TextStyle(
                        color: transaction.amount >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Продажи',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              salesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка загрузки: $error'),
                ),
                data: (sales) {
                  if (sales.bookings.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Продаж пока нет'),
                    );
                  }
                  return Column(
                    children: sales.bookings
                        .map(
                          (booking) => ListTile(
                            title: Text(booking.excursion.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatter.format(booking.excursion.dateTime),
                                ),
                                Text(
                                  '${booking.customerName} • ${booking.customerPhone}',
                                ),
                                Text(booking.passengerType.label),
                              ],
                            ),
                            trailing: Text(
                              '${booking.price.toStringAsFixed(2)} ₽',
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Активные бронирования',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка: $error'),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Вы ещё не бронировали места'),
                    );
                  }
                  return Column(
                    children: groups.map((group) {
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
                                    'Бронировано: ${formatter.format(booking.bookedAt)}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.cancel),
                                    tooltip: 'Отменить',
                                    onPressed: () =>
                                        _cancelBooking(context, ref, booking.id),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    }).toList(),
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
      BuildContext context, WidgetRef ref, int bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const CancellationReasonDialog(),
    );

    if (reason == null) {
      return;
    }

    try {
      await ref
          .read(bookingsRepositoryProvider)
          .cancelBooking(bookingId, reason: reason);
      ref.invalidate(bookingsFutureProvider);
      ref.invalidate(userWalletFutureProvider(user.id));
      ref.invalidate(userSalesFutureProvider(user.id));
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
