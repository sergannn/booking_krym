import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../auth/auth_controller.dart';

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
                icon: const Icon(Icons.logout),
                tooltip: 'Выйти',
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Экскурсии'),
              Tab(text: 'Бронирование'),
              Tab(text: 'Статистика'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExcursionsTab(),
            _ActionsTab(),
            _StatsTab(),
          ],
        ),
      ),
    );
  }
}

class _ExcursionsTab extends StatelessWidget {
  const _ExcursionsTab();

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy • HH:mm');
    final mock = _mockExcursions(formatter);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mock.length,
      itemBuilder: (context, index) {
        final item = mock[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text(item.emoji)),
            title: Text(item.title),
            subtitle: Text('${formatter.format(item.date)}\nМест занято: ${item.booked}/${item.capacity}'),
          ),
        );
      },
    );
  }

  List<_ExcursionMock> _mockExcursions(DateFormat formatter) {
    final now = DateTime.now();
    return [
      _ExcursionMock('🚍', 'Обзорная экскурсия по городу', now.add(const Duration(hours: 4)), 32, 40),
      _ExcursionMock('🛳️', 'Речная прогулка по каналу', now.add(const Duration(days: 1, hours: 2)), 18, 25),
      _ExcursionMock('🏰', 'Тайны старого замка', now.add(const Duration(days: 2, hours: 6)), 12, 20),
    ];
  }
}

class _ExcursionMock {
  _ExcursionMock(this.emoji, this.title, this.date, this.booked, this.capacity);

  final String emoji;
  final String title;
  final DateTime date;
  final int booked;
  final int capacity;
}

class _ActionsTab extends StatelessWidget {
  const _ActionsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Быстрые действия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.event_available),
          label: const Text('Добавить экскурсию'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.group_add),
          label: const Text('Назначить персонал'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.monetization_on),
          label: const Text('Обновить тарифы'),
        ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.insights, size: 48),
          SizedBox(height: 12),
          Text('Статистика в разработке'),
        ],
      ),
    );
  }
}
