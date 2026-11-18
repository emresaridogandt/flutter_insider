# Insider Flutter SDK

[![pub package](https://img.shields.io/pub/v/flutter_insider.svg)](https://pub.dev/packages/flutter_insider)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Official Flutter plugin for the [Insider](https://insiderone.com/) marketing
and growth platform. Wraps the native Insider SDK on Android and iOS and
exposes its features — user identification, event tracking, product and
purchase events, push notifications, smart recommendations, content
optimizer, message center and App Cards — through a unified Dart API.

## Installation

Add the plugin to your `pubspec.yaml`:

```bash
flutter pub add flutter_insider
```

## Platform requirements

| Platform | Minimum |
|----------|---------|
| Flutter  | `>=2.8.0` |
| Dart     | `>=2.15.0 <4.0.0` |
| Android  | `minSdk 24`, `compileSdk 36` |
| iOS      | deployment target `12.2` (CocoaPods), `12.0` (Swift Package Manager) |

### iOS: CocoaPods or Swift Package Manager

The plugin ships both a podspec and a `Package.swift`, so it works with whichever
dependency manager your Flutter project uses. Nothing in your Dart code changes.

**CocoaPods** (the default on Flutter below 3.44):

```bash
cd ios && pod install
```

**Swift Package Manager** — enabled by default from Flutter 3.44; on Flutter 3.24–3.43 turn it
on once:

```bash
flutter config --enable-swift-package-manager
```

Flutter then resolves the plugin's Swift package for you — there is no `pod install` step.
CocoaPods requires iOS `12.2`, the floor of the pinned native pods; Swift Package Manager keeps
`12.0`. The Insider native SDK versions come from different
places, though: CocoaPods installs the exact versions pinned in the plugin's podspec, while Swift
Package Manager follows the `main` branch of the public
[`useinsider/Insider-iOS-SDK`](https://github.com/useinsider/Insider-iOS-SDK) package. The two
channels can therefore name different native versions between plugin releases; today both carry
`InsiderMobile` 16.3.0.

**Upgrading an app that builds with Swift Package Manager.** Swift Package Manager is on by
default from Flutter 3.44, and the plugin's Swift package embeds `InsiderMobileAdvancedNotification`
in the app. If your `Podfile` adds the `InsiderMobileAdvancedNotification` pod to your notification
extension targets, remove those pods in the same change that upgrades the plugin. If they stay, the
build fails with `Multiple commands produce …InsiderMobileAdvancedNotification.framework`. If you
remove them before upgrading, the extensions lose the framework, because earlier plugin versions do
not provide it. Apps that build with CocoaPods are not affected.

**Notification extensions with Swift Package Manager.** The plugin embeds
`InsiderMobileAdvancedNotification` in the app, and Xcode passes the package's framework search
path to every target in the project, so the notification service and content extensions link it
with a plain `import` — no extra package or product needs to be added to the extension targets.
Two things do need attention:

- Remove the `InsiderMobileAdvancedNotification` pod from the extension targets in your `Podfile`
  (or drop the `Podfile` entirely if nothing else needs it). If CocoaPods keeps embedding the
  same framework, the build fails with `Multiple commands produce …InsiderMobileAdvancedNotification.framework`.
- The content extension's `InsiderInterface.storyboard` lives in the `Insider-iOS-SDK` package in a
  target that is not exported as a product, so nothing links it for you — copy the storyboard from
  the package checkout (or the SDK zip) into the content extension target.

For Android, the plugin pulls in Firebase Messaging, Google Play Services
location, and Huawei HMS push as transitive dependencies. No extra Gradle
configuration is required.

## Quick start

```dart
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/enum/InsiderCallbackAction.dart';

Future<void> bootstrapInsider() async {
  await FlutterInsider.Instance.init(
    'YOUR_PARTNER_NAME',
    'group.com.example.app', // iOS App Group; pass any value on Android.
    (int actionType, dynamic data) {
      switch (actionType) {
        case InsiderCallbackAction.NOTIFICATION_OPEN:
          // Handle push tap.
          break;
        case InsiderCallbackAction.INAPP_BUTTON_CLICK:
          // Handle in-app button tap.
          break;
      }
    },
  );

  // Identify the user.
  FlutterInsider.Instance
      .getCurrentUser()
      ?.setName('Ada')
      .setEmail('ada@example.com')
      .setEmailOptin(true);

  // Tag a custom event with typed parameters.
  await FlutterInsider.Instance
      .tagEvent('add_to_favorites')
      .addParameterWithString('product_id', 'sku-123')
      .addParameterWithDouble('price', 29.99)
      .build();
}
```

### Multiple apps under one partner

If one partner has several apps, pass the optional named `appIdentifier` parameter to
`init` (or `initWithCustomEndpoint`) so sessions and push targeting are
attributed to that app (`callback` is the `(int actionType, dynamic data)`
handler from Quick start):

```dart
await FlutterInsider.Instance.init('YOUR_PARTNER_NAME', 'group.com.example.app', callback, appIdentifier: 'shop_app');

// With an SDK constraint of >=2.17, the named argument may also precede the callback:
await FlutterInsider.Instance.init('YOUR_PARTNER_NAME', 'group.com.example.app', appIdentifier: 'shop_app', callback);
```

- The value must match `^[a-z0-9][a-z0-9_]{0,49}$`. The native SDK validates
  it: an invalid value is logged and treated as unset, and init still completes.
- A `null` or empty `appIdentifier` is ignored, and the SDK initializes exactly as without it.
- `reinitWithPartnerName` with a different partner name clears the app identifier on both
  platforms; a reinit with the same partner name is ignored and keeps it.

## Features

| Area | API entry point |
|------|-----------------|
| User attributes & login | [`FlutterInsider.getCurrentUser()`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsider/getCurrentUser.html) → `FlutterInsiderUser` |
| Custom events | [`FlutterInsider.tagEvent`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsider/tagEvent.html) → `FlutterInsiderEvent` |
| Product / purchase events | `visitProductDetailPage`, `itemAddedToCart`, `itemPurchased`, `cartCleared`, `visitWishlistPage` |
| Smart recommendations | `getSmartRecommendation`, `getSmartRecommendationWithProduct`, `getSmartRecommendationWithProductIDs` |
| Content optimizer | `getContentStringWithName`, `getContentIntWithName`, `getContentBoolWithName`, `markContentOptimizerAsSeen` |
| Push notifications | `setPushToken`, `handleNotification`, `setForegroundPushCallback` |
| Message center | `getMessageCenterData`, `getMessageCenterDataWithIdentifiers` |
| App Cards | [`FlutterInsider.appCards`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsider/appCards.html) → [`FlutterInsiderAppCards`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsiderAppCards-class.html) |
| Event listener | [`FlutterInsider.events`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsider/events.html) → [`FlutterInsiderEvents`](https://pub.dev/documentation/flutter_insider/latest/flutter_insider/FlutterInsiderEvents-class.html) |
| GDPR / privacy | `setGDPRConsent`, `setMobileAppAccess`, `enableIDFACollection`, `enableIpCollection`, `enableLocationCollection` |

Full API reference: <https://pub.dev/documentation/flutter_insider/latest>

## Documentation

- API reference: <https://pub.dev/documentation/flutter_insider/latest>
- Changelog: <https://pub.dev/packages/flutter_insider/changelog>
- Sample app & issues: <https://github.com/useinsider/FlutterDemo>
- Insider website: <https://insiderone.com/>

For panel-side setup — partner name, campaign and placement configuration —
contact your Insider account manager.

## License

flutter_insider is released under the MIT License. See
<https://pub.dev/packages/flutter_insider/license>.
