import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/user_summary.dart';
import '../../../data/models/wallet.dart';
import '../../../data/models/booking.dart';
import '../../../data/providers.dart';

class StaffWalletSheet extends ConsumerWidget {
  const StaffWalletSheet({super.key, required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(_walletProvider(user.id));
    final salesAsync = ref.watch(_salesProvider(user.id));
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: [
                    walletAsync.when(
                      loading: () => const ListTile(
                        title: Text('Баланс'),
                        trailing: CircularProgressIndicator(),
                      ),
                      error: (error, _) => ListTile(
                        title: const Text('Баланс'),
                        subtitle: Text('Ошибка: $error'),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () =>
                              ref.refresh(_walletProvider(user.id).future),
                        ),
                      ),
                      data: (wallet) => Card(
                        child: ListTile(
                          title: const Text('Баланс'),
                          subtitle: Text('Текущий остаток по кошельку'),
                          trailing: Text(
                            '${wallet.balance.toStringAsFixed(2)} ₽',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.green),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'История транзакций',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    walletAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Ошибка загрузки: $error'),
                      ),
                      data: (wallet) {
                        if (wallet.transactions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Транзакций пока нет'),
                          );
                        }
                        return Column(
                          children: wallet.transactions
                              .map(
                                (transaction) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: transaction.amount >= 0
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                      transaction.amount >= 0
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: transaction.amount >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  title: Text(transaction.description),
                                  subtitle: Text(
                                    formatter.format(transaction.createdAt),
                                  ),
                                  trailing: Text(
                                    '${transaction.amount.toStringAsFixed(2)} ₽',
                                    style: TextStyle(
                                      color: transaction.amount >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Продажи',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    salesAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Ошибка загрузки: $error'),
                      ),
                      data: (sales) {
                        if (sales.bookings.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Продаж пока нет'),
                          );
                        }
                        return Column(
                          children: sales.bookings
                              .map(
                                (booking) => ListTile(
                                  title: Text(booking.excursion.title),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatter
                                            .format(booking.excursion.dateTime),
                                      ),
                                      Text(
                                        '${booking.customerName} • ${booking.customerPhone}',
                                      ),
                                      Text(
                                        booking.passengerType.label,
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    '${booking.price.toStringAsFixed(2)} ₽',
                                  ),
                                ),
                              )
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
  }
}

final _walletProvider = FutureProvider.family<WalletInfo, int>((ref, userId) {
  return ref.watch(walletRepositoryProvider).fetchWallet(userId);
});

final _salesProvider = FutureProvider.family<SalesInfo, int>((ref, userId) {
  return ref.watch(walletRepositoryProvider).fetchSales(userId);
});
