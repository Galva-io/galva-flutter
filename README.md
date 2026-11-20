# Galva SDK for Flutter

Connects your Flutter app to [Galva](https://galva.io): Galva decides which subscribers need a nudge (failed renewals, trials about to end, users about to churn) and reaches them with in-app messages, push notifications and emails.

The plugin wraps the native Galva SDKs, pinned to one version each:

| galva_flutter | Android: [`io.galva.sdk:galva-sdk`](https://central.sonatype.com/artifact/io.galva.sdk/galva-sdk) | iOS: [galva-ios](https://github.com/Galva-io/galva-ios) |
| --- | --- | --- |
| 1.1.1 | 1.5.2 | 1.0.0 |
| 1.1.0 | 1.5.1 | 1.0.0 |
| 1.0.0 | 1.5.0 | 1.0.0 |

**Requirements:** Flutter 3.32+, Android minSdk 24 with Kotlin 2.1+ (Flutter's current templates use 2.4), iOS 15+ built with Xcode 26+ and Swift Package Manager.

---

## 1. Install

```yaml
dependencies:
  galva_flutter: ^1.1.1
```

**Android.** Raise `minSdk` to 24 in `android/app/build.gradle.kts` if it's lower. The plugin brings the Galva SDK and Google Play Billing 8 from Maven Central.

**iOS.** galva-ios is distributed through Swift Package Manager only, so turn on Flutter's Swift Package Manager support if your app doesn't use it yet:

```bash
flutter config --enable-swift-package-manager
```

## 2. Configure

Configure Galva once, at launch:

```dart
import 'package:flutter/widgets.dart';
import 'package:galva_flutter/galva_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Galva.instance.configure(
    const GalvaConfiguration(
      apiKey: 'pk_your_app_id', // your App ID from the Galva dashboard
      logLevel: GalvaLogLevel.warn,
    ),
  );
  runApp(const MyApp());
}
```

- An App ID works only in the environment it was issued for: `GalvaEnvironment.production` (the default) or `GalvaEnvironment.development`.
- Tell Galva who the user is: `Galva.instance.identify(userId)` after sign-in and on every start with a restored session, and `Galva.instance.logout()` on sign-out.
- Every call returns a `Future` that completes once the native SDK has the call, and throws a `GalvaError` when it can't take it.

## 3. Attributes and events

```dart
await Galva.instance.identify('user_42', email: 'ana@example.com');

await Galva.instance.setAttributes(
  const GalvaUserAttributes(firstName: 'Ana', custom: {'plan_tier': 'pro'}),
);

await Galva.instance.track('Purchase', attributes: {'sku': 'pro_yearly', 'price': 9.99});
```

To honor a privacy setting, call `Galva.instance.setOptOut(true)`: nothing is sent until `setOptOut(false)`, and in-app messages keep working.

## 4. In-app messages

By default the SDK shows each message itself, over your app, as soon as it's ready. To choose when messages appear, configure `inAppMessages: GalvaInAppMessagesPresentation.manual`, listen to the stream and show each message:

```dart
Galva.instance.inAppMessageStream.listen((message) {
  if (onboardingInProgress) return; // skip it
  Galva.instance.showMessage(message);
});
```

Galva checks for a message at launch and on each return to the foreground. Call `Galva.instance.checkForMessages()` after an action that should trigger one.

## 5. Deep links

Galva's emails and pushes link to a message with your app's scheme (`gv-…`, shown in the Galva dashboard). Declare it on both platforms (an intent filter on Android, `CFBundleURLTypes` on iOS), then pass incoming links to Galva, for example from [app_links](https://pub.dev/packages/app_links):

```dart
AppLinks().uriLinkStream.listen((uri) async {
  if (await Galva.instance.handleOpenUrl(uri.toString())) return; // Galva opens the message
  // ...your own links
});
```

A link that arrives before `identify` is kept and opened right after it.

## 6. Push notifications

Galva sends pushes through Firebase Cloud Messaging on Android and APNs on iOS.

- **iOS:** the plugin forwards the APNs token your app delegate receives, so there's nothing to call. If your app delegate doesn't pass it on, call `Galva.instance.setApnsToken(hexToken)`.
- **Android:** register the FCM token, and show Galva's pushes that arrive while the app is in the foreground:

```dart
final messaging = FirebaseMessaging.instance;
await Galva.instance.setPushToken((await messaging.getToken())!);
messaging.onTokenRefresh.listen(Galva.instance.setPushToken);

FirebaseMessaging.onMessage.listen((message) async {
  final data = message.data.map((key, value) => MapEntry(key, '$value'));
  if (await Galva.instance.isGalvaNotification(data)) {
    await Galva.instance.handlePush(data);
  }
});
```

Huawei and Amazon devices without Google Play services pass `provider: GalvaPushProvider.hms` or `.adm`.

## 7. Purchases

Offers in Galva's messages are bought through Google Play Billing and StoreKit with no code. After your own paywall completes a purchase, call `Galva.instance.reconcileTransactions()` so Galva links it to the subscriber right away.

---

## How the plugin works

It follows [Adapty's Flutter SDK](https://github.com/adaptyteam/AdaptySDK-Flutter) architecture:

- `lib/src/galva.dart` calls one method channel, `flutter.galva.io/galva`, with a JSON string of arguments, and reads back `{"success": …}` or `{"error": {code, message, detail}}`.
- [cross_platform.yaml](cross_platform.yaml) defines every request, response and event. `lib/src/constants` and both native implementations follow it.
- `GalvaCrossplatform` on each platform ([Kotlin](android/src/main/kotlin/io/galva/flutter/crossplatform/GalvaCrossplatform.kt), [Swift](ios/galva_flutter/Sources/galva_flutter/GalvaCrossplatform.swift)) decodes a request, calls the native SDK's public API and encodes the answer. Delivered in-app messages come back as `in_app_message_received` events.
- Models live in `lib/src/models`, each with its JSON builder in `lib/src/models/private`.

## Development

```bash
flutter test                       # Dart tests, against a mocked channel
cd example && flutter run --dart-define=GALVA_API_KEY=pk_... --dart-define=GALVA_ENV=development
```

License: MIT
