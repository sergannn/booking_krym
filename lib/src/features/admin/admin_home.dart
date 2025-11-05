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
import '../common/utils/ticket_generator.dart';
import '../common/widgets/cancellation_reason_dialog.dart';
import 'widgets/users_tab.dart';
import 'widgets/assign_staff_sheet.dart';
import 'widgets/prices_tab.dart';

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
            _AdminWalletTab(user: user),
            _PlaceholderTab(message: 'Статистика в разработке'),
            const _AdminScheduleTab(),
            UsersTab(currentUserId: user.id),
            const PricesTab(),
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
            Text(
              'Цена (взрослый): ${excursion.priceFor('adult').toStringAsFixed(2)} ₽',
            ),
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
                      : () => _showSeatSheet(context, ref),
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

  Future<void> _book(
    BuildContext context,
    WidgetRef ref, {
    List<int>? preselectedSeats,
  }) async {
    final stops = await ref.read(stopsFutureProvider.future);
    final result = await showDialog<BookingDialogResult>(
      context: context,
      builder: (dialogContext) => BookingDialog(
        stops: stops,
        tariffs: excursion.tariffs,
        initialSeatNumbers: preselectedSeats ?? const [],
        lockSeatSelection: (preselectedSeats?.isNotEmpty ?? false),
      ),
    );

    if (result == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

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
      if (!context.mounted) {
        return;
      }
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
      final bookedBy = authState.value?.name ?? 'Администратор';
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
                final color =
                    isAvailable ? Colors.green.shade200 : Colors.red.shade200;
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

class _AdminWalletTab extends ConsumerStatefulWidget {
  const _AdminWalletTab({required this.user});

  final User user;

  @override
  ConsumerState<_AdminWalletTab> createState() => _AdminWalletTabState();
}

class _AdminWalletTabState extends ConsumerState<_AdminWalletTab> {
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
      error: (error, _) => Center(child: Text('Ошибка: $error')),
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
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Ошибка: $error'),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Нет активных бронирований'),
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

  Future<void> _cancelBooking(
    BuildContext context,
    int bookingId,
  ) async {
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

class _AdminScheduleTab extends ConsumerWidget {
  const _AdminScheduleTab();

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
