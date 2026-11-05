import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/galva_error_json_builder.dart';

/// An error from a Galva call. [code] is one of [GalvaErrorCode].
@immutable
class GalvaError implements Exception {
  final String message;
  final String? detail;
  final int code;

  const GalvaError(this.message, this.code, this.detail);

  @override
  String toString() => '(code: $code, message: $message, detail: $detail)';
}

/// Codes of [GalvaError]. The native plugins use the same numbers.
class GalvaErrorCode {
  /// The native side returned no result.
  static const int emptyResult = 1;

  /// A request's arguments couldn't be read.
  static const int invalidArguments = 2;

  /// The plugin doesn't know the method, usually a plugin version mismatch.
  static const int methodNotImplemented = 3;

  /// The call isn't available on this platform, such as [Galva.handlePush] on iOS.
  static const int unsupportedPlatform = 4;

  /// `configure` hasn't run.
  static const int notConfigured = 5;

  /// There's no activity or window to show an in-app message on.
  static const int noPresenter = 6;

  /// The message isn't one the SDK delivered, or Galva no longer offers it.
  static const int messageNotFound = 7;

  /// Showing the message failed: Galva's servers couldn't be reached, or its page isn't available.
  static const int messageUnavailable = 8;

  /// Anything else that failed inside the plugin.
  static const int internalPluginError = 9;

  /// The native response couldn't be decoded.
  static const int decodingFailed = 10;
}
