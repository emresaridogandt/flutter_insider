@Tags(['integration'])
library flutter_insider_test;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/src/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_insider');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Date Handling Tests', () {
    test('setBirthday converts DateTime to epoch milliseconds string',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      final DateTime testDate = DateTime(2024, 1, 1, 12, 0, 0);
      final int expectedEpoch = testDate.millisecondsSinceEpoch;

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      final user = FlutterInsider.Instance.getCurrentUser();
      expect(user, isNotNull,
          reason: 'User should be initialized after initFlutterBase');
      user!.setBirthday(testDate);

      expect(methodCalls.length, greaterThan(0));
      final birthdayCall = methodCalls.firstWhere(
        (call) => call.method == 'setBirthday',
        orElse: () => throw Exception('setBirthday method not called'),
      );

      expect(birthdayCall.arguments, isA<Map>());
      final args = Map<String, dynamic>.from(birthdayCall.arguments as Map);
      expect(args['key'], equals('setBirthday'));
      expect(args['value'], equals(expectedEpoch.toString()));
    });

    test(
        'setCustomAttributeWithDate converts DateTime to epoch milliseconds string',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      final DateTime testDate = DateTime(2024, 6, 15, 10, 30, 0);
      final int expectedEpoch = testDate.millisecondsSinceEpoch;
      const String customKey = 'custom_date_attribute';

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      final user = FlutterInsider.Instance.getCurrentUser();
      expect(user, isNotNull,
          reason: 'User should be initialized after initFlutterBase');
      user!.setCustomAttributeWithDate(customKey, testDate);

      expect(methodCalls.length, greaterThan(0));
      final customDateCall = methodCalls.firstWhere(
        (call) => call.method == 'setCustomAttributeWithDate',
        orElse: () =>
            throw Exception('setCustomAttributeWithDate method not called'),
      );

      expect(customDateCall.arguments, isA<Map>());
      final args = Map<String, dynamic>.from(customDateCall.arguments as Map);
      expect(args['key'], equals(customKey));
      expect(args['value'], equals(expectedEpoch.toString()));
    });

    test('setBirthday handles different DateTime values correctly', () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      final testDates = [
        DateTime(1970, 1, 1),
        DateTime(2000, 1, 1),
        DateTime(2024, 12, 31, 23, 59, 59),
        DateTime.now(),
      ];

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      final user = FlutterInsider.Instance.getCurrentUser();
      expect(user, isNotNull,
          reason: 'User should be initialized after initFlutterBase');

      for (final date in testDates) {
        user!.setBirthday(date);
        final expectedEpoch = date.millisecondsSinceEpoch;

        final birthdayCall = methodCalls.firstWhere(
          (call) {
            if (call.method != 'setBirthday') return false;
            final args = Map<String, dynamic>.from(call.arguments as Map);
            return args['value'] == expectedEpoch.toString();
          },
          orElse: () => throw Exception(
              'setBirthday not called with correct epoch for ${date.toIso8601String()}'),
        );

        final args = Map<String, dynamic>.from(birthdayCall.arguments as Map);
        expect(args['value'], equals(expectedEpoch.toString()));
      }
    });
  });

  group('Cart Events saleID Tests', () {
    test('visitCartPage sends saleID in args when provided', () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);

      final product = FlutterInsider.Instance.createNewProduct(
          'PROD1', 'Test Product', ['cat'], 'https://img.url', 9.99, 'USD');
      await FlutterInsider.Instance.visitCartPage([product],
          saleID: 'SALE-123');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'visitCartPage',
        orElse: () => throw Exception('visitCartPage method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['saleID'], equals('SALE-123'));
    });

    test('visitCartPage does NOT send saleID key when saleID is null',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);

      final product = FlutterInsider.Instance.createNewProduct(
          'PROD1', 'Test Product', ['cat'], 'https://img.url', 9.99, 'USD');
      await FlutterInsider.Instance.visitCartPage([product]);

      final call = methodCalls.firstWhere(
        (c) => c.method == 'visitCartPage',
        orElse: () => throw Exception('visitCartPage method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args.containsKey('saleID'), isFalse);
    });

    test('visitCartPage does NOT send saleID key when saleID is empty string',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);

      final product = FlutterInsider.Instance.createNewProduct(
          'PROD1', 'Test Product', ['cat'], 'https://img.url', 9.99, 'USD');
      await FlutterInsider.Instance.visitCartPage([product], saleID: '');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'visitCartPage',
        orElse: () => throw Exception('visitCartPage method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args.containsKey('saleID'), isFalse);
    });

    test('itemRemovedFromCart sends saleID in args when provided', () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      await FlutterInsider.Instance.itemRemovedFromCart('PROD1',
          saleID: 'SALE-456');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'itemRemovedFromCart',
        orElse: () => throw Exception('itemRemovedFromCart method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['productID'], equals('PROD1'));
      expect(args['saleID'], equals('SALE-456'));
    });

    test('itemRemovedFromCart does NOT send saleID key when saleID is null',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      await FlutterInsider.Instance.itemRemovedFromCart('PROD1');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'itemRemovedFromCart',
        orElse: () => throw Exception('itemRemovedFromCart method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args.containsKey('saleID'), isFalse);
    });

    test(
        'itemRemovedFromCart does NOT send saleID key when saleID is empty string',
        () async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });

      await FlutterInsider.Instance.initFlutterBase(
          'test_partner', 'test_group', null);
      await FlutterInsider.Instance.itemRemovedFromCart('PROD1', saleID: '');

      final call = methodCalls.firstWhere(
        (c) => c.method == 'itemRemovedFromCart',
        orElse: () => throw Exception('itemRemovedFromCart method not called'),
      );
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args.containsKey('saleID'), isFalse);
    });
  });

  group('events getter', () {
    test('returns the same FlutterInsiderEvents instance on every read', () {
      final FlutterInsiderEvents first = FlutterInsider.Instance.events;

      expect(FlutterInsider.Instance.events, same(first));
    });
  });
  group('App Card model wrappers', () {
    final card = InsiderAppCard(id: 'card-1', type: 'message');
    final button = InsiderAppCardButton(
      id: 'btn-1',
      text: 'Open',
      appCardId: 'card-1',
    );

    final cases = <_WrapperCase>[
      _WrapperCase(
        'InsiderAppCard.view()',
        () => card.view(),
        Constants.APP_CARDS_VIEW,
        <String, Object?>{'appCard': card.toMap()},
      ),
      _WrapperCase(
        'InsiderAppCard.click()',
        () => card.click(),
        Constants.APP_CARDS_CLICK,
        <String, Object?>{'appCard': card.toMap()},
      ),
      _WrapperCase(
        'InsiderAppCardButton.click()',
        () => button.click(),
        Constants.APP_CARDS_BUTTON_CLICK,
        <String, Object?>{'appCardId': 'card-1', 'data': button.toMap()},
      ),
    ];

    for (final c in cases) {
      test('${c.name} sends the wire method with the full argument map',
          () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });

        await c.apply();
        await Future<void>.delayed(Duration.zero);

        expect(calls, hasLength(1));
        expect(calls.single.method, equals(c.wireMethod));
        expect(
          Map<String, dynamic>.from(calls.single.arguments as Map),
          equals(c.wireArgs),
        );
      });

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
    }
  });
}

class _WrapperCase {
  _WrapperCase(this.name, this.apply, this.wireMethod, this.wireArgs);

  final String name;
  final Future<void> Function() apply;
  final String wireMethod;
  final Map<String, Object?> wireArgs;
}
