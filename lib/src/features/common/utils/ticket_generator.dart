import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/booking.dart';
import '../../../data/models/excursion.dart';
import '../../../data/models/stop.dart';

// Условный импорт для веб-платформы
import 'dart:html' as html show AnchorElement, Blob, Url;

class TicketGenerator {
  const TicketGenerator._();

  // Кэш для шрифта с поддержкой кириллицы
  static pw.Font? _cyrillicFont;

  /// Загружает шрифт с поддержкой кириллицы
  static Future<pw.Font> _loadCyrillicFont() async {
    if (_cyrillicFont != null) {
      return _cyrillicFont!;
    }

    try {
      // Загружаем шрифт Roboto из assets
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _cyrillicFont = pw.Font.ttf(fontData);
      return _cyrillicFont!;
    } catch (e) {
      // Если не удалось загрузить шрифт, используем встроенный шрифт
      // (кириллица может отображаться некорректно)
      _cyrillicFont = pw.Font.helvetica();
      return _cyrillicFont!;
    }
  }

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
    final ticketNumber =
        'T-${excursion.id}-${DateTime.now().millisecondsSinceEpoch}-${_randomSuffix()}';

    // Загружаем шрифт с поддержкой кириллицы
    final font = await _loadCyrillicFont();

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
                  font: font,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Номер: $ticketNumber',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                excursion.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  font: font,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Дата и время: ${dateFormatter.format(excursion.dateTime)}',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Остановка: ${stop.name}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text(
                'Покупатель',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  font: font,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Имя: $customerName',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Телефон: $customerPhone',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Тип пассажира: ${passengerType.label}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Места',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  font: font,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Номера мест: ${seatNumbers.join(', ')}',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Количество мест: ${seatNumbers.length}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Оплата',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  font: font,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Цена за место: ${pricePerSeat.toStringAsFixed(2)} ₽',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Итого к оплате: ${total.toStringAsFixed(2)} ₽',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text(
                'Продавец: $bookedBy',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                'Создан: ${dateFormatter.format(DateTime.now())}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Пожалуйста, предъявите этот билет при посадке. Перенос и отмена возможны не позднее чем за 24 часа до начала экскурсии.',
                style: pw.TextStyle(fontSize: 10, font: font),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      // Для веб-платформы: скачиваем файл через Blob URL
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '$ticketNumber.pdf');
      anchor.click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Для мобильных платформ: используем Printing.sharePdf
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '$ticketNumber.pdf',
      );
    }
  }

  static int _randomSuffix() {
    final random = Random();
    return 1000 + random.nextInt(9000);
  }
}
