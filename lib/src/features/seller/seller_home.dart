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
import '../common/utils/pdf_downloader.dart';
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
        final upcoming = items.where((excursion) => !excursion.isPast).toList();
        if (upcoming.isEmpty) {
          return const Center(child: Text('Нет доступных экскурсий'));
        }
        upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        final groups = <DateTime, List<Excursion>>{};
        for (final excursion in upcoming) {
          final key = DateTime(excursion.dateTime.year,
              excursion.dateTime.month, excursion.dateTime.day);
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
    // Определяем, доступна ли экскурсия для бронирования
    final isAvailable = excursion.availableSeatsCount > 0 && !excursion.isPast;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isAvailable
          ? null
          : Colors.grey.shade200, // Серый фон для недоступных
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
                  onPressed: isAvailable ? () => _book(context, ref) : null,
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
      // Используем новый формат если доступен, иначе старый
      final payload = result.seats != null && result.seats!.isNotEmpty
          ? BookSeatPayload(
              excursionId: excursion.id,
              seats: result.seats!,
              customerName: result.customerName,
              customerPhone: result.customerPhone,
              stopId: result.stopId,
            )
          : BookSeatPayload(
              excursionId: excursion.id,
              seatNumbers: result.seatNumbers,
              customerName: result.customerName,
              customerPhone: result.customerPhone,
              passengerType: result.passengerType,
              stopId: result.stopId,
            );

      final response =
          await ref.read(bookingsRepositoryProvider).bookSeats(payload);
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

      // Сохраняем/открываем PDF через backend
      try {
        final bookingId = response.firstBookingId;
        if (bookingId != null) {
          // Скачиваем PDF как байты
          final pdfBytes = await ref
              .read(bookingsRepositoryProvider)
              .downloadTicketPdf(bookingId);
          // Сохраняем/отправляем PDF (на мобильных) или скачиваем (на веб)
          await PdfDownloader.saveAndSharePdf(
            pdfBytes: pdfBytes,
            filename: 'ticket-$bookingId.pdf',
          );
        }
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Не удалось сохранить билет: $error')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка бронирования: $error')),
      );
    }
  }

  Future<void> _showSeatSheet(BuildContext context, WidgetRef ref) async {
    final selectedSeats = <int>{};

    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Схема мест'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: excursion.busSeats.map((seat) {
                  final isAvailable = seat.status == 'available';
                  final isSelected = selectedSeats.contains(seat.seatNumber);
                  final color = isSelected
                      ? Colors.blue.shade300
                      : isAvailable
                          ? Colors.green.shade200
                          : Colors.red.shade200;
                  return InkWell(
                    onTap: isAvailable
                        ? () {
                            setState(() {
                              if (isSelected) {
                                selectedSeats.remove(seat.seatNumber);
                              } else {
                                selectedSeats.add(seat.seatNumber);
                              }
                            });
                          }
                        : null,
                    child: Chip(
                      label: Text('${seat.seatNumber}'),
                      backgroundColor: color,
                      labelStyle: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            if (selectedSeats.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() => selectedSeats.clear());
                },
                child: const Text('Очистить'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: selectedSeats.isNotEmpty
                  ? () => Navigator.of(dialogContext)
                      .pop(selectedSeats.toList()..sort())
                  : null,
              child: Text('Выбрать (${selectedSeats.length})'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _book(context, ref, preselectedSeats: result);
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
                            onPressed: () => _cancel(context, ref, booking.id),
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

class _SellerWalletTab extends ConsumerStatefulWidget {
  const _SellerWalletTab({required this.user});

  final User user;

  @override
  ConsumerState<_SellerWalletTab> createState() => _SellerWalletTabState();
}

class _SellerWalletTabState extends ConsumerState<_SellerWalletTab> {
  int _sectionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(userWalletFutureProvider(widget.user.id));
    final salesAsync = ref.watch(userSalesFutureProvider(widget.user.id));
    final profitAsync = ref.watch(userProfitFutureProvider(widget.user.id));
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return walletAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (wallet) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userWalletFutureProvider(widget.user.id));
            ref.invalidate(userSalesFutureProvider(widget.user.id));
            ref.invalidate(userProfitFutureProvider(widget.user.id));
            ref.invalidate(bookingsFutureProvider);
            await Future.wait([
              ref.read(userWalletFutureProvider(widget.user.id).future),
              ref.read(userSalesFutureProvider(widget.user.id).future),
              ref.read(userProfitFutureProvider(widget.user.id).future),
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
                        color:
                            transaction.amount >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(transaction.description),
                    subtitle: Text(
                      formatter.format(transaction.createdAt),
                    ),
                    trailing: Text(
                      '${transaction.amount.toStringAsFixed(2)} ₽',
                      style: TextStyle(
                        color:
                            transaction.amount >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                isSelected: List.generate(2, (index) => index == _sectionIndex),
                onPressed: (index) => setState(() => _sectionIndex = index),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Продажи'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Прибыль'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_sectionIndex == 0) ...[
                Text(
                  'Продажи',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                salesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
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
                                    formatter
                                        .format(booking.excursion.dateTime),
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
              ] else ...[
                Text(
                  'Прибыль',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                profitAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Ошибка загрузки: $error'),
                  ),
                  data: (profit) {
                    if (profit.breakdown.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Прибыль пока не рассчитана'),
                      );
                    }

                    final totalsTiles = profit.totalsByType.entries
                        .map(
                          (entry) => ListTile(
                            title: Text(entry.key.label),
                            subtitle: Text(
                              'Продажи: ${entry.value.sales.toStringAsFixed(2)} ₽',
                            ),
                            trailing: Text(
                              '+${entry.value.commission.toStringAsFixed(2)} ₽',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        )
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: ListTile(
                            title: const Text('Общая прибыль'),
                            subtitle: Text(
                              profit.isPartner
                                  ? 'Партнёрская комиссия'
                                  : '10% от продаж',
                            ),
                            trailing: Text(
                              '${profit.totalProfit.toStringAsFixed(2)} ₽',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: Colors.green),
                            ),
                          ),
                        ),
                        if (totalsTiles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                const ListTile(
                                  title: Text('Итого по категориям'),
                                ),
                                const Divider(height: 1),
                                ...totalsTiles,
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ...profit.breakdown.map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(item.excursion.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatter.format(item.excursion.dateTime),
                                  ),
                                  Text(item.passengerType.label),
                                  Text(
                                    'Продажа: ${item.price.toStringAsFixed(2)} ₽',
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${item.commissionAmount.toStringAsFixed(2)} ₽',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${item.commissionPercent.toStringAsFixed(1)} %',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
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
                                  title:
                                      Text('Место ${booking.seat.seatNumber}'),
                                  subtitle: Text(
                                    'Бронировано: ${formatter.format(booking.bookedAt)}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.cancel),
                                    tooltip: 'Отменить',
                                    onPressed: () => _cancelBooking(
                                      context,
                                      booking.id,
                                    ),
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

  Future<void> _cancelBooking(BuildContext context, int bookingId) async {
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
      ref.invalidate(userWalletFutureProvider(widget.user.id));
      ref.invalidate(userSalesFutureProvider(widget.user.id));
      ref.invalidate(userProfitFutureProvider(widget.user.id));
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
