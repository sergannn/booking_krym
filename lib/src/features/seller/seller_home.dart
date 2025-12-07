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
import '../admin/widgets/prices_tab.dart';

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
      const _PricesTab(),
      const _ScheduleTab(),
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
          NavigationDestination(
              icon: Icon(Icons.currency_ruble), label: 'Цены'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today), label: 'Расписание'),
        ],
      ),
    );
  }
}

class _ExcursionsTab extends ConsumerWidget {
  const _ExcursionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    if (user == null) return const SizedBox.shrink();
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final timeFormatter = DateFormat('HH:mm');
    final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');

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
                date: dateFormatter.format(date),
                excursions: dayItems,
                formatter: timeFormatter,
                user: user,
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
    required this.user,
  });

  final String date;
  final List<Excursion> excursions;
  final DateFormat formatter;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          date,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${excursions.length} ${excursions.length == 1 ? 'экскурсия' : excursions.length < 5 ? 'экскурсии' : 'экскурсий'}'),
        children: [
          for (final excursion in excursions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _ExcursionTile(
                excursion: excursion,
                formatter: formatter,
                user: user,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExcursionTile extends ConsumerWidget {
  const _ExcursionTile({
    required this.excursion,
    required this.formatter,
    required this.user,
  });

  final Excursion excursion;
  final DateFormat formatter;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Определяем, доступна ли экскурсия для бронирования
    final isAvailable = excursion.availableSeatsCount > 0 && !excursion.isPast;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isAvailable
          ? null
          : Colors.grey.shade200, // Серый фон для недоступных
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${excursion.title} — ${formatter.format(excursion.dateTime)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Цена (взрослый): ${excursion.priceFor('adult').toStringAsFixed(2)} ₽, Мест: ${excursion.availableSeatsCount}/${excursion.maxSeats}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.event_seat, size: 20),
              tooltip: 'Забронировать',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: isAvailable ? () => _book(context, ref) : null,
              color: isAvailable
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.list, size: 20),
              tooltip: 'Места',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: excursion.busSeats.isEmpty
                  ? null
                  : () => _showSeatSheet(context, ref),
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
                  // Места 1 и 2 могут продавать только администраторы (roleId == 1)
                  final isRestrictedSeat = [1, 2].contains(seat.seatNumber);
                  final isAdmin = user.roleId == 1 || user.isSuperUser;
                  final canSelect =
                      isAvailable && (!isRestrictedSeat || isAdmin);
                  final color = isSelected
                      ? Colors.blue.shade300
                      : canSelect
                          ? Colors.green.shade200
                          : isRestrictedSeat
                              ? Colors.orange.shade200
                              : Colors.red.shade200;
                  return InkWell(
                    onTap: canSelect
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

class _BookingsTab extends ConsumerStatefulWidget {
  const _BookingsTab();

  @override
  ConsumerState<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<_BookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorMessage(message: '$error'),
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(child: Text('Вы ещё не бронировали места'));
        }

        // Разделяем на новые (будущие) и старые (прошедшие)
        final now = DateTime.now();
        final newGroups = <BookingGroup>[];
        final oldGroups = <BookingGroup>[];

        for (final group in groups) {
          if (group.excursion.dateTime.isAfter(now)) {
            newGroups.add(group);
          } else {
            oldGroups.add(group);
          }
        }

        // Сортируем внутри групп по датам
        newGroups.sort(
            (a, b) => a.excursion.dateTime.compareTo(b.excursion.dateTime));
        oldGroups.sort(
            (a, b) => b.excursion.dateTime.compareTo(a.excursion.dateTime));

        // Группируем по датам экскурсий
        final groupByDate = (List<BookingGroup> groups) {
          final dateGroups = <DateTime, List<BookingGroup>>{};
          for (final group in groups) {
            final date = DateTime(
              group.excursion.dateTime.year,
              group.excursion.dateTime.month,
              group.excursion.dateTime.day,
            );
            dateGroups.putIfAbsent(date, () => []).add(group);
          }
          return dateGroups;
        };

        final newDateGroups = groupByDate(newGroups);
        final oldDateGroups = groupByDate(oldGroups);
        final sortedNewDates = newDateGroups.keys.toList()..sort();
        final sortedOldDates = oldDateGroups.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');
        final timeFormatter = DateFormat('HH:mm');

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Новые'),
                Tab(text: 'Прошедшие'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingsList(
                    context,
                    ref,
                    sortedNewDates,
                    newDateGroups,
                    dateFormatter,
                    timeFormatter,
                    formatter,
                    'Нет новых бронирований',
                  ),
                  _buildBookingsList(
                    context,
                    ref,
                    sortedOldDates,
                    oldDateGroups,
                    dateFormatter,
                    timeFormatter,
                    formatter,
                    'Нет прошедших бронирований',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookingsList(
    BuildContext context,
    WidgetRef ref,
    List<DateTime> sortedDates,
    Map<DateTime, List<BookingGroup>> dateGroups,
    DateFormat dateFormatter,
    DateFormat timeFormatter,
    DateFormat subFormatter,
    String emptyMessage,
  ) {
    if (dateGroups.isEmpty || sortedDates.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bookingsFutureProvider);
          await ref.read(bookingsFutureProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(emptyMessage),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsFutureProvider);
        await ref.read(bookingsFutureProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: sortedDates.map((date) {
          final groups = dateGroups[date]!;
          final totalBookings =
              groups.fold<int>(0, (sum, g) => sum + g.bookings.length);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                dateFormatter.format(date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              subtitle: Text(
                  '$totalBookings ${totalBookings == 1 ? 'бронирование' : totalBookings < 5 ? 'бронирования' : 'бронирований'}'),
              children: groups.map((group) {
                return ExpansionTile(
                  title: Text(group.excursion.title),
                  subtitle: Text(
                    '${timeFormatter.format(group.excursion.dateTime)} • ${group.bookings.length} место${group.bookings.length > 1 ? 'а' : ''}${group.excursion.maxSeats != null ? ' из ${group.excursion.maxSeats}' : ''}',
                  ),
                  children: group.bookings
                      .map(
                        (booking) => ListTile(
                          title: Text('Место ${booking.seat.seatNumber}'),
                          subtitle: Text(
                              'Бронировано: ${subFormatter.format(booking.bookedAt)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            tooltip: 'Отменить',
                            onPressed: () => _cancel(context, ref, booking.id),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
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

class _PricesTab extends ConsumerWidget {
  const _PricesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PricesTab();
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleFutureProvider);

    return scheduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка загрузки расписания: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(scheduleFutureProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
      data: (templates) {
        if (templates.isEmpty) {
          return const Center(
            child: Text('Расписание пока не настроено'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(scheduleFutureProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    template.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: template.description.isNotEmpty
                      ? Text(
                          template.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  children: [
                    if (template.description.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          template.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const Divider(),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Расписание по дням недели:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          if (template.schedule.isEmpty)
                            const Text(
                              'Расписание не задано',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            )
                          else
                            ...template.schedule.map((day) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        day.dayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      day.time,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
