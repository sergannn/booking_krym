import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local_database.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Администратор — ${user.shortName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Бронирование'),
              Tab(text: 'Статистика'),
              Tab(text: 'Кошелёк'),
              Tab(text: 'Расписание'),
              Tab(text: 'Список сотрудников'),
              Tab(text: 'Цены'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminBookingTab(),
            AdminStatsTab(),
            AdminWalletTab(),
            AdminScheduleTab(),
            AdminStaffTab(),
            AdminPricesTab(),
          ],
        ),
      ),
    );
  }
}

class AdminBookingTab extends StatelessWidget {
  const AdminBookingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final excursions = db.excursionsBox.values
        .where((excursion) => excursion.dateTime
            .isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    if (excursions.isEmpty) {
      return const Center(child: Text('Нет доступных экскурсий'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: excursions.length,
      itemBuilder: (context, index) {
        final excursion = excursions[index];
        final stopNames = excursion.stopIds
            .map((id) => db.stopsBox.get(id)?.name ?? id)
            .join(', ');
        final driverNames = excursion.driverIds
            .map((id) => db.usersBox.get(id)?.shortName ?? id)
            .where((name) => name.isNotEmpty)
            .join(', ');
        final guideNames = excursion.guideIds
            .map((id) => db.usersBox.get(id)?.shortName ?? id)
            .where((name) => name.isNotEmpty)
            .join(', ');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                Text('Дата и время: ${formatter.format(excursion.dateTime)}'),
                const SizedBox(height: 4),
                Text('Остановки: $stopNames'),
                if (driverNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Водитель: $driverNames'),
                ],
                if (guideNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Экскурсовод: $guideNames'),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: () => _showComingSoon(context,
                          'Бронирование для админа пока не реализовано'),
                      child: const Text('Забронировать'),
                    ),
                    OutlinedButton(
                      onPressed: () => _showComingSoon(
                          context, 'Отмена бронирования пока не реализована'),
                      child: const Text('Отменить'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showComingSoon(context,
                          'Редактирование экскурсии пока не реализовано'),
                      icon: const Icon(Icons.edit),
                      label: const Text('Редактировать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('В разработке'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class AdminStatsTab extends StatelessWidget {
  const AdminStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Раздел статистики находится в разработке'),
      ),
    );
  }
}

class AdminWalletTab extends StatelessWidget {
  const AdminWalletTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final transactions = db.walletBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    if (transactions.isEmpty) {
      return const Center(child: Text('Операций пока не было'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final user = db.usersBox.get(tx.userId);
        return ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: Text(
              '${tx.amount.toStringAsFixed(2)} ₽ — ${user?.shortName ?? tx.userId}'),
          subtitle:
              Text('${formatter.format(tx.timestamp)} • ${tx.description}'),
        );
      },
    );
  }
}

class AdminScheduleTab extends StatelessWidget {
  const AdminScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final excursions = db.excursionsBox.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    final grouped = excursions.groupListsBy((excursion) => DateTime(
          excursion.dateTime.year,
          excursion.dateTime.month,
          excursion.dateTime.day,
        ));

    if (grouped.isEmpty) {
      return const Center(child: Text('Расписание отсутствует'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final date = entry.key;
        final items = entry.value;
        final heading = DateFormat('dd.MM.yyyy').format(date);
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...items.map((excursion) {
                  final stopNames = excursion.stopIds
                      .map((id) => db.stopsBox.get(id)?.name ?? id)
                      .join(', ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${formatter.format(excursion.dateTime)} — ${excursion.title}'),
                        const SizedBox(height: 4),
                        Text('Остановки: $stopNames'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AdminStaffTab extends StatelessWidget {
  const AdminStaffTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final users = db.usersBox.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = users[index];
        final initialsSource =
            user.shortName.isNotEmpty ? user.shortName : user.displayName;
        final initial =
            initialsSource.isNotEmpty ? initialsSource[0].toUpperCase() : '?';
        return ListTile(
          leading: CircleAvatar(child: Text(initial)),
          title: Text(user.displayName),
          subtitle: Text(
            'Роль: ${_roleLabel(user.role)}\nЛогин: ${user.login} • Пароль: ${user.password}',
          ),
          isThreeLine: true,
          trailing: Text('${user.balance.toStringAsFixed(2)} ₽'),
        );
      },
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Администратор';
      case UserRole.seller:
        return 'Продавец';
      case UserRole.partnerSeller:
        return 'Продавец-партнер';
      case UserRole.driver:
        return 'Водитель';
      case UserRole.guide:
        return 'Экскурсовод';
    }
  }
}

class AdminPricesTab extends StatelessWidget {
  const AdminPricesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase.instance;
    final excursions = {
      for (final excursion in db.excursionsBox.values) excursion.id: excursion
    };
    final grouped =
        groupBy(db.priceRulesBox.values, (PriceRule rule) => rule.excursionId);

    if (grouped.isEmpty) {
      return const Center(child: Text('Цены не заданы'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final excursion = excursions[entry.key];
        final rules = entry.value;
        rules.sort((a, b) => a.tier.index.compareTo(b.tier.index));
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(excursion?.title ?? entry.key,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                    3: FlexColumnWidth(),
                  },
                  children: [
                    const TableRow(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Тариф'),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Продавец'),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Водитель'),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Экскурсовод'),
                        ),
                      ],
                    ),
                    ...rules.map((rule) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(_tierLabel(rule.tier)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${rule.sellerPayout.toStringAsFixed(0)} ₽'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${rule.driverPayout.toStringAsFixed(0)} ₽'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  '${rule.guidePayout.toStringAsFixed(0)} ₽'),
                            ),
                          ],
                        )),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _tierLabel(PriceTier tier) {
    switch (tier) {
      case PriceTier.standard:
        return 'Стандартная цена';
      case PriceTier.upTo15:
        return 'До 15 человек';
      case PriceTier.upTo10:
        return 'До 10 человек';
      case PriceTier.upTo5:
        return 'До 5 человек';
    }
  }
}
