@Tags(['integration'])
library flutter_insider_queries_test;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/src/constants.dart';
import 'package:flutter_insider/src/identifiers.dart';
import 'package:flutter_insider/src/product.dart';

import 'wire_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_insider');
  final insider = FlutterInsider.Instance;

  Map<String, Object?> contentArgs(
          String variableName, Object? defaultValue, int dataType) =>
      <String, Object?>{
        'variableName': variableName,
        'defaultValue': defaultValue,
        'dataType': dataType,
      };

  group('FlutterInsider content optimizer queries', () {
    registerWireCases([
      WireCase(
        name: 'getContentStringWithName forwards args & returns native value',
        action: () => insider.getContentStringWithName('banner', 'fallback', 1),
        wireMethod: Constants.GET_CONTENT_STRING_WITH_NAME,
        wireArgs: contentArgs('banner', 'fallback', 1),
        handlerReturn: 'native-value',
        expectResult: (r) => expect(r, equals('native-value')),
      ),
      WireCase(
        name: 'getContentIntWithName',
        action: () => insider.getContentIntWithName('counter', 0, 2),
        wireMethod: Constants.GET_CONTENT_INT_WITH_NAME,
        wireArgs: contentArgs('counter', 0, 2),
        handlerReturn: 42,
        expectResult: (r) => expect(r, equals(42)),
      ),
      WireCase(
        name: 'getContentBoolWithName',
        action: () => insider.getContentBoolWithName('flag', false, 3),
        wireMethod: Constants.GET_CONTENT_BOOL_WITH_NAME,
        wireArgs: contentArgs('flag', false, 3),
        handlerReturn: true,
        expectResult: (r) => expect(r, isTrue),
      ),
      WireCase(
        name: 'getContentStringWithoutCache',
        action: () =>
            insider.getContentStringWithoutCache('banner', 'fallback', 1),
        wireMethod: Constants.GET_CONTENT_STRING_WITHOUT_CACHE,
        wireArgs: contentArgs('banner', 'fallback', 1),
        handlerReturn: 'fresh',
        expectResult: (r) => expect(r, equals('fresh')),
      ),
      WireCase(
        name: 'getContentIntWithoutCache',
        action: () => insider.getContentIntWithoutCache('n', 0, 2),
        wireMethod: Constants.GET_CONTENT_INT_WITHOUT_CACHE,
        wireArgs: contentArgs('n', 0, 2),
        handlerReturn: 7,
        expectResult: (r) => expect(r, equals(7)),
      ),
      WireCase(
        name: 'getContentBoolWithoutCache',
        action: () => insider.getContentBoolWithoutCache('f', true, 3),
        wireMethod: Constants.GET_CONTENT_BOOL_WITHOUT_CACHE,
        wireArgs: contentArgs('f', true, 3),
        handlerReturn: false,
        expectResult: (r) => expect(r, isFalse),
      ),
      WireCase(
        name: 'markContentOptimizerAsSeen forwards variableName only',
        action: () => insider.markContentOptimizerAsSeen('banner'),
        wireMethod: Constants.MARK_CONTENT_OPTIMIZER_AS_SEEN,
        wireArgs: <String, Object?>{'variableName': 'banner'},
        handlerReturn: null,
      ),
    ], channel);
  });

  group('FlutterInsider content optimizer error path', () {
    late List<MethodCall> capturedCalls;

    setUp(() {
      capturedCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.MARK_CONTENT_OPTIMIZER_AS_SEEN) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'markContentOptimizerAsSeen reports a native failure instead of throwing',
        () async {
      await insider.markContentOptimizerAsSeen('banner');

      expect(
        capturedCalls.map((c) => c.method),
        equals(
            <String>[Constants.MARK_CONTENT_OPTIMIZER_AS_SEEN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test('markContentOptimizerAsSeen ignores a blank variableName', () async {
      await insider.markContentOptimizerAsSeen('   ');

      expect(capturedCalls, isEmpty);
    });
  });

  group('FlutterInsider smart recommendation queries', () {
    final product = insider.createNewProduct(
        'P1', 'Prod', <String>['cat'], 'https://img', 9.99, 'USD');

    registerWireCases([
      WireCase(
        name: 'getSmartRecommendation forwards args and returns native map',
        action: () => insider.getSmartRecommendation(7, 'tr-TR', 'USD'),
        wireMethod: Constants.GET_SMART_RECOMMENDATION,
        wireArgs: <String, Object?>{
          'recommendationID': 7,
          'locale': 'tr-TR',
          'currency': 'USD',
        },
        handlerReturn: <String, dynamic>{
          'items': <int>[1, 2, 3]
        },
        expectResult: (r) => expect(
            r,
            equals(<String, dynamic>{
              'items': <int>[1, 2, 3]
            })),
      ),
      WireCase(
        name: 'getSmartRecommendationWithProduct',
        action: () =>
            insider.getSmartRecommendationWithProduct(product, 7, 'tr-TR'),
        wireMethod: Constants.GET_SMART_RECOMMENDATION_WITH_PRODUCT,
        wireArgs: <String, Object?>{
          'recommendationID': 7,
          'locale': 'tr-TR',
          'requiredFields': product.requiredFields,
          'optionalFields': product.optionalFields,
          'customParameters': product.customParameters,
        },
        handlerReturn: <String, dynamic>{'ok': true},
        expectResult: (r) => expect(r, equals(<String, dynamic>{'ok': true})),
      ),
      WireCase(
        name: 'getSmartRecommendationWithProductIDs',
        action: () => insider.getSmartRecommendationWithProductIDs(
            <String>['P1', 'P2'], 7, 'tr-TR', 'USD'),
        wireMethod: Constants.GET_SMART_RECOMMENDATION_WITH_PRODUCT_IDS,
        wireArgs: <String, Object?>{
          'productIDs': <String>['P1', 'P2'],
          'recommendationID': 7,
          'locale': 'tr-TR',
          'currency': 'USD',
        },
        handlerReturn: <String, dynamic>{'count': 2},
        expectResult: (r) => expect(r, equals(<String, dynamic>{'count': 2})),
      ),
      WireCase(
        name: 'clickSmartRecommendationProduct',
        action: () => insider.clickSmartRecommendationProduct(7, product),
        wireMethod: Constants.CLICK_SMART_RECOMMENDATION_PRODUCT,
        wireArgs: <String, Object?>{
          'recommendationID': 7,
          'requiredFields': product.requiredFields,
          'optionalFields': product.optionalFields,
          'customParameters': product.customParameters,
        },
      ),
    ], channel);
  });

  group('FlutterInsider smart recommendation price gate', () {
    late List<MethodCall> capturedCalls;

    setUp(() {
      capturedCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return <String, dynamic>{'ok': true};
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    FlutterInsiderProduct nanProduct() => insider.createNewProduct(
        'P1', 'Prod', <String>['cat'], 'https://img', double.nan, 'USD');

    test(
        'getSmartRecommendationWithProduct returns null without calling native for a non-finite price',
        () async {
      final result = await insider.getSmartRecommendationWithProduct(
          nanProduct(), 7, 'tr-TR');
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(capturedCalls, isEmpty);
    });

    test('clickSmartRecommendationProduct sends nothing for a non-finite price',
        () async {
      await insider.clickSmartRecommendationProduct(7, nanProduct());
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });
  });

  group('FlutterInsider message center queries', () {
    final start = DateTime.utc(2024, 1, 1);
    final end = DateTime.utc(2024, 1, 31);
    final identifiers = FlutterInsiderIdentifiers().addEmail('a@b.com');

    registerWireCases([
      WireCase(
        name: 'getMessageCenterData (valid window)',
        action: () => insider.getMessageCenterData(start, end, 50),
        wireMethod: Constants.GET_MESSAGE_CENTER_DATA,
        wireArgs: <String, Object?>{
          'startDate': start.millisecondsSinceEpoch,
          'endDate': end.millisecondsSinceEpoch,
          'limit': 50,
        },
        handlerReturn: <Map<String, dynamic>>[
          {'id': 1},
          {'id': 2},
        ],
        expectResult: (r) {
          expect(r, isA<List>());
          expect((r as List).length, equals(2));
        },
      ),
      WireCase(
        name: 'getMessageCenterDataWithIdentifiers (valid window)',
        action: () => insider.getMessageCenterDataWithIdentifiers(
            start, end, identifiers, 25),
        wireMethod: Constants.GET_MESSAGE_CENTER_DATA_WITH_IDENTIFIERS,
        wireArgs: <String, Object?>{
          'startDate': start.millisecondsSinceEpoch,
          'endDate': end.millisecondsSinceEpoch,
          'identifiers': identifiers.getIdentifiers(),
          'limit': 25,
        },
        handlerReturn: <Map<String, dynamic>>[
          {'id': 1},
        ],
        expectResult: (r) => expect((r as List).length, equals(1)),
      ),
    ], channel);
  });

  group('FlutterInsider message center early-exit (invalid window)', () {
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getMessageCenterData returns empty list when start == end', () async {
      final t = DateTime.utc(2024, 1, 1);

      final result = await insider.getMessageCenterData(t, t, 10);

      expect(calls, isEmpty,
          reason: 'invalid window must short-circuit before any wire call');
      expect(result, isA<List>());
      expect((result as List), isEmpty);
    });

    test('getMessageCenterData returns empty list when start > end', () async {
      final later = DateTime.utc(2024, 2, 1);
      final earlier = DateTime.utc(2024, 1, 1);

      final result = await insider.getMessageCenterData(later, earlier, 10);

      expect(calls, isEmpty);
      expect((result as List), isEmpty);
    });

    test('getMessageCenterDataWithIdentifiers also short-circuits', () async {
      final t = DateTime.utc(2024, 1, 1);
      final ids = FlutterInsiderIdentifiers().addEmail('x@y.com');

      final result =
          await insider.getMessageCenterDataWithIdentifiers(t, t, ids, 10);

      expect(calls, isEmpty);
      expect((result as List), isEmpty);
    });
  });

  group('FlutterInsider message center failure contract', () {
    final start = DateTime.utc(2024, 1, 1);
    final end = DateTime.utc(2024, 1, 31);
    late List<MethodCall> capturedCalls;
    Object? Function(MethodCall call) answer = (_) => null;

    setUp(() {
      capturedCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return answer(call);
      });
    });

    tearDown(() {
      answer = (_) => null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'getMessageCenterData returns the empty result native answers on an SDK failure',
        () async {
      answer = (_) => <Object?>[];

      final result = await insider.getMessageCenterData(start, end, 10);

      expect(result, isNotNull);
      expect(result, isEmpty);
      expect(capturedCalls.map((c) => c.method),
          equals(<String>[Constants.GET_MESSAGE_CENTER_DATA]));
    });

    test(
        'getMessageCenterData returns null and reports when the platform call fails',
        () async {
      answer = (call) {
        if (call.method == Constants.GET_MESSAGE_CENTER_DATA) {
          throw PlatformException(code: 'ERROR', message: 'channel failed');
        }
        return null;
      };

      final result = await insider.getMessageCenterData(start, end, 10);

      expect(result, isNull);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.GET_MESSAGE_CENTER_DATA, 'putException']),
      );
    });
  });

  group('FlutterInsider misc queries', () {
    registerWireCases([
      WireCase(
        name: 'getInsiderID forwards native return value',
        action: () => insider.getInsiderID(),
        wireMethod: Constants.GET_INSIDER_ID,
        wireArgs: null,
        handlerReturn: 'insider-abc-123',
        expectResult: (r) => expect(r, equals('insider-abc-123')),
      ),
    ], channel);
  });
}
