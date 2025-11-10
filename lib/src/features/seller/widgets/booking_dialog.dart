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

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _seatsController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  PassengerType _passengerType = PassengerType.adult;
  int? _stopId;
  Stop? _selectedStop;
  late final List<int> _seatNumbers;

  // Новый формат: список мест с типами пассажиров
  final List<SeatBooking> _seatsWithTypes = [];

  @override
  void initState() {
    super.initState();
    _seatNumbers = List<int>.from(widget.initialSeatNumbers);
    if (_seatNumbers.isNotEmpty) {
      _seatsController.text = _seatNumbers.join(', ');
      // Всегда создаем список для множественного выбора, если есть предустановленные места
      // Это позволяет выбрать тип пассажира для каждого места
      for (final seatNum in _seatNumbers) {
        _seatsWithTypes.add(SeatBooking(
          seatNumber: seatNum,
          passengerType: PassengerType.adult,
        ));
      }
    }
    if (widget.stops.isNotEmpty) {
      _selectedStop = widget.stops.first;
      _stopId = _selectedStop!.id;
    }
  }

  @override
  void dispose() {
    _seatsController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое бронирование'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _seatsController,
                enabled: !widget.lockSeatSelection,
                decoration: InputDecoration(
                  labelText: 'Места',
                  hintText: widget.lockSeatSelection
                      ? 'Места выбраны'
                      : 'Например: 3,5,7 или 3-7',
                  helperText: widget.lockSeatSelection
                      ? 'Места заблокированы'
                      : 'Можно указать несколько мест через запятую (3,5,7) или диапазон (3-7)',
                ),
                keyboardType: TextInputType.text,
                validator: widget.lockSeatSelection
                    ? null
                    : (value) {
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
                onChanged: (value) {
                  if (!widget.lockSeatSelection) {
                    final seats = _parseSeatNumbers(value.trim());
                    setState(() {
                      // Обновляем список мест, сохраняя типы пассажиров для существующих
                      final existingSeats =
                          _seatsWithTypes.map((s) => s.seatNumber).toSet();
                      _seatsWithTypes
                          .removeWhere((s) => !seats.contains(s.seatNumber));
                      for (final seatNum in seats) {
                        if (!existingSeats.contains(seatNum)) {
                          _seatsWithTypes.add(SeatBooking(
                            seatNumber: seatNum,
                            passengerType: PassengerType.adult,
                          ));
                        }
                      }
                    });
                  }
                },
              ),
              if (_seatsWithTypes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Тип пассажира для каждого места:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._seatsWithTypes.map((seatBooking) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Место №${seatBooking.seatNumber}'),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<PassengerType>(
                              value: seatBooking.passengerType,
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
                                    final index = _seatsWithTypes.indexWhere(
                                      (s) =>
                                          s.seatNumber ==
                                          seatBooking.seatNumber,
                                    );
                                    if (index != -1) {
                                      _seatsWithTypes[index] = SeatBooking(
                                        seatNumber: seatBooking.seatNumber,
                                        passengerType: value,
                                      );
                                    }
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    double total = 0;
                    for (final seat in _seatsWithTypes) {
                      final tariff =
                          widget.tariffs[seat.passengerType.apiValue];
                      if (tariff != null) {
                        total += tariff.price;
                      }
                    }
                    return Text(
                      'Итого: ${total.toStringAsFixed(2)} ₽',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя клиента'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите имя';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Телефон клиента'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите телефон';
                  }
                  return null;
                },
              ),
              // Показываем общий тип пассажира только если не используется множественный выбор
              if (widget.lockSeatSelection || _seatsWithTypes.isEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<PassengerType>(
                  value: _passengerType,
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
                      setState(() => _passengerType = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Тип пассажира'),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final tariff = widget.tariffs[_passengerType.apiValue];
                    final pricePerSeat = tariff?.price;
                    if (pricePerSeat != null) {
                      return Text(
                        'Цена за место: ${pricePerSeat.toStringAsFixed(2)} ₽',
                      );
                    }
                    return const Text(
                      'Цена для выбранного типа не настроена',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
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

            // Используем новый формат если выбрано несколько мест с разными типами
            if (_seatsWithTypes.isNotEmpty) {
              // Проверяем, что для всех мест есть тарифы
              for (final seat in _seatsWithTypes) {
                final tariff = widget.tariffs[seat.passengerType.apiValue];
                if (tariff == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Цена для типа "${seat.passengerType.label}" на месте №${seat.seatNumber} не настроена',
                      ),
                    ),
                  );
                  return;
                }
              }

              Navigator.of(context).pop(
                BookingDialogResult(
                  seats: _seatsWithTypes,
                  seatNumbers:
                      _seatsWithTypes.map((s) => s.seatNumber).toList(),
                  pricePerSeat: 0, // Не используется в новом формате
                  customerName: _nameController.text.trim(),
                  customerPhone: _phoneController.text.trim(),
                  passengerType: _passengerType, // Для обратной совместимости
                  stop: _selectedStop!,
                ),
              );
              return;
            }

            // Старый формат: одно место или несколько мест с одним типом
            final seatNumbers = widget.lockSeatSelection
                ? _seatNumbers
                : _parseSeatNumbers(_seatsController.text.trim());

            if (seatNumbers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Введите номера мест')),
              );
              return;
            }

            final pricePerSeat = widget.tariffs[_passengerType.apiValue]?.price;
            if (pricePerSeat == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Цена для выбранного типа не настроена')),
              );
              return;
            }

            Navigator.of(context).pop(
              BookingDialogResult(
                seatNumbers: seatNumbers,
                pricePerSeat: pricePerSeat,
                customerName: _nameController.text.trim(),
                customerPhone: _phoneController.text.trim(),
                passengerType: _passengerType,
                stop: _selectedStop!,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
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
