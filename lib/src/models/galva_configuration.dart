import 'package:meta/meta.dart' show immutable;

import '../galva_version.dart';
import 'galva_environment.dart';
import 'galva_log_level.dart';

part 'private/galva_configuration_json_builder.dart';

/// How Galva's in-app messages reach the screen.
enum GalvaInAppMessagesPresentation {
  /// The SDK shows each message itself, on your app's visible screen, as soon as it's ready.
  /// [Galva.inAppMessageStream] still emits each message, for observing only.
  automatic,

  /// The SDK shows nothing on its own. Listen to [Galva.inAppMessageStream] and call
  /// [Galva.showMessage] when you choose. A Galva link still shows its message right away.
  manual,
}

/// How [Galva.configure] sets the SDK up.
@immutable
class GalvaConfiguration {
  /// Your App ID, from **Admin** > **Settings** > **Connect** > **Client SDKs**. Starts with `pk_`.
  final String apiKey;

  /// The Galva backend. [GalvaEnvironment.production] by default.
  final GalvaEnvironment environment;

  /// How much the native SDKs log. [GalvaLogLevel.warn] by default.
  final GalvaLogLevel logLevel;

  /// How in-app messages reach the screen. [GalvaInAppMessagesPresentation.automatic] by default.
  final GalvaInAppMessagesPresentation inAppMessages;

  /// Sends `session_start` when the app comes to the foreground at least 30 minutes after the
  /// last one. `true` by default.
  final bool autoTrackSessions;

  /// iOS only: resolves Apple Search Ads attribution once per install. `true` by default.
  final bool iosAppleSearchAds;

  const GalvaConfiguration({
    required this.apiKey,
    this.environment = GalvaEnvironment.production,
    this.logLevel = GalvaLogLevel.warn,
    this.inAppMessages = GalvaInAppMessagesPresentation.automatic,
    this.autoTrackSessions = true,
    this.iosAppleSearchAds = true,
  });
}
