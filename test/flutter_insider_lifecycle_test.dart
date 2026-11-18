@Tags(['integration'])
library flutter_insider_lifecycle_test;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/src/constants.dart';

import 'wire_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_insider');
  final insider = FlutterInsider.Instance;

  group('FlutterInsider lifecycle wire contract', () {
    registerWireCases([
      WireCase(
        name: 'registerWithQuietPermission true',
        action: () => insider.registerWithQuietPermission(true),
        wireMethod: Constants.REGISTER_WITH_QUIET_PERMISSION,
        wireArgs: <String, Object?>{'permission': true},
      ),
      WireCase(
        name: 'registerWithQuietPermission false',
        action: () => insider.registerWithQuietPermission(false),
        wireMethod: Constants.REGISTER_WITH_QUIET_PERMISSION,
        wireArgs: <String, Object?>{'permission': false},
      ),
      WireCase(
        name: 'enableIDFACollection',
        action: () => insider.enableIDFACollection(true),
        wireMethod: Constants.ENABLE_IDFA_COLLECTION,
        wireArgs: <String, Object?>{'enableIDFACollection': true},
      ),
      WireCase(
        name: 'enableCarrierCollection',
        action: () => insider.enableCarrierCollection(true),
        wireMethod: Constants.ENABLE_CARRIER_COLLECTION,
        wireArgs: <String, Object?>{'enableCarrierCollection': true},
      ),
      WireCase(
        name: 'enableIpCollection',
        action: () => insider.enableIpCollection(true),
        wireMethod: Constants.ENABLE_IP_COLLECTION,
        wireArgs: <String, Object?>{'enableIpCollection': true},
      ),
      WireCase(
        name: 'enableLocationCollection',
        action: () => insider.enableLocationCollection(true),
        wireMethod: Constants.ENABLE_LOCATION_COLLECTION,
        wireArgs: <String, Object?>{'enableLocationCollection': true},
      ),
      WireCase(
        name: 'startTrackingGeofence (no args)',
        action: () => insider.startTrackingGeofence(),
        wireMethod: Constants.START_TRACKING_GEOFENCE,
        wireArgs: null,
      ),
      WireCase(
        name: 'setAllowsBackgroundLocationUpdates',
        action: () => insider.setAllowsBackgroundLocationUpdates(true),
        wireMethod: Constants.SET_ALLOWS_BACKGROUND_LOCATION_UPDATES,
        wireArgs: <String, Object?>{'allowsBackgroundLocationUpdates': true},
      ),
      WireCase(
        name: 'handleNotification unwraps the "data" field',
        action: () => insider.handleNotification(<String, dynamic>{
          'data': <String, String>{'k': 'v'},
        }),
        wireMethod: Constants.HANDLE_NOTIFICATION,
        wireArgs: <String, Object?>{
          'notification': <String, String>{'k': 'v'},
        },
      ),
      WireCase(
        name: 'triggerPushProcessWithNotificationData',
        action: () => insider.triggerPushProcessWithNotificationData(
          <String, String>{'a': '1'},
        ),
        wireMethod: Constants.TRIGGER_PUSH_PROCESS_WITH_NOTIFICATION_DATA,
        wireArgs: <String, Object?>{
          'notification': <String, String>{'a': '1'},
        },
      ),
      WireCase(
        name: 'setGDPRConsent true',
        action: () => insider.setGDPRConsent(true),
        wireMethod: Constants.SET_GDPR_CONSENT,
        wireArgs: <String, Object?>{'consent': true},
      ),
      WireCase(
        name: 'setMobileAppAccess',
        action: () => insider.setMobileAppAccess(true),
        wireMethod: Constants.SET_MOBILE_APP_ACCESS,
        wireArgs: <String, Object?>{'mobileAppAccess': true},
      ),
      WireCase(
        name: 'removeInapp (no args)',
        action: () => insider.removeInapp(),
        wireMethod: Constants.REMOVE_INAPP,
        wireArgs: null,
      ),
      WireCase(
        name: 'reinitWithPartnerName',
        action: () => insider.reinitWithPartnerName('newPartner'),
        wireMethod: Constants.REINIT_WITH_PARTNER_NAME,
        wireArgs: <String, Object?>{'newPartnerName': 'newPartner'},
      ),
      WireCase(
        name: 'setPushToken',
        action: () => insider.setPushToken('abc-123'),
        wireMethod: Constants.SET_PUSH_TOKEN,
        wireArgs: <String, Object?>{'pushToken': 'abc-123'},
      ),
      WireCase(
        name: 'disableInAppMessages',
        action: () => insider.disableInAppMessages(),
        wireMethod: Constants.DISABLE_IN_APP_MESSAGES,
        wireArgs: null,
      ),
      WireCase(
        name: 'enableInAppMessages',
        action: () => insider.enableInAppMessages(),
        wireMethod: Constants.ENABLE_IN_APP_MESSAGES,
        wireArgs: null,
      ),
      WireCase(
        name: 'handleUniversalLink',
        action: () => insider.handleUniversalLink('https://x.test'),
        wireMethod: Constants.HANDLE_UNIVERSAL_LINK,
        wireArgs: <String, Object?>{'universalLink': 'https://x.test'},
      ),
      WireCase(
        name: 'setInternalBrowserCloseButtonPosition',
        action: () => insider.setInternalBrowserCloseButtonPosition('topRight'),
        wireMethod: Constants.SET_INTERNAL_BROWSER_CLOSE_BUTTON_POSITION,
        wireArgs: <String, Object?>{'position': 'topRight'},
      ),
      WireCase(
        name: 'setActiveForegroundPushView (no args)',
        action: () => insider.setActiveForegroundPushView(),
        wireMethod: Constants.SET_ACTIVE_FOREGROUND_PUSH_VIEW,
        wireArgs: null,
      ),
    ], channel);
  });

  group('init app identifier forwarding', () {
    test('the appIdentifier wire key is "appIdentifier"', () {
      expect(Constants.APP_IDENTIFIER, equals('appIdentifier'));
    });

    const eventChannel = MethodChannel(Constants.EVENT_CHANNEL_NAME);

    late List<MethodCall> capturedCalls;

    void callback(int type, dynamic data) {}

    setUp(() {
      capturedCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventChannel, (MethodCall call) async {
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventChannel, null);
    });

    /// Runs `action` and returns the single captured MethodCall.
    Future<MethodCall> expectSingleCall(Future<void> Function() action) async {
      await action();
      await Future<void>.delayed(Duration.zero);
      expect(capturedCalls, hasLength(1));
      return capturedCalls.single;
    }

    Map<String, dynamic> argsOf(MethodCall call) =>
        Map<String, dynamic>.from(call.arguments as Map);

    Map<String, dynamic> launchArgs({String? appIdentifier}) =>
        <String, dynamic>{
          'appGroup': 'group.test',
          'partnerName': 'partner',
          'sdkVersion': startsWith('F-'),
          if (appIdentifier != null) Constants.APP_IDENTIFIER: appIdentifier,
        };

    Map<String, dynamic> endpointArgs({String? appIdentifier}) =>
        <String, dynamic>{
          ...launchArgs(appIdentifier: appIdentifier),
          'customEndpoint': 'https://ep.test',
        };

    void rejectNativeCall(String method) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == method) {
          throw PlatformException(code: 'SDK_INIT_ERROR');
        }
        return null;
      });
    }

    test('init without appIdentifier sends no "appIdentifier" key', () async {
      final call = await expectSingleCall(
        () => insider.init('partner', 'group.test', callback),
      );

      expect(call.method, equals(Constants.INIT_WITH_LAUNCH_OPTIONS));
      expect(
        argsOf(call),
        equals(<String, dynamic>{
          'appGroup': 'group.test',
          'partnerName': 'partner',
          'sdkVersion': startsWith('F-'),
        }),
      );
    });

    test('init with appIdentifier forwards it as "appIdentifier"', () async {
      final call = await expectSingleCall(
        () => insider.init('partner', 'group.test', callback,
            appIdentifier: 'shop'),
      );

      expect(call.method, equals(Constants.INIT_WITH_LAUNCH_OPTIONS));
      expect(
        argsOf(call),
        equals(<String, dynamic>{
          'appGroup': 'group.test',
          'partnerName': 'partner',
          'sdkVersion': startsWith('F-'),
          Constants.APP_IDENTIFIER: 'shop',
        }),
      );
    });

    test('init with an empty appIdentifier sends no "appIdentifier" key',
        () async {
      final call = await expectSingleCall(
        () =>
            insider.init('partner', 'group.test', callback, appIdentifier: ''),
      );

      expect(call.method, equals(Constants.INIT_WITH_LAUNCH_OPTIONS));
      expect(argsOf(call), equals(launchArgs()));
    });

    test('init with a null appIdentifier sends no "appIdentifier" key',
        () async {
      final call = await expectSingleCall(
        () => insider.init('partner', 'group.test', callback,
            appIdentifier: null),
      );

      expect(call.method, equals(Constants.INIT_WITH_LAUNCH_OPTIONS));
      expect(argsOf(call), equals(launchArgs()));
    });

    test(
      'init forwards a malformed appIdentifier unchanged for native to validate',
      () async {
        final call = await expectSingleCall(
          () => insider.init('partner', 'group.test', callback,
              appIdentifier: 'Bad App!'),
        );

        expect(call.method, equals(Constants.INIT_WITH_LAUNCH_OPTIONS));
        expect(argsOf(call), equals(launchArgs(appIdentifier: 'Bad App!')));
      },
    );

    test(
        'initWithCustomEndpoint without appIdentifier sends no "appIdentifier" key',
        () async {
      final call = await expectSingleCall(
        () => insider.initWithCustomEndpoint(
          'partner',
          'group.test',
          'https://ep.test',
          callback,
        ),
      );

      expect(call.method, equals(Constants.INIT_WITH_CUSTOM_ENDPOINT));
      expect(
        argsOf(call),
        equals(<String, dynamic>{
          'appGroup': 'group.test',
          'partnerName': 'partner',
          'sdkVersion': startsWith('F-'),
          'customEndpoint': 'https://ep.test',
        }),
      );
    });

    test(
        'initWithCustomEndpoint with appIdentifier forwards it as "appIdentifier"',
        () async {
      final call = await expectSingleCall(
        () => insider.initWithCustomEndpoint(
          'partner',
          'group.test',
          'https://ep.test',
          callback,
          appIdentifier: 'shop',
        ),
      );

      expect(call.method, equals(Constants.INIT_WITH_CUSTOM_ENDPOINT));
      expect(
        argsOf(call),
        equals(<String, dynamic>{
          'appGroup': 'group.test',
          'partnerName': 'partner',
          'sdkVersion': startsWith('F-'),
          'customEndpoint': 'https://ep.test',
          Constants.APP_IDENTIFIER: 'shop',
        }),
      );
    });

    test(
      'initWithCustomEndpoint with an empty appIdentifier sends no "appIdentifier" key',
      () async {
        final call = await expectSingleCall(
          () => insider.initWithCustomEndpoint(
            'partner',
            'group.test',
            'https://ep.test',
            callback,
            appIdentifier: '',
          ),
        );

        expect(call.method, equals(Constants.INIT_WITH_CUSTOM_ENDPOINT));
        expect(argsOf(call), equals(endpointArgs()));
      },
    );

    test(
      'initWithCustomEndpoint forwards a malformed appIdentifier unchanged for native to validate',
      () async {
        final call = await expectSingleCall(
          () => insider.initWithCustomEndpoint(
            'partner',
            'group.test',
            'https://ep.test',
            callback,
            appIdentifier: 'Bad App!',
          ),
        );

        expect(call.method, equals(Constants.INIT_WITH_CUSTOM_ENDPOINT));
        expect(argsOf(call), equals(endpointArgs(appIdentifier: 'Bad App!')));
      },
    );

    test(
      'init reports a native init failure through putException and completes',
      () async {
        rejectNativeCall(Constants.INIT_WITH_LAUNCH_OPTIONS);

        await insider.init('partner', 'group.test', callback,
            appIdentifier: 'shop');
        await Future<void>.delayed(Duration.zero);

        expect(
          capturedCalls.map((c) => c.method).toList(),
          equals(<String>[Constants.INIT_WITH_LAUNCH_OPTIONS, 'putException']),
        );
        expect(argsOf(capturedCalls.first),
            equals(launchArgs(appIdentifier: 'shop')));
      },
    );

    test(
      'initWithCustomEndpoint reports a native init failure through putException and completes',
      () async {
        rejectNativeCall(Constants.INIT_WITH_CUSTOM_ENDPOINT);

        await insider.initWithCustomEndpoint(
          'partner',
          'group.test',
          'https://ep.test',
          callback,
          appIdentifier: 'shop',
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          capturedCalls.map((c) => c.method).toList(),
          equals(<String>[Constants.INIT_WITH_CUSTOM_ENDPOINT, 'putException']),
        );
        expect(argsOf(capturedCalls.first),
            equals(endpointArgs(appIdentifier: 'shop')));
      },
    );
  });
  group('in-app message methods are awaitable', () {
    late List<MethodCall> capturedCalls;

    setUp(() {
      capturedCalls = <MethodCall>[];
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final cases = <_InAppCase>[
      _InAppCase('disableInAppMessages', () => insider.disableInAppMessages(),
          Constants.DISABLE_IN_APP_MESSAGES),
      _InAppCase('enableInAppMessages', () => insider.enableInAppMessages(),
          Constants.ENABLE_IN_APP_MESSAGES),
      _InAppCase(
          'handleUniversalLink',
          () => insider.handleUniversalLink('https://x.test'),
          Constants.HANDLE_UNIVERSAL_LINK),
    ];

    for (final c in cases) {
      test('${c.name} completes only after the native side answers', () async {
        final gate = Completer<Object?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                channel, (MethodCall call) => gate.future);
        var completed = false;

        final future = c.apply().whenComplete(() => completed = true);
        await Future<void>.delayed(Duration.zero);

        expect(completed, isFalse);

        gate.complete(null);
        await future;

        expect(completed, isTrue);
      });

      test(
          '${c.name} reports a native PlatformException through putException and does not throw',
          () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          capturedCalls.add(call);
          if (call.method == c.wireMethod) {
            throw PlatformException(code: 'ERROR', message: 'native failed');
          }
          return null;
        });

        await c.apply();
        await Future<void>.delayed(Duration.zero);

        expect(
          capturedCalls.map((call) => call.method),
          equals(<String>[c.wireMethod, 'putException']),
        );
        expect(
          Map<String, dynamic>.from(
              capturedCalls.last.arguments as Map)['exception'],
          contains('native failed'),
        );
      });
    }
  });
}

class _InAppCase {
  _InAppCase(this.name, this.apply, this.wireMethod);

  final String name;
  final Future<void> Function() apply;
  final String wireMethod;
}
