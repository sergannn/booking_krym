import 'package:flutter/material.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/excursion.dart';
import '../../../data/repositories/bookings_repository.dart';

class BookingDialog extends StatefulWidget {
  const BookingDialog({
    super.key,
    required this.stops,
    required this.tariffs,
    this.initialSeatNumbers = const [],
    this.lockSeatSelection = false,
  });

  final List<Stop> stops;
  final Map<String, ExcursionTariff> tariffs;
  final List<int> initialSeatNumbers;
  final bool lockSeatSelection;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _seatsController = TextEditingController();
  late TabController _tabController;

  int? _stopId;
  Stop? _selectedStop;
  late final List<int> _seatNumbers;

  // Данные для каждого места: номер места -> данные пассажира
  final Map<int, _SeatPassengerData> _seatData = {};

  @override
  void initState() {
    super.initState();
    _seatNumbers = List<int>.from(widget.initialSeatNumbers);
    if (_seatNumbers.isNotEmpty) {
      _seatsController.text = _seatNumbers.join(', ');
      // Инициализируем данные для каждого места
      for (final seatNum in _seatNumbers) {
        _seatData[seatNum] = _SeatPassengerData();
      }
    }
    if (widget.stops.isNotEmpty) {
      _selectedStop = widget.stops.first;
      _stopId = _selectedStop!.id;
    }
    _tabController = TabController(
      length: _seatNumbers.isEmpty ? 1 : _seatNumbers.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _seatsController.dispose();
    _tabController.dispose();
    for (final data in _seatData.values) {
      data.nameController.dispose();
      data.phoneController.dispose();
    }
    super.dispose();
  }

  void _updateSeats() {
    final seats = _parseSeatNumbers(_seatsController.text.trim());
    setState(() {
      // Удаляем данные для мест, которых больше нет
      _seatData.removeWhere((seatNum, _) => !seats.contains(seatNum));
      // Добавляем данные для новых мест
      for (final seatNum in seats) {
        _seatData.putIfAbsent(seatNum, () => _SeatPassengerData());
      }
      _seatNumbers.clear();
      _seatNumbers.addAll(seats);
      // Обновляем TabController
      final oldLength = _tabController.length;
      final newLength = seats.isEmpty ? 1 : seats.length;
      if (oldLength != newLength) {
        _tabController.dispose();
        _tabController = TabController(length: newLength, vsync: this);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSeats = _seatNumbers.isNotEmpty;

    return AlertDialog(
      title: const Text('Новое бронирование'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Поле для ввода мест (если не заблокировано)
              if (!widget.lockSeatSelection) ...[
                TextFormField(
                  controller: _seatsController,
                  decoration: const InputDecoration(
                    labelText: 'Места',
                    hintText: 'Например: 3,5,7 или 3-7',
                    helperText:
                        'Можно указать несколько мест через запятую (3,5,7) или диапазон (3-7)',
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите номера мест';
                    }
                    final seats = _parseSeatNumbers(value.trim());
                    if (seats.isEmpty) {
                      return 'Введите корректные номера мест';
                    }
                    if (seats.any((s) => s <= 0 || s > 100)) {
                      return 'Номера мест должны быть от 1 до 100';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateSeats(),
                ),
                const SizedBox(height: 16),
              ],

              // Табы для каждого места
              if (hasSeats) ...[
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: _seatNumbers
                      .map((seatNum) => Tab(text: 'Место $seatNum'))
                      .toList(),
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: _seatNumbers.map((seatNum) {
                      return _buildSeatTab(seatNum);
                    }).toList(),
                  ),
                ),
              ] else ...[
                // Если мест нет, показываем сообщение
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Введите номера мест для бронирования'),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Общая остановка для всех мест
              DropdownButtonFormField<int>(
                value: _stopId,
                decoration: const InputDecoration(labelText: 'Остановка'),
                items: widget.stops
                    .map(
                      (stop) => DropdownMenuItem(
                        value: stop.id,
                        child: Text(stop.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _stopId = value;
                    _selectedStop =
                        widget.stops.firstWhere((stop) => stop.id == value);
                  });
                },
                validator: (value) =>
                    value == null ? 'Выберите остановку' : null,
              ),

              // Итоговая сумма
              // if (hasSeats) ...[
              //   const SizedBox(height: 16),
              //   Builder(
              //     builder: (context) {
              //       double total = 0;
              //       for (final seatNum in _seatNumbers) {
              //         final data = _seatData[seatNum]!;
              //         final tariff =
              //             widget.tariffs[data.passengerType.apiValue];
              //         if (tariff != null) {
              //           final price = data.withEntry
              //               ? (tariff.priceWithEntry ?? tariff.price)
              //               : (tariff.priceWithoutEntry ?? tariff.price);
              //           total += price;
              //         }
              //       }
              //       return Text(
              //         'Итого: ${total.toStringAsFixed(2)} ₽',
              //         style: const TextStyle(
              //           fontWeight: FontWeight.bold,
              //           fontSize: 16,
              //         ),
              //       );
              //     },
              //   ),
              // ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }

            if (!hasSeats) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Введите номера мест')),
              );
              return;
            }

            // Проверяем, что для всех мест заполнены данные
            for (final seatNum in _seatNumbers) {
              final data = _seatData[seatNum]!;
              if (data.nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Введите имя пассажира для места $seatNum')),
                );
                return;
              }
              if (data.phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Введите телефон пассажира для места $seatNum')),
                );
                return;
              }
              final tariff = widget.tariffs[data.passengerType.apiValue];
              if (tariff == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Цена для типа "${data.passengerType.label}" на месте $seatNum не настроена')),
                );
                return;
              }
            }

            // Собираем все места с данными
            final seats = _seatNumbers.map((seatNum) {
              final data = _seatData[seatNum]!;
              return SeatBooking(
                seatNumber: seatNum,
                passengerType: data.passengerType,
                withEntry: data.withEntry,
                customerName: data.nameController.text.trim(),
                customerPhone: data.phoneController.text.trim(),
              );
            }).toList();

            Navigator.of(context).pop(
              BookingDialogResult(
                seats: seats,
                seatNumbers: _seatNumbers,
                pricePerSeat: 0, // Не используется в новом формате
                customerName:
                    _seatData[_seatNumbers.first]!.nameController.text.trim(),
                customerPhone:
                    _seatData[_seatNumbers.first]!.phoneController.text.trim(),
                passengerType: _seatData[_seatNumbers.first]!.passengerType,
                stop: _selectedStop!,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _buildSeatTab(int seatNum) {
    final data = _seatData[seatNum]!;
    final hasMultipleSeats = _seatNumbers.length > 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Кнопка "Копировать для всех мест" (только если мест больше одного)
          if (hasMultipleSeats) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Копировать для всех мест'),
              onPressed: () => _copyToAllSeats(seatNum),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: data.nameController,
            decoration: const InputDecoration(labelText: 'Имя пассажира'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите имя';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: data.phoneController,
            decoration: const InputDecoration(labelText: 'Телефон пассажира'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите телефон';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PassengerType>(
            value: data.passengerType,
            items: PassengerType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  data.passengerType = value;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Тип пассажира'),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Входной билет'),
            value: data.withEntry,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  data.withEntry = value;
                });
              }
            },
          ),
          // const SizedBox(height: 12),
          // Builder(
          //   builder: (context) {
          //     final tariff = widget.tariffs[data.passengerType.apiValue];
          //     if (tariff != null) {
          //       final price = data.withEntry
          //           ? (tariff.priceWithEntry ?? tariff.price)
          //           : (tariff.priceWithoutEntry ?? tariff.price);
          //       return Text(
          //         'Цена: ${price.toStringAsFixed(2)} ₽',
          //         style: const TextStyle(
          //           fontWeight: FontWeight.bold,
          //           fontSize: 16,
          //         ),
          //       );
          //     }
          //     return const Text(
          //       'Цена для выбранного типа не настроена',
          //       style: TextStyle(
          //         color: Colors.red,
          //         fontWeight: FontWeight.w600,
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }

  /// Копирует данные из указанного места на все остальные места
  void _copyToAllSeats(int sourceSeatNum) {
    final sourceData = _seatData[sourceSeatNum]!;

    setState(() {
      for (final seatNum in _seatNumbers) {
        if (seatNum != sourceSeatNum) {
          final targetData = _seatData[seatNum]!;
          // Копируем имя
          targetData.nameController.text = sourceData.nameController.text;
          // Копируем телефон
          targetData.phoneController.text = sourceData.phoneController.text;
          // Копируем тип пассажира
          targetData.passengerType = sourceData.passengerType;
          // Копируем флаг входного билета
          targetData.withEntry = sourceData.withEntry;
        }
      }
    });

    // Показываем уведомление
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Данные из места $sourceSeatNum скопированы на все остальные места',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Парсит строку с номерами мест (поддерживает запятые и диапазоны)
  List<int> _parseSeatNumbers(String input) {
    if (input.isEmpty) return [];

    final result = <int>{};
    final parts = input.split(',');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        // Диапазон: 3-7
        final rangeParts = trimmed.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              result.add(i);
            }
          }
        }
      } else {
        // Одно число
        final number = int.tryParse(trimmed);
        if (number != null && number > 0 && number <= 100) {
          result.add(number);
        }
      }
    }

    return result.toList()..sort();
  }
}

class _SeatPassengerData {
  _SeatPassengerData()
      : nameController = TextEditingController(),
        phoneController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController phoneController;
  PassengerType passengerType = PassengerType.adult;
  bool withEntry = false;
}

class BookingDialogResult {
  const BookingDialogResult({
    required this.seatNumbers,
    required this.pricePerSeat,
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    required this.stop,
    this.seats, // Новый формат: список мест с типами
  });

  final List<int> seatNumbers;
  final double pricePerSeat;
  final String customerName;
  final String customerPhone;
  final PassengerType passengerType;
  final Stop stop;
  final List<SeatBooking>? seats; // Новый формат

  int get stopId => stop.id;
}
