import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/excursion.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../auth/auth_controller.dart';

class StaffHomePage extends ConsumerWidget {
  const StaffHomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание — ${user.name}'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
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
                    .any((staff) => staff.id == user.id),
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
                  .firstWhere((staff) => staff.id == user.id)
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
