import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../admin/admin_home.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../seller/seller_home.dart';
import '../staff/staff_home.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Ошибка: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Вернуться к входу'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        switch (user.role) {
          case UserRole.admin:
            return AdminHomePage(user: user);
          case UserRole.seller:
            return SellerHomePage(user: user);
          case UserRole.partnerSeller:
            return SellerHomePage(user: user, isPartner: true);
          case UserRole.driver:
            return StaffHomePage(user: user);
          case UserRole.guide:
            return StaffHomePage(user: user);
        }
      },
    );
  }
}
