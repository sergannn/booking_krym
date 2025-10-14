import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local_database.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';

class SellerHomePage extends ConsumerStatefulWidget {
  const SellerHomePage({super.key, required this.user, this.isPartner = false});

  final UserProfile user;
  final bool isPartner;

  @override
  ConsumerState<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends ConsumerState<SellerHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.isPartner ? 'Продавец-партнёр' : 'Продавец';
    final tabs = [
      SellerBookingsTab(user: widget.user),
      SellerWalletTab(user: widget.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('$title — ${widget.user.shortName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event), label: 'Бронирование'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Кошелёк'),
        ],
      ),
    );
  }
}

class SellerBookingsTab extends StatelessWidget {
  const SellerBookingsTab({super.key, required this.user});

  final UserProfile user;

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
      return const Center(child: Text('Ближайших экскурсий пока нет'));
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => _showComingSoon(
                          context, 'Бронирование пока не реализовано'),
                      child: const Text('Забронировать'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _showComingSoon(
                          context, 'Отмена бронирования пока не реализована'),
                      child: const Text('Отменить'),
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

class SellerWalletTab extends StatelessWidget {
  const SellerWalletTab({super.key, required this.user});

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
