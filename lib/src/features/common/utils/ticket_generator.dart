import 'dart:math';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/booking.dart';
import '../../../data/models/excursion.dart';
import '../../../data/models/stop.dart';

class TicketGenerator {
  const TicketGenerator._();

  static Future<void> generateAndShare({
    required Excursion excursion,
    required List<int> seatNumbers,
    required double pricePerSeat,
    required String customerName,
    required String customerPhone,
    required PassengerType passengerType,
    required Stop stop,
    required String bookedBy,
  }) async {
    if (seatNumbers.isEmpty) {
      return;
    }

    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final total = pricePerSeat * seatNumbers.length;
    final ticketNumber = 'T-${excursion.id}-${DateTime.now().millisecondsSinceEpoch}-${_randomSuffix()}';

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Электронный билет',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Номер: $ticketNumber'),
              pw.SizedBox(height: 24),
              pw.Text(
                excursion.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Дата и время: ${dateFormatter.format(excursion.dateTime)}'),
              pw.Text('Остановка: ${stop.name}'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text(
                'Покупатель',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Имя: $customerName'),
              pw.Text('Телефон: $customerPhone'),
              pw.Text('Тип пассажира: ${passengerType.label}'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Места',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Номера мест: ${seatNumbers.join(', ')}'),
              pw.Text('Количество мест: ${seatNumbers.length}'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Оплата',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Цена за место: ${pricePerSeat.toStringAsFixed(2)} ₽'),
              pw.Text('Итого к оплате: ${total.toStringAsFixed(2)} ₽'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text('Продавец: $bookedBy'),
              pw.Text('Создан: ${dateFormatter.format(DateTime.now())}'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Пожалуйста, предъявите этот билет при посадке. Перенос и отмена возможны не позднее чем за 24 часа до начала экскурсии.',
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '$ticketNumber.pdf',
    );
  }

  static int _randomSuffix() {
    final random = Random();
    return 1000 + random.nextInt(9000);
  }
}
