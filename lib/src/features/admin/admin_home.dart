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
import 'widgets/seat_permissions_tab.dart';
import 'widgets/seat_access_requests_tab.dart';

enum StaffIndicatorMode { combined, split }

final staffIndicatorModeProvider =
    StateProvider<StaffIndicatorMode>((ref) => StaffIndicatorMode.combined);

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
              Tab(text: 'Статистика'),
              Tab(text: 'Сотрудники'),
            ],
          ),
        ),
        drawer: _AdminDrawer(user: user),
        body: TabBarView(
          children: [
            _AdminBookingTab(user: user),
            const _AdminStatisticsTab(),
            UsersTab(currentUserId: user.id),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffIndicatorMode = ref.watch(staffIndicatorModeProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Администратор',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Кошелёк'),
            onTap: () {
              Navigator.of(context).pop();
              _showPage(context, _AdminWalletTab(user: user));
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Расписание'),
            onTap: () {
              Navigator.of(context).pop();
              _showPage(context, const _AdminScheduleTab());
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_ruble),
            title: const Text('Цены'),
            onTap: () {
              Navigator.of(context).pop();
              _showPage(context, const PricesTab());
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Разрешения на места 1-2'),
            onTap: () {
              Navigator.of(context).pop();
              _showPage(context, const SeatPermissionsTab());
            },
          ),
          ListTile(
            leading: const Icon(Icons.request_quote),
            title: const Text('Запросы доступа'),
            onTap: () {
              Navigator.of(context).pop();
              _showPage(context, const SeatAccessRequestsTab());
            },
          ),
          const Divider(),
          ListTile(
            dense: true,
            title: Text(
              'Настройки',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.people_alt_outlined),
            title: const Text('Отдельные иконки водителей/гидов'),
            subtitle: const Text('Показывать два индикатора вместо общей суммы'),
            value: staffIndicatorMode == StaffIndicatorMode.split,
            onChanged: (value) {
              ref.read(staffIndicatorModeProvider.notifier).state =
                  value ? StaffIndicatorMode.split : StaffIndicatorMode.combined;
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            onTap: () {
              Navigator.of(context).pop();
              showAboutDialog(
                context: context,
                applicationName: 'Система управления экскурсиями',
                applicationVersion: '1.0.0',
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выход'),
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  void _showPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Администратор'),
                ),
                body: page,
              )),
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

class _NewBookingSubTabState extends ConsumerState<_NewBookingSubTab>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
        ),
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Сбросить фильтр'),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          ),
        Expanded(
          child: excursionsAsync.when(
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

              // Разделяем на актуальные и прошедшие (с учётом времени)
              final now = DateTime.now();
              final upcomingExcursions = <Excursion>[];
              final pastExcursions = <Excursion>[];

              for (final excursion in filteredExcursions) {
                if (excursion.dateTime.isAfter(now)) {
                  upcomingExcursions.add(excursion);
                } else {
                  pastExcursions.add(excursion);
                }
              }

              upcomingExcursions.sort((a, b) => a.dateTime.compareTo(b.dateTime));
              pastExcursions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

              final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');
              final timeFormatter = DateFormat('HH:mm');

              Widget buildExcursionList(List<Excursion> items, String emptyMessage) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(emptyMessage, textAlign: TextAlign.center),
                  );
                }

                // Группируем по датам
                final groups = <DateTime, List<Excursion>>{};
                for (final excursion in items) {
                  final key = DateTime(
                    excursion.dateTime.year,
                    excursion.dateTime.month,
                    excursion.dateTime.day,
                  );
                  groups.putIfAbsent(key, () => []).add(excursion);
                }
                final sortedDates = groups.keys.toList()..sort((a, b) => items == pastExcursions ? b.compareTo(a) : a.compareTo(b));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final dayItems = groups[date]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          dateFormatter.format(date),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        subtitle: Text(
                            '${dayItems.length} ${dayItems.length == 1 ? 'экскурсия' : dayItems.length < 5 ? 'экскурсии' : 'экскурсий'}'),
                        children: dayItems
                            .map((excursion) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: _AdminExcursionCard(
                                    excursion: excursion,
                                    formatter: timeFormatter,
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  },
                );
              }

              return Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Актуальные (${upcomingExcursions.length})'),
                      Tab(text: 'Прошедшие (${pastExcursions.length})'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          child: buildExcursionList(upcomingExcursions, 'Нет актуальных экскурсий'),
                        ),
                        SingleChildScrollView(
                          child: buildExcursionList(pastExcursions, 'Нет прошедших экскурсий'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MyBookingsSubTab extends ConsumerStatefulWidget {
  const _MyBookingsSubTab({required this.user});

  final User user;

  @override
  ConsumerState<_MyBookingsSubTab> createState() => _MyBookingsSubTabState();
}

class _MyBookingsSubTabState extends ConsumerState<_MyBookingsSubTab>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
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

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
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

        // Разделяем на новые (будущие) и старые (прошедшие)
        final now = DateTime.now();
        final newGroups = <BookingGroup>[];
        final oldGroups = <BookingGroup>[];

        for (final group in myGroups) {
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

        // Фильтруем по выбранной дате
        final filterByDate = (List<BookingGroup> groups) {
          if (_selectedDate == null) return groups;
          return groups.where((group) {
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
        };

        final filteredNewGroups = filterByDate(newGroups);
        final filteredOldGroups = filterByDate(oldGroups);

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

        final newDateGroups = groupByDate(filteredNewGroups);
        final oldDateGroups = groupByDate(filteredOldGroups);
        final sortedNewDates = newDateGroups.keys.toList()..sort();
        final sortedOldDates = oldDateGroups.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final subFormatter = DateFormat('dd.MM.yyyy HH:mm');
        final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');
        final timeFormatter = DateFormat('HH:mm');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Сбросить фильтр'),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                    });
                  },
                ),
              ),
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
                    subFormatter,
                    'Нет ваших новых бронирований',
                  ),
                  _buildBookingsList(
                    context,
                    ref,
                    sortedOldDates,
                    oldDateGroups,
                    dateFormatter,
                    timeFormatter,
                    subFormatter,
                    'Нет ваших прошедших бронирований',
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
                // Собираем уникальные имена пользователей, которые забронировали места
                final bookedByNames = group.bookings
                    .where((b) => b.bookedByName != null && b.bookedByName!.isNotEmpty)
                    .map((b) => b.bookedByName!)
                    .toSet()
                    .toList();
                
                final bookedByText = bookedByNames.isNotEmpty
                    ? ' • ${bookedByNames.join(', ')}'
                    : '';
                
                // Группируем места по сотрудникам, которые их забронировали
                final bookingsByUser = <String, List<BookingItem>>{};
                for (final booking in group.bookings) {
                  final userName = booking.bookedByName?.isNotEmpty == true
                      ? booking.bookedByName!
                      : 'Неизвестный';
                  bookingsByUser.putIfAbsent(userName, () => []).add(booking);
                }

                return ExpansionTile(
                  title: Text(group.excursion.title),
                  subtitle: Text(
                    '${timeFormatter.format(group.excursion.dateTime)}$bookedByText • ${group.bookings.length} мест${group.bookings.length > 1 ? 'а' : ''}${group.excursion.maxSeats != null ? ' из ${group.excursion.maxSeats}' : ''}',
                  ),
                  children: [
                    // Группируем по сотрудникам
                    ...bookingsByUser.entries.map(
                      (entry) {
                        final isLastGroup = entry == bookingsByUser.entries.last;
                        return Column(
                          children: [
                            // Сворачиваемая группа по сотруднику
                            ExpansionTile(
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                '${entry.key} — ${entry.value.length} мест${entry.value.length > 1 ? 'а' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              children: entry.value
                                  .map(
                                    (booking) => ListTile(
                                      dense: true,
                                      title:
                                          Text('Место ${booking.seat.seatNumber}'),
                                      subtitle: Text(
                                          'Бронировано: ${subFormatter.format(booking.bookedAt)}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.cancel),
                                        tooltip: 'Отменить',
                                        onPressed: () => _cancelBooking(
                                            context, ref, booking.id),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            // Разделитель между группами (кроме последней)
                            if (!isLastGroup)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        }).toList(),
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

class _AllBookingsSubTabState extends ConsumerState<_AllBookingsSubTab>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
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

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Не удалось загрузить бронирования: $error'),
      ),
      data: (groups) {
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

        // Фильтруем по выбранной дате
        final filterByDate = (Map<DateTime, List<BookingGroup>> dateGroups) {
          if (_selectedDate == null) return dateGroups;
          final selectedDateOnly = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
          );
          return dateGroups.entries
              .where((entry) => entry.key == selectedDateOnly)
              .fold<Map<DateTime, List<BookingGroup>>>(
            {},
            (map, entry) => map..[entry.key] = entry.value,
          );
        };

        final filteredNewDateGroups =
            _selectedDate == null ? newDateGroups : filterByDate(newDateGroups);
        final filteredOldDateGroups =
            _selectedDate == null ? oldDateGroups : filterByDate(oldDateGroups);

        final subFormatter = DateFormat('dd.MM.yyyy HH:mm');
        final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');
        final timeFormatter = DateFormat('HH:mm');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Сбросить фильтр'),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                    });
                  },
                ),
              ),
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
                    sortedNewDates
                        .where(
                            (date) => filteredNewDateGroups.containsKey(date))
                        .toList(),
                    filteredNewDateGroups,
                    dateFormatter,
                    timeFormatter,
                    subFormatter,
                    'Нет новых бронирований',
                  ),
                  _buildBookingsList(
                    context,
                    ref,
                    sortedOldDates
                        .where(
                            (date) => filteredOldDateGroups.containsKey(date))
                        .toList(),
                    filteredOldDateGroups,
                    dateFormatter,
                    timeFormatter,
                    subFormatter,
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
                // Собираем уникальные имена пользователей, которые забронировали места
                final bookedByNames = group.bookings
                    .where((b) => b.bookedByName != null && b.bookedByName!.isNotEmpty)
                    .map((b) => b.bookedByName!)
                    .toSet()
                    .toList();
                
                final bookedByText = bookedByNames.isNotEmpty
                    ? ' • ${bookedByNames.join(', ')}'
                    : '';
                
                // Группируем места по сотрудникам, которые их забронировали
                final bookingsByUser = <String, List<BookingItem>>{};
                for (final booking in group.bookings) {
                  final userName = booking.bookedByName?.isNotEmpty == true
                      ? booking.bookedByName!
                      : 'Неизвестный';
                  bookingsByUser.putIfAbsent(userName, () => []).add(booking);
                }

                return ExpansionTile(
                  title: Text(group.excursion.title),
                  subtitle: Text(
                    '${timeFormatter.format(group.excursion.dateTime)}$bookedByText • ${group.bookings.length} мест${group.bookings.length > 1 ? 'а' : ''}${group.excursion.maxSeats != null ? ' из ${group.excursion.maxSeats}' : ''}',
                  ),
                  children: [
                    // Группируем по сотрудникам
                    ...bookingsByUser.entries.map(
                      (entry) {
                        final isLastGroup = entry == bookingsByUser.entries.last;
                        return Column(
                          children: [
                            ExpansionTile(
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                '${entry.key} — ${entry.value.length} мест${entry.value.length > 1 ? 'а' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              children: entry.value
                                  .map(
                                    (booking) => ListTile(
                                      title:
                                          Text('Место ${booking.seat.seatNumber}'),
                                      subtitle: Text(
                                          'Бронировано: ${subFormatter.format(booking.bookedAt)}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.cancel),
                                        tooltip: 'Отменить',
                                        onPressed: () => _cancelBooking(
                                            context, ref, booking.id),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            // Разделитель между группами (кроме последней)
                            if (!isLastGroup)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        }).toList(),
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
  const _AdminExcursionCard({
    required this.excursion,
    required this.formatter,
  });

  final Excursion excursion;
  final DateFormat formatter;

  /// Фильтрует персонал по дате/времени экскурсии
  List<ExcursionStaff> get _filteredStaff {
    final targetDate = DateFormat('yyyy-MM-dd').format(excursion.dateTime);
    final targetTime = DateFormat('HH:mm').format(excursion.dateTime);
    
    return excursion.assignedStaff.where((staff) {
      // Показываем назначения без даты (на все даты) или с совпадающей датой
      final matchesDate = staff.excursionDate == null || staff.excursionDate == targetDate;
      final matchesTime = staff.time == null || staff.time == targetTime;
      return matchesDate && matchesTime;
    }).toList();
  }

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${excursion.title} — ${formatter.format(excursion.dateTime)}   ' +
                              '${excursion.availableSeatsCount}/${excursion.maxSeats}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                  ),
                        ),
                      ),
                      if (_filteredStaff.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: _buildStaffIndicators(context, ref),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 4),
                IconButton(
              icon: const Icon(Icons.event_seat, size: 20),
                  tooltip: 'Забронировать',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
                  onPressed: () => _book(context, ref),
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
                IconButton(
              icon: const Icon(Icons.person_add, size: 20),
                  tooltip: 'Назначить персонал',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
                  onPressed: () => _assignStaff(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStaffIndicators(BuildContext context, WidgetRef ref) {
    final staff = _filteredStaff;
    if (staff.isEmpty) return [];

    final mode = ref.watch(staffIndicatorModeProvider);
    final drivers =
        staff.where((member) => member.roleInExcursion == 'driver').toList();
    final guides =
        staff.where((member) => member.roleInExcursion == 'guide').toList();
    final others = staff
        .where((member) =>
            member.roleInExcursion != 'driver' &&
            member.roleInExcursion != 'guide')
        .toList();

    if (mode == StaffIndicatorMode.combined) {
      final totalCount = staff.length;
      return [
        _buildStaffChip(
          context: context,
          staff: staff,
          tooltip: 'Назначено: $totalCount',
          icon: Icons.people,
          color: Colors.blue,
          countLabel: '$totalCount',
        ),
      ];
    }

    final chips = <Widget>[
      if (drivers.isNotEmpty)
        _buildStaffChip(
          context: context,
          staff: drivers,
          tooltip: 'Водители: ${drivers.length}',
          icon: Icons.directions_bus,
          color: Colors.indigo,
          countLabel: '${drivers.length}',
        ),
      if (guides.isNotEmpty)
        _buildStaffChip(
          context: context,
          staff: guides,
          tooltip: 'Экскурсоводы: ${guides.length}',
          icon: Icons.record_voice_over,
          color: Colors.teal,
          countLabel: '${guides.length}',
        ),
      if (others.isNotEmpty)
        _buildStaffChip(
          context: context,
          staff: others,
          tooltip: 'Другой персонал: ${others.length}',
          icon: Icons.people_outline,
          color: Colors.blueGrey,
          countLabel: '${others.length}',
        ),
    ];

    // На случай необычных ролей — хотя бы общий индикатор
    return chips.isNotEmpty
        ? chips
        : [
            _buildStaffChip(
              context: context,
              staff: staff,
              tooltip: 'Назначено: ${staff.length}',
              icon: Icons.people,
              color: Colors.blue,
              countLabel: '${staff.length}',
            ),
          ];
  }

  Widget _buildStaffChip({
    required BuildContext context,
    required List<ExcursionStaff> staff,
    required String tooltip,
    required IconData icon,
    required Color color,
    required String countLabel,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _showAllStaffDialog(context, staff),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  countLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllStaffDialog(BuildContext context, List<ExcursionStaff> staff) {
    final staffByRole = <String, List<ExcursionStaff>>{};
    for (final member in staff) {
      staffByRole.putIfAbsent(member.roleInExcursion, () => []).add(member);
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.blueGrey.shade700),
            const SizedBox(width: 8),
            const Text('Назначенный персонал'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: staffByRole.entries.map((entry) {
              final role = entry.key;
              final members = entry.value;
              final label = _roleLabel(role);
              final icon = _roleIcon(role);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: Colors.blueGrey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '$label (${members.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
                      child: Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
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

  IconData _roleIcon(String role) {
    switch (role) {
      case 'driver':
        return Icons.directions_bus;
      case 'guide':
        return Icons.record_voice_over;
      default:
        return Icons.person;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'driver':
        return 'Водители';
      case 'guide':
        return 'Экскурсоводы';
      default:
        return 'Персонал';
    }
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
      // Извлекаем weekday, time и конкретную дату из dateTime экскурсии
      // DateTime.weekday возвращает ISO weekday (1 = Monday, 7 = Sunday)
      final weekday = excursion.dateTime.weekday; // 1-7
      final time = DateFormat('HH:mm').format(excursion.dateTime);
      final excursionDate = DateFormat('yyyy-MM-dd').format(excursion.dateTime);
      
      // Используем новый формат если доступен, иначе старый
      final payload = result.seats != null && result.seats!.isNotEmpty
          ? BookSeatPayload(
              excursionId: excursion.id,
              seats: result.seats!,
              customerName: result.customerName,
              customerPhone: result.customerPhone,
              stopId: result.stopId,
              weekday: weekday,
              time: time,
              excursionDate: excursionDate,
            )
          : BookSeatPayload(
              excursionId: excursion.id,
              seatNumbers: result.seatNumbers,
              customerName: result.customerName,
              customerPhone: result.customerPhone,
              passengerType: result.passengerType,
              stopId: result.stopId,
              weekday: weekday,
              time: time,
              excursionDate: excursionDate,
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
          // Получаем все ID бронирований из ответа
          final allBookingIds = response.bookings
              ?.map((b) => b['id'] as int?)
              .whereType<int>()
              .toList();
          
          // Логируем для отладки
          print('PDF generation: bookingId=$bookingId');
          print('PDF generation: bookings response=${response.bookings}');
          print('PDF generation: allBookingIds=$allBookingIds, count=${allBookingIds?.length ?? 0}');
          
          // Проверяем, что список не пустой
          if (allBookingIds == null || allBookingIds.isEmpty) {
            print('WARNING: allBookingIds is null or empty! Using single bookingId: $bookingId');
          }
          
          // Скачиваем PDF как байты, передавая все ID бронирований
          final pdfBytes = await ref
              .read(bookingsRepositoryProvider)
              .downloadTicketPdf(
                bookingId,
                bookingIds: allBookingIds?.isNotEmpty == true ? allBookingIds : null,
              );
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
        try {
          final statistics = (data['statistics'] as List<dynamic>?) ?? [];
          final totalNetProfit = (data['total_net_profit'] as num?)?.toDouble() ?? 0.0;

          if (statistics.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_statisticsFutureProvider);
                await ref.read(_statisticsFutureProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: const Center(child: Text('Нет данных для отображения')),
                ),
              ),
            );
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
                  try {
                    final excursion = (stat['excursion'] as Map<String, dynamic>?) ?? {};
                    final dateTimeStr = excursion['date_time'] as String?;
                    if (dateTimeStr == null) {
                      return const SizedBox.shrink();
                    }
                    final dateTime = DateTime.parse(dateTimeStr);
                    final netProfit = ((stat['net_profit'] as num?)?.toDouble()) ?? 0.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(
                      netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: netProfit >= 0 ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      (excursion['title'] as String?) ?? 'Без названия',
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
                                  '${(((stat['income'] as num?)?.toDouble()) ?? ((stat['total_revenue'] as num?)?.toDouble()) ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.blue,
                            ),
                            _StatRow(
                              label: 'Продано билетов',
                              value: '${(stat['bookings_count'] as num?)?.toInt() ?? 0} шт.',
                              color: Colors.grey,
                            ),
                            const Divider(),
                            _StatRow(
                              label: 'Минус: Заплатили продавцам',
                              value:
                                  '-${((stat['seller_commissions'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.orange,
                            ),
                            _StatRow(
                              label: 'Минус: Заплатили водителям',
                              value:
                                  '-${((stat['driver_costs'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            _StatRow(
                              label: 'Минус: Заплатили экскурсоводам',
                              value:
                                  '-${((stat['guide_costs'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            _StatRow(
                              label: 'Всего расходы на персонал',
                              value:
                                  '-${((stat['staff_costs'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} ₽',
                              color: Colors.purple,
                            ),
                            const Divider(),
                            _StatRow(
                              label: 'Чистая прибыль',
                              value:
                                  '${netProfit.toStringAsFixed(2)} ₽',
                              color: netProfit >= 0
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
                  } catch (e) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: const Text('Ошибка отображения данных'),
                        subtitle: Text('$e'),
                      ),
                    );
                  }
                }).toList(),
              ],
            ),
          );
        } catch (e) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_statisticsFutureProvider);
              await ref.read(_statisticsFutureProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Ошибка обработки данных: $e'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(_statisticsFutureProvider),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
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
