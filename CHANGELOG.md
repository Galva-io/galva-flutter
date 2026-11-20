## 1.1.1

* Android: fixes in-app messages not showing with `GalvaInAppMessagesPresentation.automatic`. Dart calls `configure` once `MainActivity` is already on screen, so the native SDK never saw that activity resume and logged `In-app message <id> not shown — no visible activity`. The plugin now passes the current activity to `configure`, and `io.galva.sdk:galva-sdk` 1.5.2 uses it. iOS stays on galva-ios 1.0.0.

## 1.1.0

* Android: `io.galva.sdk:galva-sdk` 1.5.1, which fixes a crash in Play Billing when the billing client answers a storefront or product query twice (the second answer resumed a finished call). iOS stays on galva-ios 1.0.0.

## 1.0.0

* First version: configure, identify and log out, attributes, events, opt-out, in-app messages (automatic or manual), deep links, push tokens (FCM, Huawei and Amazon on Android, APNs on iOS) and purchase reconciliation, on top of the native Galva SDKs: `io.galva.sdk:galva-sdk` 1.5.0 on Android and galva-ios 1.0.0 on iOS.
