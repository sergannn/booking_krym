import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/excursion.dart';
import '../../../data/providers.dart';

class PricesTab extends ConsumerWidget {
  const PricesTab({super.key});

  static const _typeLabels = <String, String>{
    'adult': 'Взрослый',
    'child': 'Детский',
    'senior': 'Пенсионер',
    'disabled': 'Инвалид',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excursionsAsync = ref.watch(excursionsFutureProvider);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return excursionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Не удалось загрузить: $error')),
      data: (excursions) {
        if (excursions.isEmpty) {
          return const Center(child: Text('Экскурсии отсутствуют'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(excursionsFutureProvider);
            await ref.read(excursionsFutureProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: excursions.length,
            itemBuilder: (context, index) {
              final excursion = excursions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        excursion.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Дата: ${formatter.format(excursion.dateTime)}'),
                      const SizedBox(height: 12),
                      ..._typeLabels.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.value),
                              Text(
                                '${excursion.priceFor(entry.key).toStringAsFixed(2)} ₽',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Изменить цены'),
                          onPressed: () async {
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => PriceEditDialog(
                                excursion: excursion,
                              ),
                            );

                            if (updated == true) {
                              ref.invalidate(excursionsFutureProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Цены для «${excursion.title}» обновлены',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class PriceEditDialog extends ConsumerStatefulWidget {
  const PriceEditDialog({super.key, required this.excursion});

  final Excursion excursion;

  @override
  ConsumerState<PriceEditDialog> createState() => _PriceEditDialogState();
}

class _PriceEditDialogState extends ConsumerState<PriceEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _typeOrder = ['adult', 'child', 'senior', 'disabled'];
  static const _labels = <String, String>{
    'adult': 'Взрослый',
    'child': 'Детский',
    'senior': 'Пенсионер',
    'disabled': 'Инвалид',
  };

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final type in _typeOrder)
        type: TextEditingController(
          text: widget.excursion.priceFor(type).toStringAsFixed(2),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Цены для «${widget.excursion.title}»'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in _typeOrder)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _controllers[type],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _labels[type],
                    suffixText: '₽',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите цену';
                    }
                    final normalized = value.replaceAll(',', '.');
                    final parsed = double.tryParse(normalized);
                    if (parsed == null || parsed < 0) {
                      return 'Некорректная цена';
                    }
                    return null;
                  },
                ),
              ),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final prices = <String, double>{};
    for (final entry in _controllers.entries) {
      final normalized = entry.value.text.replaceAll(',', '.');
      prices[entry.key] = double.parse(normalized);
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(excursionsRepositoryProvider).updateTariffs(
            excursionId: widget.excursion.id,
            prices: prices,
            currentExcursion: widget.excursion,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = '$error';
      });
    }
  }
}
