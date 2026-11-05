import 'dart:async' show StreamController;
import 'dart:convert' show json;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';

import 'constants/argument.dart';
import 'constants/event.dart';
import 'constants/method.dart';
import 'galva_logger.dart';
import 'galva_version.dart';
import 'models/galva_configuration.dart';
import 'models/galva_error.dart';
import 'models/galva_in_app_message.dart';
import 'models/galva_log_level.dart';
import 'models/galva_push_provider.dart';
import 'models/galva_user_attributes.dart';

/// Entry point of the Galva SDK for Flutter. Call [configure] once at launch, then use
/// [Galva.instance] for everything else.
///
/// Each call goes to the native Galva SDK of the platform: `io.galva.sdk:galva-sdk` on Android
/// and `Galva` from galva-ios on iOS. Calls run in order in the background; a returned future
/// completes once the native SDK has accepted the call, not when the data reached Galva.
class Galva {
  static final Galva _instance = Galva._internal();

  factory Galva() => _instance;

  Galva._internal();

  static Galva get instance => _instance;

  /// This plugin's version.
  static String get sdkVersion => galvaFlutterVersion;

  static const String _channelName = 'flutter.galva.io/galva';
  static const MethodChannel _channel = MethodChannel(_channelName);

  final StreamController<GalvaInAppMessage> _inAppMessageController = StreamController.broadcast();

  /// The in-app messages Galva delivers for the current subscriber.
  ///
  /// With [GalvaInAppMessagesPresentation.manual], show each one with [showMessage] when you
  /// choose. With [GalvaInAppMessagesPresentation.automatic], the SDK already shows them, so
  /// listen only to observe. A message delivered while nothing listens isn't delivered again.
  Stream<GalvaInAppMessage> get inAppMessageStream => _inAppMessageController.stream;

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// Starts the SDK. Call it once, as early as you can, for example in `main` after
  /// `WidgetsFlutterBinding.ensureInitialized()`. Later calls are ignored by the native SDK,
  /// so calling it again after a hot restart is safe.
  Future<void> configure(GalvaConfiguration configuration) async {
    GalvaLogger.logLevel = configuration.logLevel;
    _channel.setMethodCallHandler(_tryHandleIncomingMethodCall);
    await _invokeMethod<void>(
      Method.configure,
      (_) {},
      {Argument.configuration: configuration.jsonValue},
    );
  }

  /// Whether the native SDK has been configured.
  Future<bool> isConfigured() => _invokeMethod(Method.isConfigured, (data) => data as bool, null);

  /// Changes how much the SDK logs. On iOS the native level is fixed by [configure], so this
  /// changes only the plugin's own log there.
  Future<void> setLogLevel(GalvaLogLevel value) {
    GalvaLogger.logLevel = value;
    return _invokeMethod<void>(Method.setLogLevel, (_) {}, {Argument.value: value.jsonValue});
  }

  // ── Identity and attributes ───────────────────────────────────────────────

  /// Identifies the subscriber with your user ID, after sign-in and on every launch with a
  /// restored session.
  ///
  /// [email] is checked on the device and dropped when invalid. [androidObfuscatedAccountId] is
  /// the obfuscated account ID your own Play Billing code sets. [iosAppAccountToken] is the
  /// StoreKit app account token (a UUID) your own purchases carry.
  Future<void> identify(
    String userId, {
    String? email,
    String? androidObfuscatedAccountId,
    String? iosAppAccountToken,
  }) {
    return _invokeMethod<void>(Method.identify, (_) {}, {
      Argument.userId: userId,
      Argument.email: ?email,
      Argument.androidObfuscatedAccountId: ?androidObfuscatedAccountId,
      Argument.iosAppAccountToken: ?iosAppAccountToken,
    });
  }

  /// Signs the subscriber out and starts a new anonymous identity. Call it on sign-out, and
  /// before another person signs in on the same device.
  Future<void> logout() => _invokeMethod<void>(Method.logout, (_) {}, null);

  /// Your user ID while a subscriber is identified, otherwise `null`. Right after [configure] it
  /// can read `null` until the SDK has loaded the stored identity.
  Future<String?> getIdentifiedUserId() =>
      _invokeMethod<String?>(Method.getIdentifiedUserId, (data) => data as String?, null);

  /// Sets attributes on the current subscriber, for audiences and message variables.
  Future<void> setAttributes(GalvaUserAttributes attributes) {
    return _invokeMethod<void>(Method.setAttributes, (_) {}, {Argument.attributes: attributes.jsonValue});
  }

  /// Records an event for the current subscriber. Attribute values that aren't
  /// JSON-compatible are dropped, and a blank [eventName] is ignored.
  Future<void> track(String eventName, {Map<String, Object?>? attributes}) {
    return _invokeMethod<void>(Method.track, (_) {}, {
      Argument.eventName: eventName,
      if (attributes != null && attributes.isNotEmpty) Argument.attributes: attributes,
    });
  }

  // ── Privacy ───────────────────────────────────────────────────────────────

  /// Turns sending off or back on. While opted out, identify, attributes, events, push tokens
  /// and session starts are dropped, and queued updates are deleted. In-app messages keep
  /// working. The choice persists across launches.
  Future<void> setOptOut(bool optedOut) => _invokeMethod<void>(Method.setOptOut, (_) {}, {Argument.value: optedOut});

  /// The current opt-out choice.
  Future<bool> isOptedOut() => _invokeMethod(Method.isOptedOut, (data) => data as bool, null);

  // ── In-app messages and links ─────────────────────────────────────────────

  /// Checks Galva for a waiting message now, instead of on the next return to the foreground.
  Future<void> checkForMessages() => _invokeMethod<void>(Method.checkForMessages, (_) {}, null);

  /// Shows [message] full screen over your app. Completes once it's on its way; throws a
  /// [GalvaError] when it can't show.
  Future<void> showMessage(GalvaInAppMessage message) {
    return _invokeMethod<void>(Method.showMessage, (_) {}, {Argument.message: message.jsonValue});
  }

  /// Hands a link to Galva. Returns `true` for a Galva link (a scheme starting with `gv`), which
  /// the SDK then opens, and `false` for any other link, so you can route your own after it.
  /// Call it from your deep link handling, such as `app_links`' stream.
  Future<bool> handleOpenUrl(String url) =>
      _invokeMethod(Method.handleOpenUrl, (data) => data as bool, {Argument.url: url});

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Android: registers the device's push token, for example from `firebase_messaging`'s
  /// `getToken()` and `onTokenRefresh`. Does nothing on iOS, where the plugin forwards the APNs
  /// token on its own; see [setApnsToken].
  Future<void> setPushToken(String token, {GalvaPushProvider provider = GalvaPushProvider.fcm}) async {
    if (!_isAndroid) return _skip(Method.setPushToken);
    await _invokeMethod<void>(Method.setPushToken, (_) {}, {
      Argument.token: token,
      Argument.provider: provider.jsonValue,
    });
  }

  /// iOS: registers an APNs device token, hex-encoded, such as `firebase_messaging`'s
  /// `getAPNSToken()`. The plugin already forwards the token iOS gives your app delegate, so
  /// call this only if your app delegate doesn't pass it on. Does nothing on Android.
  Future<void> setApnsToken(String hexToken) async {
    if (!_isIOS) return _skip(Method.setApnsToken);
    await _invokeMethod<void>(Method.setApnsToken, (_) {}, {Argument.token: hexToken});
  }

  /// Android: removes the push token from the device and asks Galva to delete it, for example
  /// when the subscriber turns notifications off in your app. Does nothing on iOS.
  Future<void> clearPushToken() async {
    if (!_isAndroid) return _skip(Method.clearPushToken);
    await _invokeMethod<void>(Method.clearPushToken, (_) {}, null);
  }

  /// Android: whether a push's data comes from Galva. Always `false` on iOS.
  Future<bool> isGalvaNotification(Map<String, String> data) async {
    if (!_isAndroid) return false;
    return _invokeMethod(Method.isGalvaNotification, (data) => data as bool, {Argument.data: data});
  }

  /// Android: shows a Galva push as a notification and records it. Call it for messages that
  /// reach your app while it's in the foreground, such as `FirebaseMessaging.onMessage`, when
  /// [isGalvaNotification] is `true`. Does nothing on iOS, where the system shows pushes.
  Future<void> handlePush(Map<String, String> data) async {
    if (!_isAndroid) return _skip(Method.handlePush);
    await _invokeMethod<void>(Method.handlePush, (_) {}, {Argument.data: data});
  }

  // ── Purchases ─────────────────────────────────────────────────────────────

  /// Reports the device's newest store purchase to Galva now, instead of on the next return to
  /// the foreground. Call it after your own paywall completes a purchase, and from "Restore".
  Future<void> reconcileTransactions() => _invokeMethod<void>(Method.reconcileTransactions, (_) {}, null);

  // ── Channel ───────────────────────────────────────────────────────────────

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static void _skip(String method) {
    GalvaLogger.write(GalvaLogLevel.debug, 'Galva.$method() does nothing on ${defaultTargetPlatform.name}');
  }

  Future<T> _invokeMethod<T>(
    String method,
    T Function(dynamic) responseParser,
    Map<String, dynamic>? arguments,
  ) async {
    final stamp = GalvaLogger.stamp;
    final stringArguments = json.encode(arguments ?? const {});
    GalvaLogger.write(GalvaLogLevel.verbose, '[$stamp] --> Galva.$method(), Args: $stringArguments');

    try {
      final stringResult = await _channel.invokeMethod<String>(method, stringArguments);
      GalvaLogger.write(GalvaLogLevel.verbose, '[$stamp] <-- Galva.$method(), Result: $stringResult');

      if (stringResult == null) {
        throw GalvaError('Galva.$method() returned null', GalvaErrorCode.emptyResult, null);
      }

      final decodedResult = json.decode(stringResult) as Map<String, dynamic>;
      if (decodedResult.containsKey(Argument.error)) {
        throw GalvaErrorJSONBuilder.fromJsonValue(decodedResult[Argument.error] as Map<String, dynamic>);
      }
      return responseParser(decodedResult[Argument.success]);
    } on GalvaError catch (e) {
      GalvaLogger.write(GalvaLogLevel.warn, '[$stamp] <-- Galva.$method() Error: $e');
      rethrow;
    } on MissingPluginException catch (e) {
      throw GalvaError(
        'Galva.$method() has no native implementation on this platform',
        GalvaErrorCode.methodNotImplemented,
        e.toString(),
      );
    } catch (e) {
      final error = GalvaError('Internal plugin error in Galva.$method()', GalvaErrorCode.internalPluginError, e.toString());
      GalvaLogger.write(GalvaLogLevel.error, '[$stamp] <-- Galva.$method() Error: $error');
      throw error;
    }
  }

  Future<dynamic> _tryHandleIncomingMethodCall(MethodCall call) async {
    try {
      return await _handleIncomingMethodCall(call);
    } catch (e) {
      GalvaLogger.write(GalvaLogLevel.error, 'Error handling ${call.method} from the native SDK: $e');
      return null;
    }
  }

  Future<dynamic> _handleIncomingMethodCall(MethodCall call) async {
    final arguments = json.decode(call.arguments as String) as Map<String, dynamic>;
    GalvaLogger.write(GalvaLogLevel.verbose, 'handleIncomingCall ${call.method} Args: $arguments');

    switch (call.method) {
      case Event.inAppMessageReceived:
        _inAppMessageController.add(
          GalvaInAppMessageJSONBuilder.fromJsonValue(arguments[Argument.message] as Map<String, dynamic>),
        );
      default:
        GalvaLogger.write(GalvaLogLevel.debug, 'Ignoring unknown event ${call.method}');
    }
    return null;
  }
}
