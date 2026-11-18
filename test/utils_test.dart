import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/constants.dart';
import 'package:flutter_insider/src/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Redirects `debugPrint` for the current test and returns the messages.
  List<String?> captureDebugPrint() {
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    return messages;
  }

  group('FlutterInsiderUtils.getDateForParsing', () {
    test('renders a local DateTime as ISO8601 with the same wall clock + Z',
        () {
      final date = DateTime(2024, 1, 15, 12, 30, 45, 678);

      expect(
        FlutterInsiderUtils.getDateForParsing(date),
        equals('2024-01-15T12:30:45.678Z'),
      );
    });

    test('renders a UTC DateTime as ISO8601 with the same wall clock', () {
      final date = DateTime.utc(2024, 6, 1, 9, 0, 0);

      expect(
        FlutterInsiderUtils.getDateForParsing(date),
        equals('2024-06-01T09:00:00.000Z'),
      );
    });

    test('keeps millisecond precision in the output', () {
      final date = DateTime(2024, 1, 1, 0, 0, 0, 123);

      expect(
        FlutterInsiderUtils.getDateForParsing(date),
        equals('2024-01-01T00:00:00.123Z'),
      );
    });
  });

  group('FlutterInsiderUtils.validateStringArray', () {
    test('returns null for null input', () {
      expect(FlutterInsiderUtils.validateStringArray(null), isNull);
    });

    test('returns an empty list for an empty list', () {
      expect(FlutterInsiderUtils.validateStringArray(<String>[]), isEmpty);
    });

    test('keeps an array whose entries are all empty, as native does', () {
      expect(
        FlutterInsiderUtils.validateStringArray(<String>['', '', '']),
        equals(<String>['', '', '']),
      );
    });

    test('keeps empty strings, as native does', () {
      expect(
        FlutterInsiderUtils.validateStringArray(<String>['a', '', 'b', '']),
        equals(<String>['a', '', 'b', '']),
      );
    });

    test('returns the original values when nothing is filtered', () {
      expect(
        FlutterInsiderUtils.validateStringArray(<String>['a', 'b', 'c']),
        equals(<String>['a', 'b', 'c']),
      );
    });

    test('preserves whitespace-only strings', () {
      expect(
        FlutterInsiderUtils.validateStringArray(<String>[' ', 'a']),
        equals(<String>[' ', 'a']),
      );
    });
  });

  group('FlutterInsiderUtils.validateNumericArray', () {
    test('returns null for null input', () {
      expect(FlutterInsiderUtils.validateNumericArray(null), isNull);
    });

    test('returns an empty list for an empty list', () {
      expect(FlutterInsiderUtils.validateNumericArray(<num>[]), isEmpty);
    });

    test('returns an empty list when every entry is non-finite', () {
      expect(
        FlutterInsiderUtils.validateNumericArray(
          <num>[double.nan, double.infinity, double.negativeInfinity],
        ),
        isEmpty,
      );
    });

    test('drops NaN and infinities and keeps finite values', () {
      final result = FlutterInsiderUtils.validateNumericArray(
        <num>[1, double.nan, 2.5, double.infinity, -3],
      );

      expect(result, equals(<num>[1, 2.5, -3]));
    });

    test('keeps mixed int and double values when all are finite', () {
      expect(
        FlutterInsiderUtils.validateNumericArray(<num>[1, 2.5, 3]),
        equals(<num>[1, 2.5, 3]),
      );
    });
  });

  group('FlutterInsiderUtils.serializeCustomParameters', () {
    test('returns an empty list for an empty map', () {
      expect(
        FlutterInsiderUtils.serializeCustomParameters(<String, Object>{}),
        isEmpty,
      );
    });

    test('encodes booleans with type "boolean"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'is_premium': true},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'boolean', 'key': 'is_premium', 'value': true},
          ]));
    });

    test('encodes ints with type "integer"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'age': 30},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'integer', 'key': 'age', 'value': 30},
          ]));
    });

    test('encodes doubles with type "double"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'score': 4.5},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'double', 'key': 'score', 'value': 4.5},
          ]));
    });

    test('encodes strings with type "string"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'plan': 'gold'},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string', 'key': 'plan', 'value': 'gold'},
          ]));
    });

    test('encodes DateTime as type "date" with epoch millis', () {
      final date = DateTime.utc(2024, 1, 15, 12, 0, 0);
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'last_login': date},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'date',
              'key': 'last_login',
              'value': date.millisecondsSinceEpoch,
            },
          ]));
    });

    test('encodes a non-empty all-string list as "string_array"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'tags': <String>['a', 'b'],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'string_array',
              'key': 'tags',
              'value': <String>['a', 'b']
            },
          ]));
    });

    test('encodes a non-empty all-numeric list as "numeric_array"', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'scores': <num>[1, 2.5, 3],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'numeric_array',
              'key': 'scores',
              'value': <num>[1, 2.5, 3],
            },
          ]));
    });

    test('sends an empty list with the element type Dart kept', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'empty': <String>[],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string_array', 'key': 'empty', 'value': <Object>[]},
          ]));
    });

    test('skips a mixed list of strings and numbers', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'mixed': <Object>['a', 1],
        },
      );

      expect(result, isEmpty);
    });

    test('skips values whose runtime type is not supported', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'nested': <String, String>{'k': 'v'},
        },
      );

      expect(result, isEmpty);
    });

    test('serializes multiple entries preserving each entry type', () {
      final date = DateTime.utc(2024, 1, 15);
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'is_premium': true,
          'age': 30,
          'score': 4.5,
          'plan': 'gold',
          'last_login': date,
          'tags': <String>['a', 'b'],
          'scores': <num>[1, 2],
        },
      );

      expect(result, hasLength(7));
      expect(
        result.map((e) => e['type']).toSet(),
        equals(<String>{
          'boolean',
          'integer',
          'double',
          'string',
          'date',
          'string_array',
          'numeric_array',
        }),
      );
    });
  });

  group('FlutterInsiderUtils.serializeCustomParameters with a Set', () {
    test('still skips a Set value (array-of-objects only accepts it)', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'tags': <String>{'a'},
        },
      );

      expect(result, isEmpty);
    });
  });

  group('FlutterInsiderUtils.serializeCustomParameters with non-finite numbers',
      () {
    test('drops NaN and infinite numbers, which break the native payload', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'ok': 1,
          'nan': double.nan,
          'inf': double.infinity,
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'integer', 'key': 'ok', 'value': 1},
          ]));
    });

    test('filters non-finite entries out of a numeric array, as native does',
        () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'with_nan': <num>[1, double.nan, 2.5],
          'with_inf': <num>[double.infinity, 3],
          'kept': <num>[1, 2.5],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'numeric_array',
              'key': 'with_nan',
              'value': <num>[1, 2.5]
            },
            {
              'type': 'numeric_array',
              'key': 'with_inf',
              'value': <num>[3]
            },
            {
              'type': 'numeric_array',
              'key': 'kept',
              'value': <num>[1, 2.5]
            },
          ]));
    });

    test('sends a developer-given empty list on the flat path', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{'tags': <String>[], 'scores': <num>[], 'any': []},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string_array', 'key': 'tags', 'value': <Object>[]},
            {'type': 'numeric_array', 'key': 'scores', 'value': <Object>[]},
            {'type': 'numeric_array', 'key': 'any', 'value': <Object>[]},
          ]));
    });

    test('still drops an empty list inside an object, as native does', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{'tags': <String>[], 'tier': 'gold'},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ]));
    });

    test('keeps an emptied numeric array on the flat path, as native does', () {
      final result = FlutterInsiderUtils.serializeCustomParameters(
        <String, Object>{
          'all_bad': <num>[double.nan, double.infinity]
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'numeric_array', 'key': 'all_bad', 'value': <num>[]},
          ]));
    });

    test('still drops a numeric array with a non-finite entry inside an object',
        () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'scores': <num>[1, double.nan],
          'tier': 'gold'
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ]));
    });
  });

  group('FlutterInsiderUtils.serializeObject', () {
    test('encodes flat entries with the custom parameter types', () {
      final date = DateTime.utc(2024, 1, 15);
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{'tier': 'gold', 'points': 1200, 'expires_at': date},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
            {'type': 'integer', 'key': 'points', 'value': 1200},
            {
              'type': 'date',
              'key': 'expires_at',
              'value': date.millisecondsSinceEpoch,
            },
          ]));
    });

    test('encodes a nested map as type "object" with a typed value list', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'address': <String, Object>{'city': 'Istanbul', 'is_default': true},
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'address',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
                {'type': 'boolean', 'key': 'is_default', 'value': true},
              ],
            },
          ]));
    });

    test('drops a map nested past what native stores, emptying its parent', () {
      // Native counts the top-level object as level 1 and refuses a map value
      // at level 2 (`StaticUtils.sanitizeObjectValue`), so `geo` goes, which
      // empties `address`, which empties the object.
      expect(
        FlutterInsiderUtils.serializeObject(<String, Object>{
          'address': <String, Object>{
            'geo': <String, Object>{'lat': 41.0},
          },
        }),
        isEmpty,
      );
    });

    test('encodes a map nested as deep as native stores', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'address': <String, Object>{'city': 'Istanbul'},
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'address',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
              ],
            },
          ]));
    });

    test('drops entries whose runtime type is not supported', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'lines': <Object>[
            <String, Object>{'sku': 'a'},
          ],
          'sku': 'abc',
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'string', 'key': 'sku', 'value': 'abc'},
          ]));
    });

    test('encodes a nested Map<String, dynamic> such as jsonDecode output', () {
      final Map<String, dynamic> shipping =
          jsonDecode('{"city": "Istanbul", "zip": 34000}')
              as Map<String, dynamic>;

      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{'shipping': shipping},
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'shipping',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
                {'type': 'integer', 'key': 'zip', 'value': 34000},
              ],
            },
          ]));
    });

    test('drops null values inside a nested map', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'shipping': <String, dynamic>{'city': 'Istanbul', 'zip': null},
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'shipping',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
              ],
            },
          ]));
    });

    test('encodes a Set of strings as "string_array", on both platforms alike',
        () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'tags': <String>{'a', 'b'},
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'string_array',
              'key': 'tags',
              'value': <String>['a', 'b']
            },
          ]));
    });

    test(
        'converts a Set of strings to a List so the message codec can encode it',
        () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'tags': <String>{'a', 'b'},
        },
      );

      expect(result.single['value'], isA<List<dynamic>>());
    });

    test(
        'converts a nested Set of numbers to a List so the message codec can '
        'encode it', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'stats': <String, Object>{
            'scores': <num>{1, 2.5}
          },
        },
      );

      final nested = result.single['value'] as List<Map<String, Object>>;
      expect(nested.single['value'], isA<List<dynamic>>());
    });

    test('encodes a Set of numbers inside a nested map as "numeric_array"', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'stats': <String, Object>{
            'scores': <num>{1, 2.5}
          },
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'stats',
              'value': <Map<String, Object>>[
                {
                  'type': 'numeric_array',
                  'key': 'scores',
                  'value': <num>[1, 2.5],
                },
              ],
            },
          ]));
    });

    test(
        'drops NaN and infinite numbers, which native rejects silently on Android',
        () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'ok': 1.5,
          'nan': double.nan,
          'inf': double.infinity,
          'nested': <String, Object>{
            'neg_inf': double.negativeInfinity,
            'k': 2
          },
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {'type': 'double', 'key': 'ok', 'value': 1.5},
            {
              'type': 'object',
              'key': 'nested',
              'value': <Map<String, Object>>[
                {'type': 'integer', 'key': 'k', 'value': 2},
              ],
            },
          ]));
    });

    test('drops a numeric array that contains an infinite number', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'scores': <num>[1, double.infinity],
          'ranks': <num>[3, double.negativeInfinity],
          'kept': <num>[1, 2],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'numeric_array',
              'key': 'kept',
              'value': <num>[1, 2]
            },
          ]));
    });

    test('drops a numeric array that contains a non-finite number', () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'scores': <num>[1, double.nan],
          'ranks': <num>[1, 2],
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'numeric_array',
              'key': 'ranks',
              'value': <num>[1, 2]
            },
          ]));
    });

    test('drops only the non-string keys of a nested map, like the native SDK',
        () {
      final result = FlutterInsiderUtils.serializeObject(
        <String, Object>{
          'address': <dynamic, Object>{1: 'x', 'city': 'Istanbul'},
        },
      );

      expect(
          result,
          equals(<Map<String, Object>>[
            {
              'type': 'object',
              'key': 'address',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
              ],
            },
          ]));
    });
  });

  group('FlutterInsiderUtils.isSendableKey', () {
    test('accepts a normal key without printing anything', () {
      final messages = captureDebugPrint();

      expect(FlutterInsiderUtils.isSendableKey('setName', 'tier'), isTrue);
      expect(messages, isEmpty);
    });

    test('rejects an empty or blank key and names the method', () {
      final messages = captureDebugPrint();

      expect(FlutterInsiderUtils.isSendableKey('setName', ''), isFalse);
      expect(FlutterInsiderUtils.isSendableKey('setName', '   '), isFalse);
      expect(
        messages,
        equals(<String>[
          '[Insider] setName ignored the call: an empty or whitespace-only key cannot be sent to native.',
          '[Insider] setName ignored the call: an empty or whitespace-only key cannot be sent to native.',
        ]),
      );
    });
  });

  group('FlutterInsiderUtils.putException', () {
    test('swallows a bridge failure instead of escaping to the zone', () async {
      const MethodChannel failing = MethodChannel('flutter_insider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(failing, (MethodCall call) async {
        throw PlatformException(code: 'X', message: 'reporter is down');
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(failing, null));

      Object? zoneError;
      await runZonedGuarded(() async {
        await FlutterInsiderUtils.putException(failing, 'boom');
      }, (Object error, StackTrace stack) {
        zoneError = error;
      });

      expect(zoneError, isNull);
    });
  });

  group('FlutterInsiderUtils.isSendableIdentifierValue', () {
    test('accepts a whitespace-only value, as native does', () {
      final messages = captureDebugPrint();

      expect(FlutterInsiderUtils.isSendableIdentifierValue('addUserID', '   '),
          isTrue);
      expect(messages, isEmpty);
    });

    test('rejects an empty value and names the method', () {
      final messages = captureDebugPrint();

      expect(FlutterInsiderUtils.isSendableIdentifierValue('addUserID', ''),
          isFalse);
      expect(
        messages.single,
        equals('[Insider] addUserID ignored the call: an empty value cannot '
            'be sent to native.'),
      );
    });
  });

  group('FlutterInsiderUtils.isSendableIdentifierSet', () {
    test('accepts a populated set without printing anything', () {
      final messages = captureDebugPrint();

      expect(
        FlutterInsiderUtils.isSendableIdentifierSet(
            Constants.LOGIN, <String, String>{Constants.ADD_EMAIL: 'a@b.com'}),
        isTrue,
      );
      expect(messages, isEmpty);
    });

    test('rejects an empty set and names the method', () {
      final messages = captureDebugPrint();

      expect(
        FlutterInsiderUtils.isSendableIdentifierSet(
            'someOtherCall', <String, String>{}),
        isFalse,
      );
      expect(
        messages.single,
        equals('[Insider] someOtherCall ignored the call: the identifier set '
            'is empty, so there is nothing to identify the user with.'),
      );
    });

    test('rejects a null set the same way', () {
      // `FlutterInsiderIdentifiers.identifiers` is a public mutable field, so
      // a caller can hand the builder back with no map at all.
      final messages = captureDebugPrint();

      expect(
        FlutterInsiderUtils.isSendableIdentifierSet(Constants.LOGIN, null),
        isFalse,
      );
      expect(
        messages.single,
        equals('[Insider] login ignored the call: the identifier set is '
            'empty, so there is nothing to identify the user with.'),
      );
    });
  });

  group('FlutterInsiderUtils.isSendableInteger', () {
    test('accepts both ends of the 32-bit range without printing anything', () {
      final messages = captureDebugPrint();

      expect(
          FlutterInsiderUtils.isSendableInteger('addParameterWithInt', 'n',
              FlutterInsiderUtils.MAX_SENDABLE_INTEGER),
          isTrue);
      expect(
          FlutterInsiderUtils.isSendableInteger('addParameterWithInt', 'n',
              -FlutterInsiderUtils.MAX_SENDABLE_INTEGER),
          isTrue);
      expect(messages, isEmpty);
    });

    test('rejects a value past either end and names the key', () {
      final messages = captureDebugPrint();

      expect(
          FlutterInsiderUtils.isSendableInteger(
              'addParameterWithInt', 'score', 3000000000),
          isFalse);
      expect(
          FlutterInsiderUtils.isSendableInteger(
              'addParameterWithInt', 'score', -3000000000),
          isFalse);
      expect(
        messages,
        equals(<String>[
          for (var i = 0; i < 2; i++)
            '[Insider] addParameterWithInt ignored score: only whole numbers '
                'within the 32-bit range can be sent to native.',
        ]),
      );
    });

    test('rejects the first value past either end', () {
      final messages = captureDebugPrint();

      expect(
          FlutterInsiderUtils.isSendableInteger('addParameterWithInt', 'n',
              FlutterInsiderUtils.MAX_SENDABLE_INTEGER + 1),
          isFalse);
      expect(
          FlutterInsiderUtils.isSendableInteger('addParameterWithInt', 'n',
              -FlutterInsiderUtils.MAX_SENDABLE_INTEGER - 1),
          isFalse);
      expect(messages, hasLength(2));
    });

    test('the 32-bit floor is excluded, as the other wrappers exclude it', () {
      expect(
          FlutterInsiderUtils.isSendableInteger(
              'addParameterWithInt', 'n', -2147483648),
          isFalse);
    });

    test('MAX_SENDABLE_INTEGER pins the value the other wrappers use', () {
      expect(FlutterInsiderUtils.MAX_SENDABLE_INTEGER, equals(2147483647));
    });
  });

  group('flat customParameters drop warnings', () {
    test('names every family, in the order the three wrappers agreed', () {
      final messages = captureDebugPrint();

      final serialized =
          FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        '': 'blank',
        '  ': 'blank too',
        'firstName': 'camel',
        'map': <String, Object>{'a': 1},
        'mixed': <Object>['a', 1],
        'nan': double.nan,
        'scores': <num>[1, double.infinity, 3],
        'flags': <bool>[true],
        'dates': <DateTime>[DateTime.utc(2020)],
        'ok': 1,
      });

      expect(
        serialized,
        equals(<Map<String, Object>>[
          {
            'type': 'numeric_array',
            'key': 'scores',
            'value': <num>[1, 3]
          },
          {'type': 'integer', 'key': 'ok', 'value': 1},
        ]),
      );
      expect(
        messages,
        equals(<String>[
          '[Insider] customParameters dropped 2 entries: an empty or '
              'whitespace-only key cannot be sent to native. The rest of the '
              'call was still sent.',
          '[Insider] customParameters dropped firstName: a key must start '
              'with a lowercase letter and hold only lowercase letters, '
              'digits and underscores. The rest of the call was still sent.',
          '[Insider] customParameters dropped map: the value is not a string, '
              'number, boolean, Date or array of those. The rest of the call '
              'was still sent.',
          '[Insider] customParameters dropped mixed: a list must hold one '
              'type, and this one holds several. The rest of the call was '
              'still sent.',
          '[Insider] customParameters dropped values that cannot be sent to '
              'native: nan. NaN and infinite numbers cannot be sent to '
              'native. The rest of the call was still sent.',
          '[Insider] customParameters dropped non-finite elements from: '
              'scores. NaN and infinite numbers cannot be sent to native. The '
              'rest of the call was still sent.',
          '[Insider] customParameters dropped flags, dates: the native SDKs '
              'store neither date arrays nor boolean arrays. The rest of the '
              'call was still sent.',
        ]),
      );
    });

    test('uses the singular form for a single blank key', () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.serializeCustomParameters(<String, Object>{'': 1});

      expect(
          messages.single,
          startsWith('[Insider] customParameters dropped '
              '1 entry: an empty or whitespace-only key'));
    });

    test('reports a Set and a list of lists as unusable values', () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'a_set': <String>{'s'},
        'nested': <Object>[
          <String>['a']
        ],
      });

      expect(
        messages.single,
        equals('[Insider] customParameters dropped a_set, nested: the value '
            'is not a string, number, boolean, Date or array of those. The '
            'rest of the call was still sent.'),
      );
    });

    test('blames a mixed array on holding several types, not on its elements',
        () {
      final messages = captureDebugPrint();

      // Each fixture holds one element of a reported kind next to one that is
      // not, so only a whole-array match may warn: a per-element check would
      // report them under the date/boolean family instead. A number next to a
      // date is deliberately absent — that pair shares one wire type.
      FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'mixed': <Object>['a', 1],
        'mixed_bool': <Object>[true, 'a'],
        'mixed_date': <Object>[DateTime.utc(2020), 'a'],
      });

      expect(
        messages.single,
        equals('[Insider] customParameters dropped mixed, mixed_bool, '
            'mixed_date: a list must hold one type, and this one holds '
            'several. The rest of the call was still sent.'),
      );
    });

    test('keeps the two list reasons in separate warnings', () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'a_set': <String>{'s'},
        'mixed': <Object>['a', 1],
      });

      expect(messages, hasLength(2));
      expect(
        messages,
        contains(allOf(
          contains('dropped a_set:'),
          contains('the value is not a string, number, boolean, Date'),
        )),
      );
      expect(
        messages,
        contains(allOf(
          contains('dropped mixed:'),
          contains('a list must hold one type, and this one holds several.'),
        )),
      );
    });

    test('stays silent when nothing is dropped', () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'scores': <num>[1, 2],
        'tags': <String>['a'],
        'empty': <num>[],
        'ok': 'x',
      });

      expect(messages, isEmpty);
    });
  });

  group('a list whose kinds are mixed', () {
    // Native has a `String[]` setter and a `Number[]` setter and nothing else,
    // so a list of mixed kinds has no setter to mirror. Choosing one for it
    // would send an array the caller never wrote. Cordova drops these too.
    test('drops a number/date list rather than converting the dates', () {
      final messages = captureDebugPrint();

      final out =
          FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'd': <Object>[1, DateTime.fromMillisecondsSinceEpoch(0)],
        'ok': 1,
      });

      expect(
          out,
          equals(<Map<String, Object>>[
            {'type': 'integer', 'key': 'ok', 'value': 1},
          ]));
      expect(
        messages.single,
        equals('[Insider] customParameters dropped d: a list must hold one '
            'type, and this one holds several. The rest of the call was still '
            'sent.'),
      );
    });

    test('drops a string/number list, naming it once', () {
      final messages = captureDebugPrint();

      final out =
          FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'd': <Object>['x', double.nan],
      });

      expect(out, isEmpty);
      expect(messages, hasLength(1));
    });

    test('drops a boolean/number list, naming it once', () {
      final messages = captureDebugPrint();

      final out =
          FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'd': <Object>[true, double.nan],
      });

      expect(out, isEmpty);
      expect(messages, hasLength(1));
    });

    test('still filters a pure number list, which native does itself', () {
      // `StaticUtils.validateNumericArray` drops non-finite elements from a
      // `Number[]`, so a native caller gets [1] for this input too.
      final messages = captureDebugPrint();

      final out =
          FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
        'd': <num>[1, double.nan],
      });

      expect(
          out,
          equals(<Map<String, Object>>[
            {
              'type': 'numeric_array',
              'key': 'd',
              'value': <num>[1]
            },
          ]));
      expect(
        messages.single,
        startsWith('[Insider] customParameters dropped non-finite elements '
            'from: d.'),
      );
    });
  });

  group('native object limits mirrored from the SDK', () {
    Map<String, Object> chainOf(int levels) {
      Map<String, Object> deep = <String, Object>{'leaf': 'v'};
      for (var i = 0; i < levels; i++) {
        deep = <String, Object>{'k$i': deep};
      }
      return deep;
    }

    test('keeps a chain that stays within the native nesting limit', () {
      // Native counts the top-level object as level 1, so one nested map is
      // the deepest it stores (`StaticUtils.sanitizeObjectValue`).
      final source = chainOf(1);

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isEmpty,
      );
    });

    test('drops the key one level past the native nesting limit', () {
      final source = chainOf(2);

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        hasLength(1),
      );
    });

    test('a chain deep enough to overflow the stack still returns', () {
      // The nesting limit cuts it at the second level, so the whole chain
      // empties out rather than recursing 50 000 times.
      expect(FlutterInsiderUtils.serializeObject(chainOf(50000)), isEmpty);
    });

    test('keeps a string of exactly the native length limit', () {
      final source = <String, Object>{'tier': 'x' * 500};

      expect(FlutterInsiderUtils.serializeObject(source), hasLength(1));
    });

    test('drops a string one character past the native length limit', () {
      // Literal, not `maxObjectStringLength + 1`: a test written relative to
      // the constant moves with it and stops seeing a changed limit.
      final source = <String, Object>{
        'tier': 'x' * 501,
        'ok': 'short',
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['tier']),
      );
    });

    test('drops the whole array when one element is over the limit', () {
      // Native refuses the array outright here rather than filtering it
      // (`StaticUtils.sanitizeObjectArrayValue` returns null), so the key goes
      // with it — unlike the scalar case where only that value is dropped.
      final source = <String, Object>{
        'tags': <String>['ok', 'x' * 501],
        'tier': 'gold',
      };

      final serialized = FlutterInsiderUtils.serializeObject(source);

      expect(
        serialized,
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'gold'},
        ]),
      );
      expect(FlutterInsiderUtils.droppedKeyPaths(source, serialized),
          equals(<String>['tags']));
    });

    test('keeps an array whose longest element is exactly at the limit', () {
      final source = <String, Object>{
        'tags': <String>['x' * 500],
      };

      expect(FlutterInsiderUtils.serializeObject(source), hasLength(1));
    });

    test('the flat parameter path leaves the array string limit to native', () {
      final long = 'x' * (FlutterInsiderUtils.maxObjectStringLength + 1);

      expect(
        FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
          'tags': <String>['ok', long],
        }),
        equals(<Map<String, Object>>[
          {
            'type': 'string_array',
            'key': 'tags',
            'value': <String>['ok', long]
          },
        ]),
      );
    });

    test('the flat parameter path leaves the string limit to native', () {
      final long = 'x' * (FlutterInsiderUtils.maxObjectStringLength + 1);

      expect(
        FlutterInsiderUtils.serializeCustomParameters(<String, Object>{
          'tier': long,
        }),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': long},
        ]),
      );
    });

    test('the mirrored constants pin the native values they copy', () {
      expect(FlutterInsiderUtils.maxObjectStringLength, equals(500));
      expect(FlutterInsiderUtils.maxObjectNestingDepth, equals(2));
      expect(FlutterInsiderUtils.nativeKeyPattern.pattern,
          equals(r'^[a-z][0-9a-z_]*$'));
    });
  });

  group('native key rule mirrored from the SDK', () {
    test('drops a key native would reject, naming its path', () {
      final source = <String, Object>{
        'firstName': 'camel',
        '9bad': 'leading digit',
        'UP': 'uppercase',
        'ok_key': 'kept',
      };

      final serialized = FlutterInsiderUtils.serializeObject(source);

      expect(
        serialized,
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'ok_key', 'value': 'kept'},
        ]),
      );
      expect(
        FlutterInsiderUtils.droppedKeyPaths(source, serialized),
        equals(<String>['firstName', '9bad', 'UP']),
      );
    });

    test('isSendableKey rejects a key native would reject', () {
      final messages = captureDebugPrint();

      expect(
          FlutterInsiderUtils.isSendableKey('setName', 'firstName'), isFalse);
      expect(
        messages.single,
        equals('[Insider] setName ignored the call: a key must start with a '
            'lowercase letter and hold only lowercase letters, digits and '
            'underscores.'),
      );
    });

    test('isSendableKey still accepts a valid key', () {
      final messages = captureDebugPrint();

      expect(FlutterInsiderUtils.isSendableKey('setName', 'tier_2'), isTrue);
      expect(messages, isEmpty);
    });
  });

  group('product labels in price warnings', () {
    test('names a product without an id instead of leaving the subject blank',
        () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.warnUnsendablePrice('itemPurchased', '');
      FlutterInsiderUtils.warnUnsendableProducts(
          'visitCartPage', <String>['', 'sku-1']);

      expect(
        messages,
        equals(<String>[
          '[Insider] itemPurchased skipped a product with no id: its price is '
              'NaN or infinite, so the call carrying it was not sent.',
          '[Insider] visitCartPage left out a product with no id, sku-1: their '
              'price is NaN or infinite. The rest of the call was still sent.',
        ]),
      );
    });

    test('treats a whitespace-only id as no id at all', () {
      final messages = captureDebugPrint();

      FlutterInsiderUtils.warnUnsendablePrice('itemPurchased', '   ');

      expect(
        messages.single,
        equals('[Insider] itemPurchased skipped a product with no id: its '
            'price is NaN or infinite, so the call carrying it was not sent.'),
      );
    });
  });

  group('blank keys inside an object', () {
    test('drops a blank or whitespace-only key and keeps the rest', () {
      expect(
        FlutterInsiderUtils.serializeObject(
          <String, Object>{'': 'gold', 'tier': 'x', '   ': 1},
        ),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'x'},
        ]),
      );
    });

    test('names the dropped blank key in the reported paths', () {
      final source = <String, Object>{'': 'gold', 'tier': 'x'};

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['<empty key>']),
      );
    });

    test('reports a nested blank key with its parent path', () {
      final source = <String, Object>{
        'address': <String, Object>{'': 'v', 'city': 'Istanbul'},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['address.<empty key>']),
      );
    });

    test('keeps blank keys out of the flat custom parameter path too', () {
      expect(
        FlutterInsiderUtils.serializeCustomParameters(
          <String, Object>{'  ': 'v', 'ok': 1},
        ),
        equals(<Map<String, Object>>[
          {'type': 'integer', 'key': 'ok', 'value': 1},
        ]),
      );
    });

    test('labels a whitespace-only key as <empty key> in the reported paths',
        () {
      final source = <String, Object>{'   ': 'gold', 'tier': 'x'};

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['<empty key>']),
      );
    });

    test('drops a blank key whose value is a nested map', () {
      expect(
        FlutterInsiderUtils.serializeObject(<String, Object>{
          '  ': <String, Object>{'city': 'Istanbul'},
          'tier': 'x',
        }),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'x'},
        ]),
      );
    });

    test('reports a blank key holding a map as one path, not its children', () {
      final source = <String, Object>{
        '  ': <String, Object>{'city': 'Istanbul'},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['<empty key>']),
      );
    });
  });

  group('FlutterInsiderUtils.serializeObject cycles', () {
    test('drops only the key that closes a cycle and keeps the rest', () {
      final Map<String, Object> source = <String, Object>{'tier': 'gold'};
      source['self'] = source;

      expect(
        FlutterInsiderUtils.serializeObject(source),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'gold'},
        ]),
      );
    });

    test('reports the dropped cycle key as a dropped path', () {
      final Map<String, Object> source = <String, Object>{'tier': 'gold'};
      source['self'] = source;

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['self']),
      );
    });

    test('drops a cycle that closes on an intermediate ancestor, not the root',
        () {
      // Both guards would drop `back` here, so this pins the outcome, not the
      // reason: the object path records no reason, only the dropped path.
      final Map<String, Object> address = <String, Object>{'city': 'Istanbul'};
      address['back'] = address;
      final source = <String, Object>{'tier': 'gold', 'address': address};

      expect(
        FlutterInsiderUtils.serializeObject(source),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'gold'},
          {
            'type': 'object',
            'key': 'address',
            'value': <Map<String, Object>>[
              {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
            ],
          },
        ]),
      );
      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['address.back']),
      );
    });

    test('keeps a repeated map that is not an ancestor', () {
      final Map<String, Object> shared = <String, Object>{'city': 'Istanbul'};
      final source = <String, Object>{'home': shared, 'work': shared};

      expect(
        FlutterInsiderUtils.serializeObject(source),
        equals(<Map<String, Object>>[
          {
            'type': 'object',
            'key': 'home',
            'value': <Map<String, Object>>[
              {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
            ],
          },
          {
            'type': 'object',
            'key': 'work',
            'value': <Map<String, Object>>[
              {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
            ],
          },
        ]),
      );
    });

    test('drops a nested cycle back to the root without losing its siblings',
        () {
      final Map<String, Object> address = <String, Object>{'city': 'Istanbul'};
      final Map<String, Object> source = <String, Object>{
        'tier': 'gold',
        'address': address,
      };
      address['root'] = source;

      expect(
        FlutterInsiderUtils.serializeObject(source),
        equals(<Map<String, Object>>[
          {'type': 'string', 'key': 'tier', 'value': 'gold'},
          {
            'type': 'object',
            'key': 'address',
            'value': <Map<String, Object>>[
              {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
            ],
          },
        ]),
      );
    });
  });

  group('FlutterInsiderUtils.droppedKeyPaths', () {
    test('returns no paths when every entry survived serialization', () {
      final source = <String, Object>{
        'tier': 'gold',
        'address': <String, Object>{'city': 'Istanbul'},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isEmpty,
      );
    });

    test('returns the dotted path of every dropped entry', () {
      final source = <String, Object>{
        'tier': 'gold',
        'mixed': <Object>['a', 1],
        'address': <dynamic, dynamic>{
          'city': 'Istanbul',
          'zip': null,
          1: 'x',
        },
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['mixed', 'address.zip', 'address.1']),
      );
    });
  });

  group('FlutterInsiderUtils.droppedKeyPaths at every nesting level', () {
    test('returns no paths for a nested map kept intact', () {
      final source = <String, Object>{
        'address': <String, Object>{'city': 'Istanbul', 'zip': '34000'},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isEmpty,
      );
    });

    test('names the parent when a too-deep map empties it', () {
      final source = <String, Object>{
        'address': <String, Object>{
          'geo': <String, Object>{'lat': 41.0},
        },
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        equals(<String>['address']),
      );
    });

    test('returns a path when a top-level entry was dropped', () {
      final source = <String, Object>{
        'tier': 'gold',
        'mixed': <Object>['a', 1],
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isNotEmpty,
      );
    });

    test('returns no paths for a nested Map<String, dynamic> kept intact', () {
      final source = <String, Object>{
        'address': jsonDecode('{"city": "Istanbul"}') as Map<String, dynamic>,
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isEmpty,
      );
    });

    test('returns a path when a null inside a nested map was dropped', () {
      final source = <String, Object>{
        'address': <String, dynamic>{'city': 'Istanbul', 'zip': null},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isNotEmpty,
      );
    });

    test('returns a path when a non-string key inside a nested map was dropped',
        () {
      final source = <String, Object>{
        'address': <dynamic, Object>{1: 'x', 'city': 'Istanbul'},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isNotEmpty,
      );
    });

    test('returns a path when an entry inside a nested map was dropped', () {
      final source = <String, Object>{
        'address': <String, Object>{'city': 'Istanbul', 'empty': <String>[]},
      };

      expect(
        FlutterInsiderUtils.droppedKeyPaths(
          source,
          FlutterInsiderUtils.serializeObject(source),
        ),
        isNotEmpty,
      );
    });
  });

  group('channel-touching helpers', () {
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

    group('getContentOptimizerMap', () {
      test('returns a map with the three expected keys and values', () {
        final result = FlutterInsiderUtils.getContentOptimizerMap(
          'banner_text',
          'fallback',
          1,
          channel,
        );

        expect(
          result,
          equals(<String, dynamic>{
            'variableName': 'banner_text',
            'defaultValue': 'fallback',
            'dataType': 1,
          }),
        );
      });

      test('does not invoke the channel in the happy path', () {
        FlutterInsiderUtils.getContentOptimizerMap('v', 'd', 0, channel);

        expect(capturedCalls, isEmpty);
      });

      test('accepts arbitrary defaultValue runtime types (dynamic)', () {
        final cases = <Object?>[
          null,
          'string-default',
          42,
          3.14,
          true,
          <String>['a', 'b'],
        ];

        for (final defaultValue in cases) {
          final result = FlutterInsiderUtils.getContentOptimizerMap(
            'v',
            defaultValue,
            2,
            channel,
          );

          expect(result, isA<Map<String, dynamic>>());
          expect(result['defaultValue'], equals(defaultValue),
              reason: 'defaultValue=$defaultValue');
          expect(result['dataType'], equals(2));
        }
      });

      test('echoes the dataType integer verbatim', () {
        for (final dataType in <int>[0, 1, 2, 3, 99]) {
          final result = FlutterInsiderUtils.getContentOptimizerMap(
            'v',
            'd',
            dataType,
            channel,
          );

          expect(result['dataType'], equals(dataType));
        }
      });
    });

    group('putException', () {
      // The three tests below are the contract the doc promises and nothing
      // else enforced until now: this future must never complete with an error.
      // No caller awaits it, so a rejection becomes an unhandled zone error in
      // the HOST app — its console and its crash reporter — on the one path
      // taken when something inside the plugin has already gone wrong.
      test('completes normally when the native handler throws', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          throw PlatformException(code: 'INSIDER_EXCEPTION');
        });

        await expectLater(
          FlutterInsiderUtils.putException(channel, Exception('boom')),
          completes,
        );
      });

      test('completes normally when the plugin is not registered', () async {
        // No handler at all is how a MissingPluginException reaches Dart.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        await expectLater(
          FlutterInsiderUtils.putException(channel, Exception('boom')),
          completes,
        );
      });

      test('completes normally when the exception\'s toString() throws',
          () async {
        await expectLater(
          FlutterInsiderUtils.putException(channel, _ThrowingToString()),
          completes,
        );
      });

      test('invokes the "putException" channel method', () async {
        await FlutterInsiderUtils.putException(channel, Exception('boom'));

        expect(capturedCalls, hasLength(1));
        expect(capturedCalls.single.method, equals('putException'));
      });

      test('passes exception.toString() under the "exception" arg key',
          () async {
        await FlutterInsiderUtils.putException(channel, Exception('boom'));

        final args =
            Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
        expect(args.keys, equals(<String>{'exception'}));
        expect(args['exception'], equals(Exception('boom').toString()));
      });

      test('serializes a plain string exception via toString()', () async {
        await FlutterInsiderUtils.putException(channel, 'just a string');

        final args =
            Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
        expect(args['exception'], equals('just a string'));
      });

      test('serializes a custom object via its toString()', () async {
        await FlutterInsiderUtils.putException(channel, _Boom());

        final args =
            Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
        expect(args['exception'], equals('boom-from-toString'));
      });

      test('captures one MethodCall per call when invoked twice', () async {
        await FlutterInsiderUtils.putException(channel, Exception('a'));
        await FlutterInsiderUtils.putException(channel, Exception('b'));

        expect(capturedCalls, hasLength(2));
        expect(
          capturedCalls
              .map((c) => (c.arguments as Map)['exception'] as String)
              .toList(),
          equals(<String>[
            Exception('a').toString(),
            Exception('b').toString(),
          ]),
        );
      });
    });

    group('putBridgeError', () {
      test('warns with the method name, the native error and the not-sent tail',
          () async {
        final messages = captureDebugPrint();
        final error =
            PlatformException(code: 'INVALID_ARGS', message: 'bad args');

        await FlutterInsiderUtils.putBridgeError(
            channel, Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE, error);

        expect(
          messages.single,
          equals('[Insider] ${Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE} was '
              'rejected by the native bridge: $error. The call was not sent.'),
        );
      });

      test('forwards the error to the native SDK via "putException"', () async {
        captureDebugPrint(); // keep the warning out of the test output
        final error =
            PlatformException(code: 'INVALID_ARGS', message: 'bad args');

        await FlutterInsiderUtils.putBridgeError(
            channel, Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE, error);

        expect(capturedCalls, hasLength(1));
        expect(capturedCalls.single.method, equals('putException'));
        expect(
          Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
          equals(<String, dynamic>{'exception': error.toString()}),
        );
      });
    });
  });
}

class _Boom {
  @override
  String toString() => 'boom-from-toString';
}

/// Stands in for an exception whose `toString()` itself fails — the one way
/// `putException` could still reject if the argument map were built outside its
/// try block.
class _ThrowingToString {
  @override
  String toString() => throw StateError('toString blew up');
}
