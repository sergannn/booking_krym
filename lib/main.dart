import 'package:flutter/material.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BookingAppBootstrap.ensureInitialized();
  runApp(const BookingApp());
}
