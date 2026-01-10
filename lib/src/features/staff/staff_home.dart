import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/models/stop.dart';
import '../../data/models/bus_seat.dart';
import '../../data/models/excursion.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';
import 'assignments_controller.dart';
import '../../core/services/internet_connection_service.dart';

final assignmentsControllerProvider =
    Provider.family<AssignmentsController, User>(
  (ref, user) {
    final assignmentsRepo = ref.watch(assignmentsRepositoryProvider);
    final controller = AssignmentsController(
      user: user,
      assignmentsRepository: assignmentsRepo,
    );
    ref.onDispose(() => controller.dispose());
    return controller;
  },
);

class StaffHomePage extends ConsumerStatefulWidget {
  const StaffHomePage({super.key, required this.user});

  final User user;

  @override
  ConsumerState<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends ConsumerState<StaffHomePage> {
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллер при открытии страницы
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentsControllerProvider(widget.user));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Определяем, водитель это или гид
    final isDriver = widget.user.roleId == 3;
    final normalizedRole = widget.user.role.trim().toLowerCase();
    final isGuide = normalizedRole.contains('гид') ||
        normalizedRole.contains('guide') ||
        normalizedRole.contains('экскурсовод');
    final showTabs = isDriver || isGuide;
    final excursionsAsync = ref.watch(
      showTabs 
          ? staffExcursionsFutureProvider(widget.user.id) 
          : excursionsFutureProvider,
    );
    final staffProfitAsync =
        ref.watch(staffProfitFutureProvider(widget.user.id));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    // Подписываемся на контроллер назначений (только для водителей и гидов)
    // Уведомления показываются автоматически в контроллере при обнаружении новых назначений
    if (isDriver || isGuide) {
      ref.watch(assignmentsControllerProvider(widget.user));
    }

    final appBarTitle = isDriver
        ? 'Кабинет водителя'
        : isGuide
            ? 'Кабинет экскурсовода'
            : 'Расписание — ${widget.user.name}';

    // Отслеживаем статус интернета
    final internetStatusAsync = ref.watch(internetStatusProvider);
    final hasInternet = internetStatusAsync.valueOrNull ?? true;
    
    // Определяем цвет фона AppBar в зависимости от статуса интернета
    final appBarColor = hasInternet 
        ? Theme.of(context).colorScheme.primary 
        : Colors.red;

    final scaffold = Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white, // Белый цвет для всех элементов AppBar
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white), // Явно указываем белый цвет
        ),
        bottom: showTabs
            ? TabBar(
                tabs: const [
                  Tab(text: 'Предстоящие'),
                  Tab(text: 'Прошедшие'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout, color: Colors.white), // Явно указываем белый цвет
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Прибыль
          if (isDriver || isGuide)
            staffProfitAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (profitData) {
                final breakdown =
                    profitData['breakdown'] as List<dynamic>? ?? [];
                
                // Фильтруем breakdown по датам
                List<dynamic> filteredBreakdown = breakdown;
                if (_selectedDateFrom != null || _selectedDateTo != null) {
                  filteredBreakdown = breakdown.where((item) {
                    final dateTime = item['date_time'] as String?;
                    if (dateTime == null || dateTime.isEmpty) {
                      return false;
                    }
                    try {
                      final date = DateTime.parse(dateTime);
                      final dateOnly = DateTime(date.year, date.month, date.day);
                      
                      if (_selectedDateFrom != null) {
                        final fromDate = DateTime(_selectedDateFrom!.year, _selectedDateFrom!.month, _selectedDateFrom!.day);
                        if (dateOnly.isBefore(fromDate)) {
                          return false;
                        }
                      }
                      if (_selectedDateTo != null) {
                        final toDate = DateTime(_selectedDateTo!.year, _selectedDateTo!.month, _selectedDateTo!.day).add(const Duration(days: 1));
                        if (dateOnly.isAfter(toDate.subtract(const Duration(seconds: 1)))) {
                          return false;
                        }
                      }
                      return true;
                    } catch (e) {
                      return false;
                    }
                  }).toList();
                }
                
                // Пересчитываем общую прибыль для отфильтрованных данных
                double filteredTotalProfit = filteredBreakdown.fold<double>(
                  0.0,
                  (sum, item) => sum + ((item['profit'] as num?)?.toDouble() ?? 0.0),
                );
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Фильтр по датам
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Фильтр по датам',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.calendar_today, size: 18),
                                      label: Text(
                                        _selectedDateFrom != null
                                            ? DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateFrom!)
                                            : 'От',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDateFrom ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _selectedDateFrom = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.calendar_today, size: 18),
                                      label: Text(
                                        _selectedDateTo != null
                                            ? DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateTo!)
                                            : 'До',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDateTo ?? DateTime.now(),
                                          firstDate: _selectedDateFrom ?? DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _selectedDateTo = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  if (_selectedDateFrom != null || _selectedDateTo != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedDateFrom = null;
                                          _selectedDateTo = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Общая прибыль',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_selectedDateFrom != null || _selectedDateTo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _selectedDateFrom != null && _selectedDateTo != null
                                ? '${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateFrom!)} - ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateTo!)}'
                                : _selectedDateFrom != null
                                    ? 'С ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateFrom!)}'
                                    : 'До ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateTo!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${filteredTotalProfit.toStringAsFixed(2)} ₽',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (filteredBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Детализация прибыли'),
                          children: [
                            ...filteredBreakdown.map((item) {
                              final excursionTitle =
                                  item['excursion_title'] as String? ?? '';
                              final profit =
                                  (item['profit'] as num?)?.toDouble() ?? 0.0;
                              final passengerCount =
                                  item['passenger_count'] as int? ?? 0;
                              final dateTime = item['date_time'] as String?;
                              DateTime? date;
                              if (dateTime != null) {
                                try {
                                  date = DateTime.parse(dateTime);
                                } catch (_) {}
                              }
                              return ListTile(
                                title: Text(excursionTitle),
                                subtitle: date != null
                                    ? Text(formatter.format(date))
                                    : null,
                                trailing: Text(
                                  '${profit.toStringAsFixed(2)} ₽',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people, size: 20),
                                    Text(
                                      '$passengerCount',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          // Расписание
          Expanded(
            child: excursionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Ошибка: $error')),
              data: (items) {
                // Получаем данные о прибыли для передачи в ExpansionTile
                final profitData = staffProfitAsync.valueOrNull;
                
                // Для водителей/гидов (showTabs = true) мы уже получаем только их бронирования
                // через /api/bookings/driver, поэтому все экскурсии уже "назначены"
                // Для остальных ролей фильтруем по assignedStaff
                final assigned = showTabs
                    ? items // Для водителей/гидов берем все (уже отфильтровано на бэкенде)
                    : items
                    .where(
                      (excursion) => excursion.assignedStaff
                          .any((staff) => staff.id == widget.user.id),
                    )
                    .toList();

                Widget buildList(List<Excursion> list, String emptyText) {
                  if (list.isEmpty) {
                    return Center(child: Text(emptyText));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final excursion = list[index];
                      // Получаем роль пользователя в экскурсии
                      final staffMember = excursion.assignedStaff
                          .where((staff) => staff.id == widget.user.id)
                          .firstOrNull;
                      final role = staffMember?.roleInExcursion ?? 
                          (isDriver ? 'driver' : 'guide');
                      return Card(
                        child: ExpansionTile(
                          title: Text(
                            excursion.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            formatter.format(excursion.dateTime),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Роль: ${role == 'driver' ? 'Водитель' : 'Гид'}'),
                                  if (excursion.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(excursion.description),
                                  ],
                                    // Детализация прибыли
                                  if (isDriver || isGuide) ...[
                                    const SizedBox(height: 16),
                                    _ProfitDetails(
                                      excursionId: excursion.id,
                                      excursionDate: excursion.dateTime,
                                      profitData: profitData,
                                    ),
                                  ],
                                  // Остановки, указанные в бронированиях (что важно водителю)
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Посадка пассажиров:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _BookedStopsFromSeats(
                                      busSeats: excursion.busSeats),
                                  const SizedBox(height: 16),
                                  // Полный список остановок — убираем в collapsible
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Все остановки маршрута',
                                      style:
                                          TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    children: [
                                      FutureBuilder<List<Stop>>(
                                        future: ref
                                            .read(stopsRepositoryProvider)
                                            .fetchStopsForExcursion(
                                                excursion.id),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          if (snapshot.hasError) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                'Ошибка загрузки остановок: ${snapshot.error}',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            );
                                          }
                                          final stops = snapshot.data ?? [];
                                          if (stops.isEmpty) {
                                            return const Padding(
                                              padding:
                                                  EdgeInsets.all(8.0),
                                              child:
                                                  Text('Остановки не указаны'),
                                            );
                                          }
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: stops
                                                .map((stop) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.location_on,
                                                            size: 16,
                                                            color:
                                                                Colors.grey,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child:
                                                                Text(stop.name),
                                                          ),
                                                        ],
                                                      ),
                                                    ))
                                                .toList(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (assigned.isEmpty) {
                  return const Center(
                    child: Text('Для вас пока нет назначенных экскурсий'),
                  );
                }

                if (!showTabs) {
                  assigned.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  return buildList(
                    assigned,
                    'Для вас пока нет назначенных экскурсий',
                  );
                }

                final upcomingList = assigned
                    .where((e) => !e.isPast)
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                final pastList = assigned
                    .where((e) => e.isPast)
                    .toList()
                  ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

                return TabBarView(
                  children: [
                    buildList(
                      upcomingList,
                      'Нет предстоящих экскурсий',
                    ),
                    buildList(
                      pastList,
                      'Нет прошедших экскурсий',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    if (showTabs) {
      return DefaultTabController(length: 2, child: scaffold);
    }
    return scaffold;
  }
}

class _SeatsGrid extends StatelessWidget {
  const _SeatsGrid({required this.busSeats});

  final List<BusSeat> busSeats;

  @override
  Widget build(BuildContext context) {
    if (busSeats.isEmpty) {
      return const Text('Схема мест недоступна');
    }

    final sorted = [...busSeats]..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.map((seat) {
        final booking = seat.booking;
        final hasBooking = booking != null;
        final label = StringBuffer()
          ..write(seat.seatNumber);
        if (hasBooking && booking.customerName.isNotEmpty) {
          label.write(' — ${booking.customerName}');
        }
        
        // Добавляем информацию о продавце
        final sellerInfo = <String>[];
        if (seat.bookedByInfo != null) {
          sellerInfo.add('${seat.bookedByInfo!.name}');
        }
        
        // Преобразуем тип пассажира на русский
        String passengerTypeText = '';
        if (hasBooking && booking.passengerType.isNotEmpty) {
          final type = booking.passengerType.toLowerCase();
          switch (type) {
            case 'adult':
              passengerTypeText = 'Взрослый';
              break;
            case 'child':
              passengerTypeText = 'Детский';
              break;
            case 'senior':
              passengerTypeText = 'Пенсионер';
              break;
            case 'disabled':
              passengerTypeText = 'Инвалид';
              break;
            case 'special':
              passengerTypeText = 'Спеццена';
              break;
            case 'concession':
              passengerTypeText = 'Льготный';
              break;
            default:
              passengerTypeText = booking.passengerType;
          }
        }
        
        final subtitle = hasBooking
            ? [
                if (passengerTypeText.isNotEmpty) passengerTypeText,
                if (booking.stopTitle?.isNotEmpty ?? false)
                  booking.stopTitle!,
                if (booking.customerPhone.isNotEmpty) booking.customerPhone,
                ...sellerInfo,
              ].where((e) => e.isNotEmpty).join('\n')
            : (seat.status == 'available' 
                ? 'Свободно' 
                : (seat.bookedByInfo != null && seat.bookedByInfo!.name.isNotEmpty
                    ? seat.bookedByInfo!.name
                    : 'Занято'));

        // Используем цвет продавца, если он есть, иначе стандартные цвета
        Color seatColor;
        if (seat.bookedByInfo?.color != null && seat.bookedByInfo!.color!.isNotEmpty) {
          try {
            final hexColor = seat.bookedByInfo!.color!;
            seatColor = Color(int.parse(hexColor.substring(1), radix: 16) + 0xFF000000);
          } catch (e) {
            seatColor = hasBooking
                ? Colors.blue.shade100
                : seat.status == 'available'
                    ? Colors.green.shade100
                    : Colors.red.shade100;
          }
        } else {
          seatColor = hasBooking
              ? Colors.blue.shade100
              : seat.status == 'available'
                  ? Colors.green.shade100
                  : Colors.red.shade100;
        }

        return Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: seatColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BookedStopsFromSeats extends StatelessWidget {
  const _BookedStopsFromSeats({required this.busSeats});

  final List<BusSeat> busSeats;

  @override
  Widget build(BuildContext context) {
    final stops = busSeats
        .map((seat) => seat.booking?.stopTitle ?? '')
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList();

    if (stops.isEmpty) {
      return const Text('Остановки будут показаны после бронирований.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stops
          .map(
            (title) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProfitDetails extends StatelessWidget {
  const _ProfitDetails({
    required this.excursionId,
    required this.excursionDate,
    required this.profitData,
  });

  final int excursionId;
  final DateTime excursionDate;
  final Map<String, dynamic>? profitData;

  @override
  Widget build(BuildContext context) {
    if (profitData == null) {
      return const SizedBox.shrink();
    }

    final breakdown = profitData!['breakdown'] as List<dynamic>? ?? [];
    // Ищем запись не только по excursion_id, но и по дате экскурсии
    // Для одной экскурсии может быть несколько записей (по разным датам)
    final item = breakdown.firstWhere(
      (e) {
        final eId = e['excursion_id'] as int?;
        if (eId != excursionId) return false;
        
        // Проверяем дату
        final dateTimeStr = e['date_time'] as String?;
        if (dateTimeStr == null || dateTimeStr.isEmpty) return false;
        
        try {
          final itemDate = DateTime.parse(dateTimeStr);
          // Сравниваем дату и время (без секунд и миллисекунд)
          final excursionDateOnly = DateTime(
            excursionDate.year,
            excursionDate.month,
            excursionDate.day,
            excursionDate.hour,
            excursionDate.minute,
          );
          final itemDateOnly = DateTime(
            itemDate.year,
            itemDate.month,
            itemDate.day,
            itemDate.hour,
            itemDate.minute,
          );
          return excursionDateOnly == itemDateOnly;
        } catch (e) {
          return false;
        }
      },
      orElse: () => null,
    );

    if (item == null) {
      return const SizedBox.shrink();
    }

    final profit = (item['profit'] as num?)?.toDouble() ?? 0.0;
    final passengerCount = item['passenger_count'] as int? ?? 0;
    final totalRevenue = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final passengersByType = item['passengers_by_type'] as Map<String, dynamic>? ?? {};
    final staffPriceInfo = item['staff_price_info'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детализация прибыли',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Прибыль:'),
              Text(
                '${profit.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Общая выручка:'),
              Text('${totalRevenue.toStringAsFixed(2)} ₽'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Количество пассажиров:'),
              Text('$passengerCount'),
            ],
          ),
          if (passengersByType.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Пассажиры по типам:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...passengersByType.entries.map((entry) {
              final typeName = entry.key == 'adult'
                  ? 'Взрослый'
                  : entry.key == 'child'
                      ? 'Ребенок'
                      : entry.key;
              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(typeName),
                    Text('${entry.value}'),
                  ],
                ),
              );
            }),
          ],
          if (staffPriceInfo != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Информация о цене:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Цена: ${(staffPriceInfo['price'] as num?)?.toStringAsFixed(2) ?? '0.00'} ₽',
                  ),
                  if (staffPriceInfo['min_passengers'] != null ||
                      staffPriceInfo['max_passengers'] != null)
                    Text(
                      'Диапазон пассажиров: ${staffPriceInfo['min_passengers'] ?? 0} - ${staffPriceInfo['max_passengers'] ?? '∞'}',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
