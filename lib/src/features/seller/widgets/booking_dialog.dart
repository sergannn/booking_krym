import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/booking.dart';
import '../../../data/models/stop.dart';

class BookingDialog extends StatefulWidget {
  const BookingDialog({
    super.key,
    required this.stops,
  });

  final List<Stop> stops;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _seatsController = TextEditingController();
  final _priceController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  PassengerType _passengerType = PassengerType.adult;
  int? _stopId;

  @override
  void dispose() {
    _seatsController.dispose();
    _priceController.dispose();
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
                decoration: const InputDecoration(
                  labelText: 'Места',
                  hintText: 'Например: 3,7,11',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите номера мест';
                  }
                  final hasNumbers = value.split(',').map((item) =>
                      int.tryParse(item.trim())).whereType<int>().isNotEmpty;
                  if (!hasNumbers) {
                    return 'Неверный формат';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Цена за место'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите цену';
                  }
                  final numeric = value.replaceAll(',', '.');
                  final parsed = double.tryParse(numeric);
                  if (parsed == null || parsed <= 0) {
                    return 'Некорректная цена';
                  }
                  return null;
                },
              ),
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
                onChanged: (value) => setState(() => _stopId = value),
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
            final seatNumbers = _seatsController.text
                .split(',')
                .map((item) => int.tryParse(item.trim()))
                .whereType<int>()
                .toList();
            Navigator.of(context).pop(
              BookingDialogResult(
                seatNumbers: seatNumbers,
                price: double.parse(
                    _priceController.text.replaceAll(',', '.')),
                customerName: _nameController.text.trim(),
                customerPhone: _phoneController.text.trim(),
                passengerType: _passengerType,
                stopId: _stopId!,
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
    required this.price,
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    required this.stopId,
  });

  final List<int> seatNumbers;
  final double price;
  final String customerName;
  final String customerPhone;
  final PassengerType passengerType;
  final int stopId;
}
