import 'package:flutter/material.dart';
import 'src/app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';


Future<void> main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await BookingAppBootstrap.ensureInitialized();
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://9b9cf1cfa024ec5de94b28ad731bf8ae@o4509209029640192.ingest.de.sentry.io/4510658362015824';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(child: const BookingApp())),
  );
  // TODO: Remove this line after sending the first sample event to sentry.
  await Sentry.captureException(Exception('This is a sample exception.'));
}
