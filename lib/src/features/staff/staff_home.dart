import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local_database.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';

class StaffHomePage extends ConsumerWidget {
  const StaffHomePage({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = user.role == UserRole.driver ? 'Водитель' : 'Экскурсовод';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$title — ${user.shortName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Расписание'),
              Tab(text: 'Кошелёк'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StaffScheduleTab(user: user),
            StaffWalletTab(user: user),
          ],
        ),
      ),
    );
  }
}

class StaffScheduleTab extends StatelessWidget {
  const StaffScheduleTab({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final isDriver = user.role == UserRole.driver;
    final excursions = db.excursionsBox.values
        .where(
          (excursion) => isDriver
              ? excursion.driverIds.contains(user.id)
              : excursion.guideIds.contains(user.id),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    if (excursions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('На вас пока не назначены экскурсии'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: excursions.length,
      itemBuilder: (context, index) {
        final excursion = excursions[index];
        final stopNames = excursion.stopIds
            .map((id) => db.stopsBox.get(id)?.name ?? id)
            .join(', ');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(excursion.title),
            subtitle: Text(
                '${formatter.format(excursion.dateTime)}\nОстановки: $stopNames'),
          ),
        );
      },
    );
  }
}

class StaffWalletTab extends StatelessWidget {
  const StaffWalletTab({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final transactions = db.walletBox.values
        .where((transaction) => transaction.userId == user.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final balance = db.usersBox.get(user.id)?.balance ?? user.balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Баланс: ${balance.toStringAsFixed(2)} ₽',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (transactions.isEmpty)
          const Expanded(
            child: Center(child: Text('История операций пока пуста')),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return ListTile(
                  title: Text('${tx.amount.toStringAsFixed(2)} ₽'),
                  subtitle: Text(
                      '${formatter.format(tx.timestamp)} • ${tx.description}'),
                );
              },
            ),
          ),
      ],
    );
  }
}
