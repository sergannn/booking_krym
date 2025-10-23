import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import '../auth/auth_controller.dart';

class SellerHomePage extends StatelessWidget {
  const SellerHomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Продавец — ${user.name}'),
        actions: [
          Consumer(builder: (context, ref, _) {
            return IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти',
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            );
          }),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Авторизация успешна!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('Добро пожаловать, ${user.name}'),
              const SizedBox(height: 12),
              Text('Роль: ${user.role}'),
              const SizedBox(height: 24),
              const Text('Функции бронирования появятся позже.'),
            ],
          ),
        ),
      ),
    );
  }
}
