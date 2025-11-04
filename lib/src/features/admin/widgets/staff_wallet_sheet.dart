import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/user_summary.dart';
import '../../../data/models/booking.dart';
import '../../../data/providers.dart';

class StaffWalletSheet extends ConsumerStatefulWidget {
  const StaffWalletSheet({super.key, required this.user});

  final UserSummary user;

  @override
  ConsumerState<StaffWalletSheet> createState() => _StaffWalletSheetState();
}

class _StaffWalletSheetState extends ConsumerState<StaffWalletSheet> {
  int _sectionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(userWalletFutureProvider(widget.user.id));
    final salesAsync = ref.watch(userSalesFutureProvider(widget.user.id));
    final profitAsync = ref.watch(userProfitFutureProvider(widget.user.id));
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
                      widget.user.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.user.email),
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
                          onPressed: () => ref.refresh(
                            userWalletFutureProvider(widget.user.id).future,
                          ),
                        ),
                      ),
                      data: (wallet) => Card(
                        child: ListTile(
                          title: const Text('Баланс'),
                          subtitle: const Text('Текущий остаток по кошельку'),
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
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected:
                          List.generate(2, (index) => index == _sectionIndex),
                      onPressed: (index) => setState(() => _sectionIndex = index),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Продажи'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Прибыль'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_sectionIndex == 0) ...[
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
                                          formatter.format(
                                              booking.excursion.dateTime),
                                        ),
                                        Text(
                                          '${booking.customerName} • ${booking.customerPhone}',
                                        ),
                                        Text(booking.passengerType.label),
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
                    ] else ...[
                      Text(
                        'Прибыль',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      profitAsync.when(
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
                        data: (profit) {
                          if (profit.breakdown.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Прибыль пока не рассчитана'),
                            );
                          }

                          final totalsTiles = profit.totalsByType.entries
                              .map(
                                (entry) => ListTile(
                                  title: Text(entry.key.label),
                                  subtitle: Text(
                                    'Продажи: ${entry.value.sales.toStringAsFixed(2)} ₽',
                                  ),
                                  trailing: Text(
                                    '+${entry.value.commission.toStringAsFixed(2)} ₽',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                              )
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                child: ListTile(
                                  title: const Text('Общая прибыль'),
                                  subtitle: Text(
                                    profit.isPartner
                                        ? 'Партнёрская комиссия'
                                        : '10% от продаж',
                                  ),
                                  trailing: Text(
                                    '${profit.totalProfit.toStringAsFixed(2)} ₽',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: Colors.green),
                                  ),
                                ),
                              ),
                              if (totalsTiles.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Card(
                                  child: Column(
                                    children: [
                                      const ListTile(
                                        title: Text('Итого по категориям'),
                                      ),
                                      const Divider(height: 1),
                                      ...totalsTiles,
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              ...profit.breakdown.map(
                                (item) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(item.excursion.title),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatter.format(
                                              item.excursion.dateTime),
                                        ),
                                        Text(item.passengerType.label),
                                        Text(
                                          'Продажа: ${item.price.toStringAsFixed(2)} ₽',
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '+${item.commissionAmount.toStringAsFixed(2)} ₽',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${item.commissionPercent.toStringAsFixed(1)} %',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
