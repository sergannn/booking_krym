import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
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
      body: excursionsAsync.when(
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        excursion.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(formatter.format(excursion.dateTime)),
                      const SizedBox(height: 8),
                      Text('Роль: ${role == 'driver' ? 'Водитель' : 'Гид'}'),
                      if (excursion.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(excursion.description),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
