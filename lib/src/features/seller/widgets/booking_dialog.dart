import 'package:flutter/material.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/excursion.dart';

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

  @override
  void initState() {
    super.initState();
    _seatNumbers = List<int>.from(widget.initialSeatNumbers);
    if (_seatNumbers.isNotEmpty) {
      _seatsController.text = _seatNumbers.join(',');
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
                decoration: const InputDecoration(
                  labelText: 'Место',
                  hintText: 'Например: 3',
                  helperText: 'Можно забронировать только одно место',
                ),
                keyboardType: TextInputType.number,
                validator: widget.lockSeatSelection
                    ? null
                    : (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите номер места';
                        }
                        final seatNumber = int.tryParse(value.trim());
                        if (seatNumber == null || seatNumber <= 0) {
                          return 'Введите корректный номер места';
                        }
                        return null;
                      },
              ),
              const SizedBox(height: 12),
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
            final seatNumbers = widget.lockSeatSelection
                ? _seatNumbers
                : [
                    int.tryParse(_seatsController.text.trim()) ?? 0,
                  ].where((n) => n > 0).toList();
            if (seatNumbers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Введите номер места')),
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
}

class BookingDialogResult {
  const BookingDialogResult({
    required this.seatNumbers,
    required this.pricePerSeat,
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    required this.stop,
  });

  final List<int> seatNumbers;
  final double pricePerSeat;
  final String customerName;
  final String customerPhone;
  final PassengerType passengerType;
  final Stop stop;

  int get stopId => stop.id;
}
