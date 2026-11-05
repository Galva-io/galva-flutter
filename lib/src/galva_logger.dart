import 'dart:developer' as developer;
import 'dart:math' show Random;

import 'galva_version.dart';
import 'models/galva_log_level.dart';

/// The Dart side's own log, for channel traffic. The native SDKs log to Logcat (`Galva` tag)
/// and the unified log (`co.galva.sdk` subsystem).
class GalvaLogger {
  static GalvaLogLevel logLevel = GalvaLogLevel.warn;

  static void write(GalvaLogLevel level, String message) {
    if (level == GalvaLogLevel.none || level.index > logLevel.index) return;
    developer.log(
      '${level.name.toUpperCase()}: $message',
      name: 'GalvaFlutter $galvaFlutterVersion',
    );
  }

  static final _random = Random();
  static const _stampChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /// A short random tag that ties a call's request and response lines together.
  static String get stamp => List.generate(4, (_) => _stampChars[_random.nextInt(_stampChars.length)]).join();
}
