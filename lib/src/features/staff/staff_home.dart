import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/models/stop.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';
import 'assignments_controller.dart';

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
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final staffProfitAsync =
        ref.watch(staffProfitFutureProvider(widget.user.id));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    // Определяем, водитель это или гид
    final isDriver = widget.user.roleId == 3;
    final normalizedRole = widget.user.role.trim().toLowerCase();
    final isGuide = normalizedRole.contains('гид') ||
        normalizedRole.contains('guide') ||
        normalizedRole.contains('экскурсовод');

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

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
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
                final totalProfit =
                    profitData['total_profit'] as double? ?? 0.0;
                final breakdown =
                    profitData['breakdown'] as List<dynamic>? ?? [];
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Общая прибыль',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalProfit.toStringAsFixed(2)} ₽',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (breakdown.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Детализация прибыли'),
                          children: [
                            ...breakdown.map((item) {
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
                final assigned = items
                    .where(
                      (excursion) => excursion.assignedStaff
                          .any((staff) => staff.id == widget.user.id),
                    )
                    .toList();
                if (assigned.isEmpty) {
                  return const Center(
                    child: Text('Для вас пока нет назначенных экскурсий'),
                  );
                }
                assigned.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: assigned.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final excursion = assigned[index];
                    final role = excursion.assignedStaff
                        .firstWhere((staff) => staff.id == widget.user.id)
                        .roleInExcursion;
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
                                const SizedBox(height: 16),
                                const Text(
                                  'Остановки:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<List<Stop>>(
                                  future: ref
                                      .read(stopsRepositoryProvider)
                                      .fetchStopsForExcursion(excursion.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
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
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Остановки не указаны'),
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: stops
                                          .map((stop) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 16,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(stop.name),
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
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
