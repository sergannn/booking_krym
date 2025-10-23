import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/app_config.dart';
import 'core/storage/token_storage.dart';
import 'features/common/app_shell.dart';

class BookingAppBootstrap {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await TokenStorage.instance.init();
    ApiClient.instance.configure(
      baseUrl: AppConfig.apiBaseUrl,
      tokenProvider: TokenStorage.instance,
    );
    _initialized = true;
  }
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Booking Manager',
        home: AppShell(),
      ),
    );
  }
}
