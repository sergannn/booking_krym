import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models/excursion.dart';
import '../../data/models/user.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/providers.dart';
import '../../core/api/api_helpers.dart';
import '../auth/auth_controller.dart';
import '../seller/widgets/booking_dialog.dart';
import '../common/utils/pdf_downloader.dart';
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
            _AdminBookingTab(user: user),
            _AdminWalletTab(user: user),
            const _AdminStatisticsTab(),
            const _AdminScheduleTab(),
            UsersTab(currentUserId: user.id),
            const PricesTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminBookingTab extends ConsumerStatefulWidget {
  const _AdminBookingTab({required this.user});

  final User user;

  @override
  ConsumerState<_AdminBookingTab> createState() => _AdminBookingTabState();
}

class _AdminBookingTabState extends ConsumerState<_AdminBookingTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Новое бронирование'),
              Tab(text: 'Мои бронирования'),
              Tab(text: 'Бронирования'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _NewBookingSubTab(user: widget.user),
                _MyBookingsSubTab(user: widget.user),
                _AllBookingsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBookingSubTab extends ConsumerStatefulWidget {
  const _NewBookingSubTab({required this.user});

  final User user;

  @override
  ConsumerState<_NewBookingSubTab> createState() => _NewBookingSubTabState();
}

class _NewBookingSubTabState extends ConsumerState<_NewBookingSubTab> {
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(excursionsFutureProvider);
        await ref.read(excursionsFutureProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Новое бронирование',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _selectedDate == null
                      ? 'Выбрать дату'
                      : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Сбросить фильтр'),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          excursionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Не удалось загрузить экскурсии: $error'),
            ),
            data: (excursions) {
              // Фильтруем по выбранной дате
              final filteredExcursions = _selectedDate == null
                  ? excursions
                  : excursions.where((excursion) {
                      final excursionDate = DateTime(
                        excursion.dateTime.year,
                        excursion.dateTime.month,
                        excursion.dateTime.day,
                      );
                      final selectedDateOnly = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                      );
                      return excursionDate == selectedDateOnly;
                    }).toList();

              // Показываем только будущие экскурсии
              final futureExcursions = filteredExcursions
                  .where((excursion) => !excursion.isPast)
                  .toList()
                ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

              if (futureExcursions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _selectedDate == null
                        ? 'Нет доступных экскурсий для бронирования'
                        : 'Нет доступных экскурсий на выбранную дату',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: futureExcursions.length,
                itemBuilder: (context, index) {
                  final excursion = futureExcursions[index];
                  return _AdminExcursionCard(
                    excursion: excursion,
                    formatter: formatter,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MyBookingsSubTab extends ConsumerStatefulWidget {
  const _MyBookingsSubTab({required this.user});

  final User user;

  @override
  ConsumerState<_MyBookingsSubTab> createState() => _MyBookingsSubTabState();
}

class _MyBookingsSubTabState extends ConsumerState<_MyBookingsSubTab> {
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsFutureProvider);
        await ref.read(bookingsFutureProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Мои бронирования',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _selectedDate == null
                      ? 'Выбрать дату'
                      : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Сбросить фильтр'),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          ],
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
              // Фильтруем только бронирования текущего пользователя
              final myGroups = groups
                  .map((group) {
                    final myBookings = group.bookings
                        .where((booking) => booking.bookedBy == widget.user.id)
                        .toList();
                    if (myBookings.isEmpty) return null;
                    return BookingGroup(
                      excursion: group.excursion,
                      bookings: myBookings,
                    );
                  })
                  .whereType<BookingGroup>()
                  .toList();

              // Фильтруем по выбранной дате
              final filteredGroups = _selectedDate == null
                  ? myGroups
                  : myGroups.where((group) {
                      final excursionDate = DateTime(
                        group.excursion.dateTime.year,
                        group.excursion.dateTime.month,
                        group.excursion.dateTime.day,
                      );
                      final selectedDateOnly = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                      );
                      return excursionDate == selectedDateOnly;
                    }).toList();

              if (filteredGroups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _selectedDate == null
                        ? 'Нет ваших бронирований'
                        : 'Нет ваших бронирований на выбранную дату',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredGroups.length,
                itemBuilder: (context, index) {
                  final group = filteredGroups[index];
                  final subFormatter = DateFormat('dd.MM.yyyy HH:mm');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(group.excursion.title),
                      subtitle: Text(
                        '${subFormatter.format(group.excursion.dateTime)} • ${group.bookings.length} мест',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: group.bookings
                          .map(
                            (booking) => ListTile(
                              title: Text('Место ${booking.seat.seatNumber}'),
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

class _AllBookingsSubTab extends ConsumerStatefulWidget {
  const _AllBookingsSubTab();

  @override
  ConsumerState<_AllBookingsSubTab> createState() => _AllBookingsSubTabState();
}

class _AllBookingsSubTabState extends ConsumerState<_AllBookingsSubTab> {
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsFutureProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsFutureProvider);
        await ref.read(bookingsFutureProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Все бронирования',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _selectedDate == null
                      ? 'Выбрать дату'
                      : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Сбросить фильтр'),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          ],
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
              // Фильтруем по выбранной дате
              final filteredGroups = _selectedDate == null
                  ? groups
                  : groups.where((group) {
                      final excursionDate = DateTime(
                        group.excursion.dateTime.year,
                        group.excursion.dateTime.month,
                        group.excursion.dateTime.day,
                      );
                      final selectedDateOnly = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                      );
                      return excursionDate == selectedDateOnly;
                    }).toList();

              if (filteredGroups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _selectedDate == null
                        ? 'Нет активных бронирований'
                        : 'Нет бронирований на выбранную дату',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredGroups.length,
                itemBuilder: (context, index) {
                  final group = filteredGroups[index];
                  final subFormatter = DateFormat('dd.MM.yyyy HH:mm');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(group.excursion.title),
                      subtitle: Text(
                        '${subFormatter.format(group.excursion.dateTime)} • ${group.bookings.length} мест',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: group.bookings
                          .map(
                            (booking) => ListTile(
                              title: Text('Место ${booking.seat.seatNumber}'),
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
            Text(excursion.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Дата: ${formatter.format(excursion.dateTime)}'),
            Text(
              'Цена (взрослый): ${excursion.priceFor('adult').toStringAsFixed(2)} ₽',
            ),
            Text(
                'Свободно мест: ${excursion.availableSeatsCount} / ${excursion.maxSeats}'),
            Text(
                'Забронировано мест: ${excursion.bookedSeatsCount} / ${excursion.maxSeats}'),
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
            // Описание скрыто для лучшей видимости
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

class _AdminStatisticsTab extends ConsumerWidget {
  const _AdminStatisticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(_statisticsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return statisticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка загрузки статистики: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(_statisticsFutureProvider),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
      data: (data) {
        final statistics = data['statistics'] as List<dynamic>;
        final totalNetProfit = data['total_net_profit'] as double;

        if (statistics.isEmpty) {
          return const Center(child: Text('Нет данных для отображения'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_statisticsFutureProvider);
            await ref.read(_statisticsFutureProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Общая чистая прибыль',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalNetProfit.toStringAsFixed(2)} ₽',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...statistics.map((stat) {
                final excursion = stat['excursion'] as Map<String, dynamic>;
                final dateTime =
                    DateTime.parse(excursion['date_time'] as String);
                final netProfit = (stat['net_profit'] as double);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(
                      netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: netProfit >= 0 ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      excursion['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${formatter.format(dateTime)} • Чистая прибыль: ${netProfit.toStringAsFixed(2)} ₽',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            _StatRow(
                              label: 'Доход (выручка от продажи билетов)',
                              value:
                                  '${((stat['income'] as double?) ?? (stat['total_revenue'] as double)).toStringAsFixed(2)} ₽',
                              color: Colors.blue,
                            ),
                            _StatRow(
                              label: 'Продано билетов',
                              value: '${stat['bookings_count'] as int} шт.',
                              color: Colors.grey,
                            ),
                            const Divider(),
                            _StatRow(
                              label: 'Минус: Заплатили продавцам',
                              value:
                                  '-${(stat['seller_commissions'] as double).toStringAsFixed(2)} ₽',
                              color: Colors.orange,
                            ),
                            _StatRow(
                              label: 'Минус: Заплатили водителям',
                              value:
                                  '-${(stat['driver_costs'] as double? ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            _StatRow(
                              label: 'Минус: Заплатили экскурсоводам',
                              value:
                                  '-${(stat['guide_costs'] as double? ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            _StatRow(
                              label: 'Всего расходы на персонал',
                              value:
                                  '-${(stat['staff_costs'] as double).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            const Divider(),
                            _StatRow(
                              label: 'Чистая прибыль',
                              value:
                                  '${(stat['net_profit'] as double).toStringAsFixed(2)} ₽',
                              color: (stat['net_profit'] as double) >= 0
                                  ? Colors.green
                                  : Colors.red,
                              isBold: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Доход - комиссии продавцам - расходы на персонал',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

final _statisticsFutureProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.getJson(
    '/api/excursions/statistics',
    authenticated: true,
  );
  return response;
});
