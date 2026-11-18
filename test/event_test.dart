import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_insider');

  late List<MethodCall> capturedCalls;

  setUp(() {
    capturedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Builds an event, calls build(), and returns the captured arguments.
  Future<Map<String, dynamic>> buildAndCapture(
      void Function(FlutterInsiderEvent) configure) async {
    final event = FlutterInsiderEvent(channel, 'test_event');
    configure(event);
    await event.build();

    expect(capturedCalls, hasLength(1));
    expect(capturedCalls.single.method, equals('tagEvent'));
    return Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
  }

  /// Redirects `debugPrint` for the current test and returns the messages.
  List<String?> captureDebugPrint() {
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    return messages;
  }

  group('blank keys', () {
    test('every parameter setter drops a blank key and names itself', () async {
      final messages = captureDebugPrint();
      final args = await buildAndCapture((e) {
        e
          ..addParameterWithString('', 'v')
          ..addParameterWithInt('  ', 1)
          ..addParameterWithDouble('', 1.5)
          ..addParameterWithBoolean('  ', true)
          ..addParameterWithDate('', DateTime.utc(2024, 1, 1))
          ..addParameterWithStringArray('  ', <String>['a'])
          ..addParameterWithNumericArray('', <num>[1])
          ..addParameterWithObjectArray(
              '  ', <Map<String, Object>>[<String, Object>{'tier': 'gold'}])
          ..addParameterWithString('kept', 'v');
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'string', 'key': 'kept', 'value': 'v'},
      ]));
      expect(
        messages,
        equals(<String>[
          for (final method in <String>[
            'addParameterWithString',
            'addParameterWithInt',
            'addParameterWithDouble',
            'addParameterWithBoolean',
            'addParameterWithDate',
            'addParameterWithStringArray',
            'addParameterWithNumericArray',
            'addParameterWithObjectArray',
          ])
            '[Insider] $method ignored the call: an empty or whitespace-only key cannot be sent to native.',
        ]),
      );
    });
  });

  group('build', () {
    test('invokes the tagEvent channel method with the event name', () async {
      final args = await buildAndCapture((_) {});

      expect(args['name'], equals('test_event'));
    });

    test('sends an empty parameters list when no parameters were added',
        () async {
      final args = await buildAndCapture((_) {});

      expect(args['parameters'], isEmpty);
    });
  });

  group('addParameterWithString', () {
    test('appends a typed string parameter', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithString('plan', 'gold');
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'string', 'key': 'plan', 'value': 'gold'},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(identical(event.addParameterWithString('k', 'v'), event), isTrue);
    });
  });

  group('addParameterWithInt', () {
    test('appends a typed integer parameter', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithInt('age', 30);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'integer', 'key': 'age', 'value': 30},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(identical(event.addParameterWithInt('k', 1), event), isTrue);
    });

    test('skips a value past the 32-bit range and keeps the other parameters',
        () async {
      final messages = captureDebugPrint();

      final args = await buildAndCapture((e) {
        e
          ..addParameterWithInt('big', 3000000000)
          ..addParameterWithInt('ok', 7);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'integer', 'key': 'ok', 'value': 7},
      ]));
      expect(
        messages.single,
        equals('[Insider] addParameterWithInt ignored big: only whole numbers '
            'within the 32-bit range can be sent to native.'),
      );
    });
  });

  group('the native key rule at the event surface', () {
    test('addParameterWithString refuses a key native would reject', () async {
      final messages = captureDebugPrint();

      FlutterInsiderEvent(channel, 'e')
          .addParameterWithString('firstName', 'camel')
          .addParameterWithString('ok_key', 'kept')
          .build();
      await Future<void>.delayed(Duration.zero);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map)['parameters'],
        equals(<Map<String, dynamic>>[
          {'type': 'string', 'key': 'ok_key', 'value': 'kept'},
        ]),
      );
      expect(
        messages.single,
        equals('[Insider] addParameterWithString ignored the call: a key must '
            'start with a lowercase letter and hold only lowercase letters, '
            'digits and underscores.'),
      );
    });
  });

  group('addParameterWithObjectArray when nothing survives', () {
    test('drops the parameter and says so, without losing the event',
        () async {
      final messages = captureDebugPrint();

      FlutterInsiderEvent(channel, 'e')
          .addParameterWithObjectArray('p', <Map<String, Object>>[
            <String, Object>{'firstName': 'camel'},
          ])
          .addParameterWithString('ok', 'kept')
          .build();
      await Future<void>.delayed(Duration.zero);

      // The event still goes out, so the wording must name the parameter.
      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map)['parameters'],
        equals(<Map<String, dynamic>>[
          {'type': 'string', 'key': 'ok', 'value': 'kept'},
        ]),
      );
      expect(
        messages.single,
        equals('[Insider] addParameterWithObjectArray dropped values that '
            'cannot be sent to native: 0.firstName. Nothing was left to send, '
            'so the parameter was ignored.'),
      );
    });

    test('keeps the event when only one object of the list is keyless',
        () async {
      final messages = captureDebugPrint();

      FlutterInsiderEvent(channel, 'e')
          .addParameterWithObjectArray('p', <Map<String, Object>>[
            <String, Object>{'tier': 'gold'},
            <String, Object>{},
          ])
          .build();
      await Future<void>.delayed(Duration.zero);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map)['parameters'],
        equals(<Map<String, dynamic>>[
          {
            'type': 'objects',
            'key': 'p',
            'value': <List<Map<String, Object>>>[
              <Map<String, Object>>[
                {'type': 'string', 'key': 'tier', 'value': 'gold'},
              ],
            ],
          },
        ]),
      );
      expect(
        messages.single,
        equals('[Insider] addParameterWithObjectArray dropped values that '
            'cannot be sent to native: 1. The rest of the call was still '
            'sent.'),
      );
    });

    test('names the object that had no key to drop', () async {
      final messages = captureDebugPrint();

      FlutterInsiderEvent(channel, 'e')
          .addParameterWithObjectArray('p', <Map<String, Object>>[
            <String, Object>{},
          ])
          .build();
      await Future<void>.delayed(Duration.zero);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map)['parameters'],
        isEmpty,
      );
      expect(
        messages.single,
        equals('[Insider] addParameterWithObjectArray dropped values that '
            'cannot be sent to native: 0. Nothing was left to send, so the '
            'parameter was ignored.'),
      );
    });
  });

  group('addParameterWithObjectArray empty list', () {
    test('is a no-op, as native treats it, and says so', () async {
      final messages = captureDebugPrint();

      FlutterInsiderEvent(channel, 'e')
          .addParameterWithObjectArray('p', <Map<String, Object>>[])
          .build();
      await Future<void>.delayed(Duration.zero);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map)['parameters'],
        isEmpty,
      );
      expect(
        messages.single,
        equals('[Insider] addParameterWithObjectArray ignored the parameter: '
            'there are no objects to add.'),
      );
    });
  });

  group('addParameterWithDouble', () {
    test('skips NaN and infinity with a warning and keeps the other parameters',
        () async {
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      final args = await buildAndCapture((e) {
        e
            .addParameterWithDouble('nan_score', double.nan)
            .addParameterWithDouble('inf_score', double.negativeInfinity)
            .addParameterWithInt('ok', 7);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'integer', 'key': 'ok', 'value': 7},
      ]));
      expect(messages, equals(<String>[
        '[Insider] addParameterWithDouble ignored nan_score: NaN and infinite '
            'numbers cannot be sent to native.',
        '[Insider] addParameterWithDouble ignored inf_score: NaN and infinite '
            'numbers cannot be sent to native.',
      ]));
    });

    test('appends a typed double parameter', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithDouble('score', 4.5);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'double', 'key': 'score', 'value': 4.5},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(identical(event.addParameterWithDouble('k', 1.0), event), isTrue);
    });
  });

  group('addParameterWithBoolean', () {
    test('appends a typed boolean parameter', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithBoolean('is_premium', true);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'boolean', 'key': 'is_premium', 'value': true},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(identical(event.addParameterWithBoolean('k', false), event), isTrue);
    });
  });

  group('addParameterWithDate', () {
    test('serializes DateTime as epoch milliseconds *string*', () async {
      final date = DateTime.utc(2024, 1, 15, 12, 0, 0);
      final args = await buildAndCapture((e) {
        e.addParameterWithDate('last_login', date);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {
          'type': 'date',
          'key': 'last_login',
          'value': date.millisecondsSinceEpoch.toString(),
        },
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(
        identical(event.addParameterWithDate('k', DateTime.utc(2024)), event),
        isTrue,
      );
    });
  });

  group('addParameterWithStringArray', () {
    test('uses type "strings" and keeps empty strings, as native does',
        () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithStringArray('tags', <String>['a', '', 'b']);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'strings', 'key': 'tags', 'value': <String>['a', '', 'b']},
      ]));
    });

    test('sends an array whose values are all empty', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithStringArray('tags', <String>['', '']);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'strings', 'key': 'tags', 'value': <String>['', '']},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(
        identical(event.addParameterWithStringArray('k', <String>['a']), event),
        isTrue,
      );
    });
  });

  group('addParameterWithArray (deprecated)', () {
    test('uses type "strings" and stores values verbatim (no filtering)',
        () async {
      // ignore: deprecated_member_use_from_same_package
      final args = await buildAndCapture((e) {
        // ignore: deprecated_member_use_from_same_package
        e.addParameterWithArray('tags', <String>['a', '', 'b']);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'strings', 'key': 'tags', 'value': <String>['a', '', 'b']},
      ]));
    });
  });

  group('addParameterWithNumericArray', () {
    test('uses type "numbers" and filters out non-finite values', () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithNumericArray(
          'scores',
          <num>[1, double.nan, 2.5, double.infinity, -3],
        );
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'numbers', 'key': 'scores', 'value': <num>[1, 2.5, -3]},
      ]));
    });

    test('falls back to an empty list when every value is non-finite',
        () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithNumericArray(
          'scores',
          <num>[double.nan, double.infinity],
        );
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {'type': 'numbers', 'key': 'scores', 'value': <num>[]},
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(
        identical(event.addParameterWithNumericArray('k', <num>[1]), event),
        isTrue,
      );
    });
  });

  group('addParameterWithObjectArray', () {
    test('uses type "objects" with one typed parameter list per object',
        () async {
      final args = await buildAndCapture((e) {
        e.addParameterWithObjectArray('order_lines', <Map<String, Object>>[
          <String, Object>{'sku': 'ABC-1', 'qty': 2, 'unit_price': 19.99},
          <String, Object>{
            'sku': 'DEF-2',
            'shipping': <String, Object>{'city': 'Istanbul'},
          },
        ]);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {
          'type': 'objects',
          'key': 'order_lines',
          'value': <List<Map<String, Object>>>[
            <Map<String, Object>>[
              {'type': 'string', 'key': 'sku', 'value': 'ABC-1'},
              {'type': 'integer', 'key': 'qty', 'value': 2},
              {'type': 'double', 'key': 'unit_price', 'value': 19.99},
            ],
            <Map<String, Object>>[
              {'type': 'string', 'key': 'sku', 'value': 'DEF-2'},
              {
                'type': 'object',
                'key': 'shipping',
                'value': <Map<String, Object>>[
                  {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
                ],
              },
            ],
          ],
        },
      ]));
    });

    test('returns the same instance for chaining', () {
      final event = FlutterInsiderEvent(channel, 'e');

      expect(
        identical(
          event.addParameterWithObjectArray(
              'k', <Map<String, Object>>[<String, Object>{'a': 'b'}]),
          event,
        ),
        isTrue,
      );
    });
  });

  group('addParameterWithObjectArray dropped values', () {
    test('warns with the dropped key paths and keeps the rest', () async {
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      final args = await buildAndCapture((e) {
        e.addParameterWithObjectArray('order_lines', <Map<String, Object>>[
          <String, Object>{'sku': 'ABC-1', 'lines': <Object>['a', 1]},
        ]);
      });

      expect(args['parameters'], equals(<Map<String, dynamic>>[
        {
          'type': 'objects',
          'key': 'order_lines',
          'value': <List<Map<String, Object>>>[
            <Map<String, Object>>[
              {'type': 'string', 'key': 'sku', 'value': 'ABC-1'},
            ],
          ],
        },
      ]));
      expect(messages, equals(<String>[
        '[Insider] addParameterWithObjectArray dropped values that cannot be '
            'sent to native: 0.lines. The rest of the call was still sent.',
      ]));
    });
  });

  group('chaining and accumulation', () {
    test('accumulates parameters in the order they were added', () async {
      final args = await buildAndCapture((e) {
        e
            .addParameterWithString('s', 'x')
            .addParameterWithInt('i', 1)
            .addParameterWithDouble('d', 2.5)
            .addParameterWithBoolean('b', true);
      });

      final params = (args['parameters'] as List).cast<Map>();
      expect(params.map((p) => p['key']).toList(),
          equals(<String>['s', 'i', 'd', 'b']));
      expect(
        params.map((p) => p['type']).toList(),
        equals(<String>['string', 'integer', 'double', 'boolean']),
      );
    });

    test('keeps duplicate keys as separate entries (no deduplication)',
        () async {
      final args = await buildAndCapture((e) {
        e
            .addParameterWithString('k', 'first')
            .addParameterWithString('k', 'second');
      });

      expect(args['parameters'], hasLength(2));
      expect((args['parameters'] as List)[0]['value'], equals('first'));
      expect((args['parameters'] as List)[1]['value'], equals('second'));
    });
  });
}
