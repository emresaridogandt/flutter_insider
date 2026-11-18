import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/constants.dart';
import 'package:flutter_insider/src/identifiers.dart';
import 'package:flutter_insider/src/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_insider');

  late List<MethodCall> capturedCalls;
  Object? handlerReturn;

  void setHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedCalls.add(call);
      return handlerReturn;
    });
  }

  setUp(() {
    capturedCalls = <MethodCall>[];
    handlerReturn = null;
    setHandler();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Runs `action` and returns the single captured MethodCall.
  ///
  /// Use this helper to assert that exactly one platform-channel message was
  /// emitted by the action, and to inspect its method name + arguments.
  Future<MethodCall> expectSingleCall(void Function() action) async {
    action();
    await Future<void>.delayed(Duration.zero); // drain pending microtasks
    expect(capturedCalls, hasLength(1));
    return capturedCalls.single;
  }

  FlutterInsiderUser newUser() => FlutterInsiderUser(channel);

  /// Redirects `debugPrint` for the current test and returns the messages.
  List<String?> captureDebugPrint() {
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    return messages;
  }

  group('built-in string setters (passthrough value)', () {
    final cases = <_StringSetterCase>[
      _StringSetterCase(
          'setName', (u, v) => u.setName(v), Constants.SET_NAME, 'Alice'),
      _StringSetterCase('setSurname', (u, v) => u.setSurname(v),
          Constants.SET_SURNAME, 'Smith'),
      _StringSetterCase('setLanguage', (u, v) => u.setLanguage(v),
          Constants.SET_LANGUAGE, 'tr'),
      _StringSetterCase(
          'setLocale', (u, v) => u.setLocale(v), Constants.SET_LOCALE, 'tr_TR'),
      _StringSetterCase('setFacebookID', (u, v) => u.setFacebookID(v),
          Constants.SET_FACEBOOK_ID, 'fb-1'),
      _StringSetterCase('setTwitterID', (u, v) => u.setTwitterID(v),
          Constants.SET_TWITTER_ID, 'tw-1'),
      _StringSetterCase(
          'setEmail', (u, v) => u.setEmail(v), Constants.SET_EMAIL, 'a@b.com'),
      _StringSetterCase('setPhoneNumber', (u, v) => u.setPhoneNumber(v),
          Constants.SET_PHONE_NUMBER, '+1'),
    ];

    for (final c in cases) {
      test('${c.name} sends method "${c.wireMethod}" with raw string value',
          () async {
        final user = newUser();

        final call = await expectSingleCall(() => c.apply(user, c.value));

        expect(call.method, equals(c.wireMethod));
        expect(call.arguments, isA<Map>());
        expect(
          Map<String, dynamic>.from(call.arguments as Map),
          equals(<String, dynamic>{
            'key': c.wireMethod,
            'value': c.value,
          }),
        );
      });

      test('${c.name} returns the same instance for chaining', () {
        final user = newUser();

        expect(identical(c.apply(user, c.value), user), isTrue);
      });
    }
  });

  group('type-converting setters', () {
    test('setGender sends the int value verbatim (no stringification)',
        () async {
      final user = newUser();

      final call = await expectSingleCall(() => user.setGender(2));

      expect(call.method, equals(Constants.SET_GENDER));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': Constants.SET_GENDER,
          'value': 2,
        }),
      );
    });

    test('setBirthday serializes the DateTime as epoch ms string', () async {
      final birthday = DateTime.utc(1990, 5, 15);
      final user = newUser();

      final call = await expectSingleCall(() => user.setBirthday(birthday));

      expect(call.method, equals(Constants.SET_BIRTHDAY));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': Constants.SET_BIRTHDAY,
          'value': birthday.millisecondsSinceEpoch.toString(),
        }),
      );
    });

    test('setAge stringifies the int value', () async {
      final user = newUser();

      final call = await expectSingleCall(() => user.setAge(30));

      expect(call.method, equals(Constants.SET_AGE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': Constants.SET_AGE,
          'value': '30',
        }),
      );
    });

    test('setAge sends the highest value the 32-bit bridges carry', () async {
      final user = newUser();

      final call = await expectSingleCall(() => user.setAge(2147483647));

      expect((call.arguments as Map)['value'], equals('2147483647'));
    });

    test('setAge sends the lowest value the 32-bit bridges carry', () async {
      final user = newUser();

      final call = await expectSingleCall(() => user.setAge(-2147483647));

      expect((call.arguments as Map)['value'], equals('-2147483647'));
    });

    test('setAge refuses a value wider than the 32-bit range', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.setAge(3000000000);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] setAge ignored age: only whole numbers within the '
            '32-bit range can be sent to native.'),
      );
    });

    test('setAge refuses the 32-bit floor, as every wrapper does', () async {
      final user = newUser();

      user.setAge(-2147483648);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });

    final optinCases = <_OptinCase>[
      _OptinCase(
          'setSMSOptin', (u, v) => u.setSMSOptin(v), Constants.SET_SMS_OPTIN),
      _OptinCase('setEmailOptin', (u, v) => u.setEmailOptin(v),
          Constants.SET_EMAIL_OPTIN),
      _OptinCase('setLocationOptin', (u, v) => u.setLocationOptin(v),
          Constants.SET_LOCATION_OPTIN),
      _OptinCase('setPushOptin', (u, v) => u.setPushOptin(v),
          Constants.SET_PUSH_OPTIN),
      _OptinCase('setWhatsappOptin', (u, v) => u.setWhatsappOptin(v),
          Constants.SET_WHATSAPP_OPTIN),
      _OptinCase('setPromotionalOptin', (u, v) => u.setPromotionalOptin(v),
          Constants.SET_PROMOTIONAL_OPTIN),
    ];

    for (final c in optinCases) {
      test('${c.name} sends "true" / "false" string values', () async {
        final user = newUser();

        final trueCall = await expectSingleCall(() => c.apply(user, true));
        expect(trueCall.method, equals(c.wireMethod));
        expect((trueCall.arguments as Map)['value'], equals('true'));

        capturedCalls.clear();

        final falseCall = await expectSingleCall(() => c.apply(user, false));
        expect(falseCall.method, equals(c.wireMethod));
        expect((falseCall.arguments as Map)['value'], equals('false'));
      });
    }

    test('all type-converting setters return the same instance for chaining',
        () {
      final user = newUser();

      expect(identical(user.setGender(0), user), isTrue);
      expect(identical(user.setBirthday(DateTime.utc(2000)), user), isTrue);
      expect(identical(user.setAge(20), user), isTrue);
      expect(identical(user.setSMSOptin(true), user), isTrue);
      expect(identical(user.setEmailOptin(true), user), isTrue);
      expect(identical(user.setLocationOptin(true), user), isTrue);
      expect(identical(user.setPushOptin(true), user), isTrue);
      expect(identical(user.setWhatsappOptin(true), user), isTrue);
      expect(identical(user.setPromotionalOptin(true), user), isTrue);
    });
  });

  group('custom attribute setters', () {
    test('setCustomAttributeWithString routes to its dedicated method',
        () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.setCustomAttributeWithString('plan', 'gold'));

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_STRING));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'plan', 'value': 'gold'}),
      );
    });

    test('setCustomAttributeWithInt sends the int value verbatim', () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.setCustomAttributeWithInt('age', 30));

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_INT));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'age', 'value': 30}),
      );
    });

    test('setCustomAttributeWithInt drops a value past the 32-bit range',
        () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.setCustomAttributeWithInt('score', 3000000000);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] setCustomAttributeWithInt ignored score: only whole '
            'numbers within the 32-bit range can be sent to native.'),
      );
    });

    test('setCustomAttributeWithDouble sends the double value verbatim',
        () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.setCustomAttributeWithDouble('score', 4.5));

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_DOUBLE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'score', 'value': 4.5}),
      );
    });

    test('setCustomAttributeWithBoolean sends the bool value verbatim',
        () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.setCustomAttributeWithBoolean('vip', true));

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_BOOLEAN));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'vip', 'value': true}),
      );
    });

    test('setCustomAttributeWithDouble ignores NaN and infinity with a warning',
        () async {
      final user = newUser();
      final messages = captureDebugPrint();

      user
          .setCustomAttributeWithDouble('nan_score', double.nan)
          .setCustomAttributeWithDouble('inf_score', double.infinity);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
          messages,
          equals(<String>[
            '[Insider] ${Constants.SET_CUSTOM_ATTRIBUTE_WITH_DOUBLE} ignored '
                'nan_score: NaN and infinite numbers cannot be sent to native.',
            '[Insider] ${Constants.SET_CUSTOM_ATTRIBUTE_WITH_DOUBLE} ignored '
                'inf_score: NaN and infinite numbers cannot be sent to native.',
          ]));
    });

    test('setCustomAttributeWithDate serializes DateTime as epoch ms string',
        () async {
      final date = DateTime.utc(2024, 1, 15);
      final user = newUser();

      final call = await expectSingleCall(
          () => user.setCustomAttributeWithDate('last_login', date));

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_DATE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'last_login',
          'value': date.millisecondsSinceEpoch.toString(),
        }),
      );
    });

    test('setCustomAttributeWithArray sends the list verbatim (no filtering)',
        () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.setCustomAttributeWithArray(
          'tags',
          <String>['a', '', 'b'],
        ),
      );

      expect(call.method, equals(Constants.SET_CUSTOM_ATTRIBUTE_WITH_ARRAY));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'tags',
          'value': <String>['a', '', 'b'],
        }),
      );
    });

    test('all custom-attribute setters return the same instance for chaining',
        () {
      final user = newUser();

      expect(
          identical(user.setCustomAttributeWithString('k', 'v'), user), isTrue);
      expect(identical(user.setCustomAttributeWithInt('k', 1), user), isTrue);
      expect(
          identical(user.setCustomAttributeWithDouble('k', 1.0), user), isTrue);
      expect(identical(user.setCustomAttributeWithBoolean('k', true), user),
          isTrue);
      expect(
        identical(
          user.setCustomAttributeWithDate('k', DateTime.utc(2024)),
          user,
        ),
        isTrue,
      );
      expect(
        identical(
          user.setCustomAttributeWithArray('k', <String>['a']),
          user,
        ),
        isTrue,
      );
    });
  });

  group('blank keys', () {
    test('a blank key sends nothing and warns, on scalar and object setters',
        () async {
      final messages = captureDebugPrint();
      final user = FlutterInsiderUser(channel);

      user.setCustomAttributeWithString('  ', 'gold');
      user.setCustomAttributeWithInt('', 1);
      user.addObjectsToCustomAttribute('', <Map<String, Object>>[
        <String, Object>{'tier': 'gold'}
      ]);
      user.removeObjectsFromCustomAttribute('   ');
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages,
        equals(<String>[
          '[Insider] ${Constants.SET_CUSTOM_ATTRIBUTE_WITH_STRING} ignored the call: '
              'an empty or whitespace-only key cannot be sent to native.',
          '[Insider] ${Constants.SET_CUSTOM_ATTRIBUTE_WITH_INT} ignored the call: '
              'an empty or whitespace-only key cannot be sent to native.',
          '[Insider] ${Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE} ignored the call: '
              'an empty or whitespace-only key cannot be sent to native.',
          '[Insider] ${Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE} '
              'ignored the call: an empty or whitespace-only key cannot be sent to native.',
        ]),
      );
    });
  });

  group('bridge rejection reporting', () {
    test(
        'warns the developer and reports the error when native rejects the call',
        () async {
      final messages = captureDebugPrint();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE) {
          throw PlatformException(code: 'INVALID_ARGS', message: 'bad args');
        }
        return null;
      });

      FlutterInsiderUser(channel).addObjectsToCustomAttribute(
        'loyalty',
        <Map<String, Object>>[
          <String, Object>{'tier': 'gold'}
        ],
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        messages.single,
        allOf(
          contains(Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE),
          contains('rejected by the native bridge'),
        ),
      );
      expect(
          capturedCalls.map((c) => c.method),
          equals(<String>[
            Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE,
            'putException'
          ]));
    });

    test('mergeObjectsInCustomAttribute warns and reports when native rejects',
        () async {
      final messages = captureDebugPrint();
      final error =
          PlatformException(code: 'INVALID_ARGS', message: 'bad args');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE) {
          throw error;
        }
        return null;
      });

      FlutterInsiderUser(channel).mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{'tier': 'gold'},
        <String, Object>{'tier': 'platinum'},
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        messages.single,
        equals('[Insider] ${Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE} was '
            'rejected by the native bridge: $error. The call was not sent.'),
      );
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[
          Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE,
          'putException',
        ]),
      );
    });

    test(
        'removeObjectsFromCustomAttribute warns and reports when native rejects',
        () async {
      final messages = captureDebugPrint();
      final error =
          PlatformException(code: 'INVALID_ARGS', message: 'bad args');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE) {
          throw error;
        }
        return null;
      });

      FlutterInsiderUser(channel).removeObjectsFromCustomAttribute(
        'loyalty',
        <String, Object>{'tier': 'gold'},
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        messages.single,
        equals(
            '[Insider] ${Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE} was '
            'rejected by the native bridge: $error. The call was not sent.'),
      );
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[
          Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE,
          'putException',
        ]),
      );
    });
  });

  group('addObjectsToCustomAttribute', () {
    test('sends the key and every object as a typed parameter list', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{'tier': 'gold', 'points': 1200},
          <String, Object>{'tier': 'silver'},
        ]),
      );

      expect(call.method, equals(Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE));
      expect(Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE,
          equals('addObjectsToCustomAttribute'));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'value': <List<Map<String, Object>>>[
            <Map<String, Object>>[
              {'type': 'string', 'key': 'tier', 'value': 'gold'},
              {'type': 'integer', 'key': 'points', 'value': 1200},
            ],
            <Map<String, Object>>[
              {'type': 'string', 'key': 'tier', 'value': 'silver'},
            ],
          ],
        }),
      );
    });

    test('sends a nested map object as a typed object entry', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{
            'tier': 'gold',
            'address': <String, Object>{'city': 'Istanbul', 'zip': 34000},
          },
        ]),
      );

      expect(call.method, equals(Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'value': <List<Map<String, Object>>>[
            <Map<String, Object>>[
              {'type': 'string', 'key': 'tier', 'value': 'gold'},
              {
                'type': 'object',
                'key': 'address',
                'value': <Map<String, Object>>[
                  {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
                  {'type': 'integer', 'key': 'zip', 'value': 34000},
                ],
              },
            ],
          ],
        }),
      );
    });

    test('returns the same instance for chaining', () {
      final user = newUser();

      expect(
        identical(
          user.addObjectsToCustomAttribute('k', <Map<String, Object>>[
            <String, Object>{'a': 'b'}
          ]),
          user,
        ),
        isTrue,
      );
    });
  });

  group('addObjectsToCustomAttribute dropped values', () {
    test('warns once with index-prefixed dropped key paths, and still sends',
        () async {
      final user = newUser();
      final messages = captureDebugPrint();

      final call = await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{'tier': 'gold', 'tags': <String>[]},
          <String, Object>{
            'address': <dynamic, Object>{1: 'x', 'city': 'Istanbul'},
          },
        ]),
      );

      expect(call.method, equals(Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE));
      expect(
          messages,
          equals(<String>[
            '[Insider] ${Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE} dropped values '
                'that cannot be sent to native: 0.tags, 1.address.1. '
                'The rest of the call was still sent.',
          ]));
    });

    test('warns with the key path of a dropped NaN value', () async {
      final user = newUser();
      final messages = captureDebugPrint();

      await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{'tier': 'gold', 'ratio': double.nan},
        ]),
      );

      expect(
          messages,
          equals(<String>[
            '[Insider] ${Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE} dropped values '
                'that cannot be sent to native: 0.ratio. '
                'The rest of the call was still sent.',
          ]));
    });

    test('does not warn when every value can be sent', () async {
      final user = newUser();
      final messages = captureDebugPrint();

      await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{'tier': 'gold'},
        ]),
      );

      expect(messages, isEmpty);
    });
  });

  group('the native key rule at the user surface', () {
    test('setCustomAttributeWithString refuses a key native would reject',
        () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.setCustomAttributeWithString('firstName', 'camel');
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] setCustomAttributeWithString ignored the call: a '
            'key must start with a lowercase letter and hold only lowercase '
            'letters, digits and underscores.'),
      );
    });

    test('a keyless object is named by its index, not lost silently', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
        <String, Object>{},
        <String, Object>{'tier': 'gold'},
      ]);
      await Future<void>.delayed(Duration.zero);

      // The surviving object still goes out, so the loss of the first one
      // would be invisible without naming its index.
      expect(
        Map<String, dynamic>.from(
            capturedCalls.single.arguments as Map)['value'],
        equals(<List<Map<String, Object>>>[
          <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ],
        ]),
      );
      expect(
        messages.single,
        equals('[Insider] addObjectsToCustomAttribute dropped values that '
            'cannot be sent to native: 0. The rest of the call was still '
            'sent.'),
      );
    });
  });

  group('addObjectsToCustomAttribute when nothing survives', () {
    test('refuses the call instead of sending an empty object', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
        <String, Object>{'firstName': 'camel'},
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] addObjectsToCustomAttribute dropped values that '
            'cannot be sent to native: 0.firstName. Nothing was left to send, '
            'so the call was ignored.'),
      );
    });

    test('names a keyless object by its real position, not always the first',
        () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
        <String, Object>{'tier': 'gold'},
        <String, Object>{},
        <String, Object>{},
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        messages.single,
        equals('[Insider] addObjectsToCustomAttribute dropped values that '
            'cannot be sent to native: 1, 2. The rest of the call was still '
            'sent.'),
      );
    });

    test('names the object that had no key to drop', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.addObjectsToCustomAttribute(
          'loyalty', <Map<String, Object>>[<String, Object>{}]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] addObjectsToCustomAttribute dropped values that '
            'cannot be sent to native: 0. Nothing was left to send, so the '
            'call was ignored.'),
      );
    });

    test('still sends when at least one object keeps a key', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
          <String, Object>{'firstName': 'camel'},
          <String, Object>{'tier': 'gold'},
        ]),
      );

      // The emptied object is dropped from the list, not sent as a hole:
      // native's sanitizer only appends objects that survived.
      expect(
        Map<String, dynamic>.from(call.arguments as Map)['value'],
        equals(<List<Map<String, Object>>>[
          <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ],
        ]),
      );
    });
  });

  group('addObjectsToCustomAttribute empty list', () {
    test('is a no-op, as native treats it, and says so', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] addObjectsToCustomAttribute ignored the call: there '
            'are no objects to add.'),
      );
    });
  });

  group('mergeObjectsInCustomAttribute', () {
    test('sends the key, the typed match and the typed value', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.mergeObjectsInCustomAttribute(
          'loyalty',
          <String, Object>{'tier': 'gold'},
          <String, Object>{'points': 1500},
        ),
      );

      expect(call.method, equals(Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE));
      expect(Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE,
          equals('mergeObjectsInCustomAttribute'));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ],
          'value': <Map<String, Object>>[
            {'type': 'integer', 'key': 'points', 'value': 1500},
          ],
        }),
      );
    });

    test('sends a nested map value as a typed object entry', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.mergeObjectsInCustomAttribute(
          'loyalty',
          <String, Object>{'tier': 'gold'},
          <String, Object>{
            'reward': <String, Object>{'name': 'coffee', 'points': 50},
          },
        ),
      );

      expect(call.method, equals(Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ],
          'value': <Map<String, Object>>[
            {
              'type': 'object',
              'key': 'reward',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'name', 'value': 'coffee'},
                {'type': 'integer', 'key': 'points', 'value': 50},
              ],
            },
          ],
        }),
      );
    });

    test('sends a lossless nested match as a typed object entry', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.mergeObjectsInCustomAttribute(
          'loyalty',
          <String, Object>{
            'address': <String, Object>{'city': 'Istanbul'},
          },
          <String, Object>{'points': 1500},
        ),
      );

      expect(call.method, equals(Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {
              'type': 'object',
              'key': 'address',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
              ],
            },
          ],
          'value': <Map<String, Object>>[
            {'type': 'integer', 'key': 'points', 'value': 1500},
          ],
        }),
      );
    });

    test('warns with the method name when the match loses an entry', () async {
      final user = newUser();
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{
          'mixed': <Object>['a', 1]
        },
        <String, Object>{'points': 1500},
      );
      await Future<void>.delayed(Duration.zero);

      expect(messages, hasLength(1));
      expect(
        messages.single,
        contains(
            '[Insider] ${Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE} ignored'),
      );
    });

    test('does not warn when the match serializes losslessly', () async {
      final user = newUser();
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{'tier': 'gold'},
        <String, Object>{'points': 1500},
      );
      await Future<void>.delayed(Duration.zero);

      expect(messages, isEmpty);
    });

    test('warns with the dropped key paths when the value loses an entry',
        () async {
      final user = newUser();
      final messages = captureDebugPrint();

      await expectSingleCall(
        () => user.mergeObjectsInCustomAttribute(
          'loyalty',
          <String, Object>{'tier': 'gold'},
          <String, Object>{
            'points': 1500,
            'mixed': <Object>['a', 1]
          },
        ),
      );

      expect(
          messages,
          equals(<String>[
            '[Insider] ${Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE} dropped values '
                'that cannot be sent to native: mixed. '
                'The rest of the call was still sent.',
          ]));
    });

    test('names the dropped key paths when the match is ignored', () async {
      final user = newUser();
      final messages = captureDebugPrint();

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{
          'tier': 'gold',
          'address': <dynamic, Object>{1: 'x', 'city': 'Istanbul'},
        },
        <String, Object>{'points': 1500},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(messages, hasLength(1));
      expect(messages.single, contains('(address.1)'));
    });

    test('still sends the call when only the value loses an entry', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.mergeObjectsInCustomAttribute(
          'loyalty',
          <String, Object>{'tier': 'gold'},
          <String, Object>{
            'points': 1500,
            'mixed': <Object>['a', 1]
          },
        ),
      );

      expect(call.method, equals(Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'gold'},
          ],
          'value': <Map<String, Object>>[
            {'type': 'integer', 'key': 'points', 'value': 1500},
          ],
        }),
      );
    });

    test('sends nothing when the match loses an entry during serialization',
        () async {
      final user = newUser();

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{
          'tier': 'gold',
          'mixed': <Object>['a', 1]
        },
        <String, Object>{'points': 1500},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });

    test('returns the same instance for chaining', () {
      final user = newUser();

      expect(
        identical(
          user.mergeObjectsInCustomAttribute(
              'k', <String, Object>{'a': 'b'}, <String, Object>{'c': 'd'}),
          user,
        ),
        isTrue,
      );
    });

    test('refuses a value whose keys native would all reject', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{'tier': 'gold'},
        <String, Object>{'firstName': 'camel'},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] mergeObjectsInCustomAttribute dropped values that '
            'cannot be sent to native: firstName. Nothing was left to send, '
            'so the call was ignored.'),
      );
    });

    test('refuses an empty value, which has nothing to merge', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{'tier': 'gold'},
        <String, Object>{},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] mergeObjectsInCustomAttribute ignored the call: an '
            'empty value has nothing to merge.'),
      );
    });

    test('refuses an empty match instead of sending one', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.mergeObjectsInCustomAttribute(
        'loyalty',
        <String, Object>{},
        <String, Object>{'points': 1500},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] mergeObjectsInCustomAttribute ignored the call: an '
            'empty match would remove every object. Call it without a match '
            'if that is what you intended.'),
      );
    });
  });

  group('removeObjectsFromCustomAttribute', () {
    test('sends the key and the typed match', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.removeObjectsFromCustomAttribute(
            'loyalty', <String, Object>{'tier': 'bronze'}),
      );

      expect(
          call.method, equals(Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE));
      expect(Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE,
          equals('removeObjectsFromCustomAttribute'));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'bronze'},
          ],
        }),
      );
    });

    test('sends only the key when no match is given (removes every object)',
        () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.removeObjectsFromCustomAttribute('loyalty'));

      expect(
          call.method, equals(Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'loyalty'}),
      );
    });

    test('refuses an explicitly empty match, which would wipe the attribute',
        () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.removeObjectsFromCustomAttribute('loyalty', <String, Object>{});
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] removeObjectsFromCustomAttribute ignored the call: '
            'an empty match would remove every object. Call it without a '
            'match if that is what you intended.'),
      );
    });

    test('refuses an explicit null match, which is not the wildcard', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.removeObjectsFromCustomAttribute('loyalty', null);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] removeObjectsFromCustomAttribute ignored the call: '
            'a null match is not the wildcard. Call it without a match to '
            'remove every object.'),
      );
    });

    test('refuses a null match before it looks at the key', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.removeObjectsFromCustomAttribute('   ', null);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(messages.single, contains('a null match is not the wildcard'));
    });

    test('still accepts a nullable variable that holds a match', () async {
      final user = newUser();
      final Map<String, Object>? match = <String, Object>{'tier': 'bronze'};

      final call = await expectSingleCall(
          () => user.removeObjectsFromCustomAttribute('loyalty', match));

      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {'type': 'string', 'key': 'tier', 'value': 'bronze'},
          ],
        }),
      );
    });

    test('still clears the attribute when no match is given at all', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      final call = await expectSingleCall(
          () => user.removeObjectsFromCustomAttribute('loyalty'));

      expect(
        messages.single,
        equals("[Insider] removeObjectsFromCustomAttribute is removing every "
            "object of 'loyalty' because no match was given. This cannot be "
            "undone."),
      );

      expect(
          call.method, equals(Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'loyalty'}),
      );
    });

    test('sends a lossless nested match as a typed object entry', () async {
      final user = newUser();

      final call = await expectSingleCall(
        () => user.removeObjectsFromCustomAttribute(
          'loyalty',
          <String, Object>{
            'address': <String, Object>{'city': 'Istanbul', 'zip': 34000},
          },
        ),
      );

      expect(
          call.method, equals(Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{
          'key': 'loyalty',
          'match': <Map<String, Object>>[
            {
              'type': 'object',
              'key': 'address',
              'value': <Map<String, Object>>[
                {'type': 'string', 'key': 'city', 'value': 'Istanbul'},
                {'type': 'integer', 'key': 'zip', 'value': 34000},
              ],
            },
          ],
        }),
      );
    });

    test('warns with the method name when the match loses an entry', () async {
      final user = newUser();
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      user.removeObjectsFromCustomAttribute(
        'loyalty',
        <String, Object>{
          'mixed': <Object>['a', 1]
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(messages, hasLength(1));
      expect(
        messages.single,
        contains(
            '[Insider] ${Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE} ignored'),
      );
    });

    test('sends nothing when the match loses an entry during serialization',
        () async {
      final user = newUser();

      user.removeObjectsFromCustomAttribute(
        'loyalty',
        <String, Object>{
          'address': <String, Object>{'city': 'Istanbul', 'tags': <String>[]},
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });

    test('returns the same instance for chaining', () {
      final user = newUser();

      expect(
          identical(user.removeObjectsFromCustomAttribute('k'), user), isTrue);
    });
  });

  group('array-of-objects native errors', () {
    /// Makes every AoO method fail on the native side, as the bridges do when
    /// the native call throws, while still capturing the putException report.
    void failObjectCalls() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == 'putException') return null;
        throw PlatformException(code: 'INSIDER_EXCEPTION', message: 'boom');
      });
    }

    final cases = <String, void Function(FlutterInsiderUser)>{
      Constants.ADD_OBJECTS_TO_CUSTOM_ATTRIBUTE: (u) =>
          u.addObjectsToCustomAttribute('loyalty', <Map<String, Object>>[
            <String, Object>{'a': 'b'}
          ]),
      Constants.MERGE_OBJECTS_IN_CUSTOM_ATTRIBUTE: (u) => u
          .mergeObjectsInCustomAttribute('loyalty', <String, Object>{'a': 'b'},
              <String, Object>{'c': 'd'}),
      Constants.REMOVE_OBJECTS_FROM_CUSTOM_ATTRIBUTE: (u) =>
          u.removeObjectsFromCustomAttribute('loyalty'),
    };

    cases.forEach((method, action) {
      test('$method reports a native error through putException', () async {
        failObjectCalls();
        final user = newUser();

        action(user);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          capturedCalls.map((c) => c.method).toList(),
          equals(<String>[method, 'putException']),
        );
      });
    });
  });

  group('unsetCustomAttribute', () {
    test('sends only the key (no value field)', () async {
      final user = newUser();

      final call =
          await expectSingleCall(() => user.unsetCustomAttribute('plan'));

      expect(call.method, equals(Constants.UNSET_CUSTOM_ATTRIBUTE));
      expect(
        Map<String, dynamic>.from(call.arguments as Map),
        equals(<String, dynamic>{'key': 'plan'}),
      );
      expect((call.arguments as Map).containsKey('value'), isFalse);
    });

    test('returns the same instance for chaining', () {
      final user = newUser();

      expect(identical(user.unsetCustomAttribute('k'), user), isTrue);
    });
  });

  group('login', () {
    test('without insiderIDResult, sends only the identifiers map', () async {
      final user = newUser();
      final identifiers =
          FlutterInsiderIdentifiers().addEmail('a@b.com').addUserID('user-1');

      final call = await expectSingleCall(() => user.login(identifiers));

      expect(call.method, equals(Constants.LOGIN));
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(
          args['identifiers'],
          equals(<String, String>{
            Constants.ADD_EMAIL: 'a@b.com',
            Constants.ADD_USER_ID: 'user-1',
          }));
      expect(args.containsKey('insiderID'), isFalse);
    });

    test('with insiderIDResult, sends the insiderID flag', () async {
      final user = newUser();
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      handlerReturn = 'native-insider-id';

      final received = <Object?>[];
      final call = await expectSingleCall(() {
        user.login(identifiers, insiderIDResult: (id) => received.add(id));
      });

      expect(call.method, equals(Constants.LOGIN));
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['insiderID'], equals('insiderID'));
      expect(args['identifiers'], isA<Map>());
    });

    test('with insiderIDResult, the callback receives the native return value',
        () async {
      final user = newUser();
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      handlerReturn = 'native-insider-id';

      final received = <Object?>[];
      user.login(identifiers, insiderIDResult: (id) => received.add(id));

      // wait for the invokeMethod future + .then callback to resolve
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>['native-insider-id']));
    });

    test('an empty identifier set is not sent and is warned about', () async {
      final messages = captureDebugPrint();
      final user = newUser();

      user.login(FlutterInsiderIdentifiers());
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] login ignored the call: the identifier set is '
            'empty, so there is nothing to identify the user with.'),
      );
    });

    test('an empty identifier set still answers insiderIDResult', () async {
      captureDebugPrint();
      final user = newUser();

      // Native returns without touching its callback on an empty set, so an
      // unanswered callback is the defect this pins - not the missing call.
      final received = <Object?>[];
      user.login(FlutterInsiderIdentifiers(),
          insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(received, equals(<Object?>['']));
    });

    test('a callback taking a non-nullable String is answered, not thrown at',
        () async {
      captureDebugPrint();
      final user = newUser();

      // A `Function?` parameter hides the callback's own signature, so passing
      // null here threw a TypeError that putException swallowed - leaving the
      // callback unanswered, which is the defect this whole guard fixes.
      final received = <String>[];
      void callback(String insiderID) => received.add(insiderID);

      user.login(FlutterInsiderIdentifiers(), insiderIDResult: callback);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(received, equals(<String>['']));
    });

    test('an identifier set whose only entry was refused is empty too',
        () async {
      final messages = captureDebugPrint();
      final user = newUser();

      // The builder drops a blank value, so a set that looked populated at
      // the call site can still reach login carrying nothing.
      user.login(FlutterInsiderIdentifiers().addEmail(''));
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
      expect(
        messages,
        equals(<String>[
          '[Insider] addEmail ignored the call: an empty value cannot be sent '
              'to native.',
          '[Insider] login ignored the call: the identifier set is empty, so '
              'there is nothing to identify the user with.',
        ]),
      );
    });

    test(
        'with insiderIDResult, the callback receives the raw "" (Android path)',
        () async {
      handlerReturn = '';
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      final received = <Object?>[];

      newUser().login(identifiers, insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>['']));
    });

    test('with insiderIDResult, the callback receives null (iOS nil)',
        () async {
      handlerReturn = null;
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      final received = <Object?>[];

      newUser().login(identifiers, insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>[null]));
    });

    test('with insiderIDResult, reports the error when the callback throws',
        () async {
      handlerReturn = 'insider-id';
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      newUser().login(identifiers,
          insiderIDResult: (_) => throw StateError('partner bug'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGIN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('partner bug'),
      );
    });

    test(
        'with insiderIDResult, does not invoke the callback when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGIN) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });
      final received = <Object?>[];
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      newUser().login(identifiers, insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGIN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test(
        'without insiderIDResult, reports through putException when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGIN) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      newUser().login(identifiers);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGIN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });
  });

  group('loginAsync', () {
    test(
        'an empty identifier set is not sent, resolves null and is warned about',
        () async {
      final messages = captureDebugPrint();

      final result = await newUser().loginAsync(FlutterInsiderIdentifiers());

      expect(result, isNull);
      expect(capturedCalls, isEmpty);
      expect(
        messages.single,
        equals('[Insider] login ignored the call: the identifier set is '
            'empty, so there is nothing to identify the user with.'),
      );
    });

    test('always sends the insiderID flag with the identifiers map', () async {
      final identifiers =
          FlutterInsiderIdentifiers().addEmail('a@b.com').addUserID('user-1');

      await newUser().loginAsync(identifiers);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method, equals(Constants.LOGIN));
      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
        equals(<String, dynamic>{
          'identifiers': <String, String>{
            Constants.ADD_EMAIL: 'a@b.com',
            Constants.ADD_USER_ID: 'user-1',
          },
          'insiderID': 'insiderID',
        }),
      );
    });

    test('resolves the Insider ID the native side returned', () async {
      handlerReturn = 'native-insider-id';
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser().loginAsync(identifiers);

      expect(result, equals('native-insider-id'));
    });

    test('resolves null when native returns "" (Android path)', () async {
      handlerReturn = '';
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser().loginAsync(identifiers);

      expect(result, isNull);
    });

    test('resolves null when native returns an empty List (defensive)',
        () async {
      handlerReturn = <Object?>[];
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser().loginAsync(identifiers);

      expect(result, isNull);
    });

    test('resolves null when native returns null (iOS nil)', () async {
      handlerReturn = null;
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser().loginAsync(identifiers);

      expect(result, isNull);
    });

    test('resolves null and reports through putException when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGIN) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser().loginAsync(identifiers);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGIN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test('completes only after the native side answers', () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      var completed = false;

      final future = newUser()
          .loginAsync(identifiers)
          .whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      gate.complete('merged-id');
      expect(await future, equals('merged-id'));
      expect(completed, isTrue);
    });

    test('resolves null when native does not answer within the given timeout',
        () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final stopwatch = Stopwatch()..start();

      final result = await newUser()
          .loginAsync(identifiers, timeout: const Duration(milliseconds: 10));

      expect(result, isNull);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('reports a native failure that arrives after the timeout', () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return call.method == Constants.LOGIN ? gate.future : null;
      });
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');

      final result = await newUser()
          .loginAsync(identifiers, timeout: const Duration(milliseconds: 10));
      gate.completeError(
          PlatformException(code: 'ERROR', message: 'native failed late'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGIN, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed late'),
      );
    });

    testWidgets(
        'waits for the default timeout of 10 seconds before resolving null',
        (WidgetTester tester) async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      final identifiers = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      Object? result = 'pending';

      newUser().loginAsync(identifiers).then((String? id) => result = id);
      await tester.pump(const Duration(seconds: 9));

      expect(result, equals('pending'));

      await tester.pump(const Duration(seconds: 1));

      expect(result, isNull);
    });
  });

  group('logout', () {
    test('sends method LOGOUT with empty args', () async {
      final user = newUser();

      final call = await expectSingleCall(() => user.logout());

      expect(call.method, equals(Constants.LOGOUT));
      expect(Map<String, dynamic>.from(call.arguments as Map), isEmpty);
    });

    test('completes without error when native returns an empty List (iOS path)',
        () async {
      handlerReturn = <Object?>[];

      await newUser().logout();

      expect(capturedCalls.single.method, equals(Constants.LOGOUT));
    });

    test('completes and reports through putException when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGOUT) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });

      await newUser().logout();
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test('completes only after the native side answers', () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      var completed = false;

      final future = newUser().logout().whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      gate.complete('');
      await future;
      expect(completed, isTrue);
    });
  });

  group('logoutResettingInsiderID', () {
    test('with null additionalIdentifiers, sends empty args', () async {
      final user = newUser();

      final call =
          await expectSingleCall(() => user.logoutResettingInsiderID(null));

      expect(call.method, equals(Constants.LOGOUT_RESETTING_INSIDER_ID));
      expect(Map<String, dynamic>.from(call.arguments as Map), isEmpty);
    });

    test('with empty additionalIdentifiers list, sends empty args', () async {
      final user = newUser();

      final call = await expectSingleCall(
          () => user.logoutResettingInsiderID(<FlutterInsiderIdentifiers>[]));

      expect(call.method, equals(Constants.LOGOUT_RESETTING_INSIDER_ID));
      expect(Map<String, dynamic>.from(call.arguments as Map), isEmpty);
    });

    test('with non-empty additionalIdentifiers, sends each identifier as a map',
        () async {
      final user = newUser();
      final id1 = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      final id2 = FlutterInsiderIdentifiers()..addUserID('user-1');

      final call = await expectSingleCall(
        () => user
            .logoutResettingInsiderID(<FlutterInsiderIdentifiers>[id1, id2]),
      );

      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(
          args['additionalIdentifiers'],
          equals(<Map<String, String>>[
            <String, String>{Constants.ADD_EMAIL: 'a@b.com'},
            <String, String>{Constants.ADD_USER_ID: 'user-1'},
          ]));
      expect(args.containsKey('insiderIDResult'), isFalse);
    });

    test('with insiderIDResult callback, sends the insiderIDResult flag',
        () async {
      final user = newUser();

      handlerReturn = 'reset-id';

      final call = await expectSingleCall(() {
        user.logoutResettingInsiderID(
          null,
          insiderIDResult: (_) {},
        );
      });

      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['insiderIDResult'], equals('insiderIDResult'));
    });

    test(
        'with insiderIDResult callback, the callback receives the native return',
        () async {
      final user = newUser();

      handlerReturn = 'reset-id';

      final received = <Object?>[];
      user.logoutResettingInsiderID(null,
          insiderIDResult: (id) => received.add(id));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>['reset-id']));
    });

    test(
        'with insiderIDResult, the callback receives the raw "" (Android path)',
        () async {
      handlerReturn = '';
      final received = <Object?>[];

      newUser().logoutResettingInsiderID(null,
          insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>['']));
    });

    test('with insiderIDResult, the callback receives null (iOS nil)',
        () async {
      handlerReturn = null;
      final received = <Object?>[];

      newUser().logoutResettingInsiderID(null,
          insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<Object?>[null]));
    });

    test('with insiderIDResult, reports the error when the callback throws',
        () async {
      handlerReturn = 'insider-id';

      newUser().logoutResettingInsiderID(null,
          insiderIDResult: (_) => throw StateError('partner bug'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT_RESETTING_INSIDER_ID, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('partner bug'),
      );
    });

    test(
        'with insiderIDResult, does not invoke the callback when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGOUT_RESETTING_INSIDER_ID) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });
      final received = <Object?>[];

      newUser().logoutResettingInsiderID(null,
          insiderIDResult: (id) => received.add(id));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT_RESETTING_INSIDER_ID, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test(
        'without insiderIDResult, reports through putException when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGOUT_RESETTING_INSIDER_ID) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });

      newUser().logoutResettingInsiderID(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT_RESETTING_INSIDER_ID, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });
  });

  group('logoutResettingInsiderIDAsync', () {
    test('with null additionalIdentifiers, sends only the insiderIDResult flag',
        () async {
      await newUser().logoutResettingInsiderIDAsync(null);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method,
          equals(Constants.LOGOUT_RESETTING_INSIDER_ID));
      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
        equals(<String, dynamic>{'insiderIDResult': 'insiderIDResult'}),
      );
    });

    test(
        'with empty additionalIdentifiers list, sends only the insiderIDResult flag',
        () async {
      await newUser()
          .logoutResettingInsiderIDAsync(<FlutterInsiderIdentifiers>[]);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
        equals(<String, dynamic>{'insiderIDResult': 'insiderIDResult'}),
      );
    });

    test(
        'with non-empty additionalIdentifiers, sends each identifier as a map with the flag',
        () async {
      final id1 = FlutterInsiderIdentifiers()..addEmail('a@b.com');
      final id2 = FlutterInsiderIdentifiers()..addUserID('user-1');

      await newUser()
          .logoutResettingInsiderIDAsync(<FlutterInsiderIdentifiers>[id1, id2]);

      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
        equals(<String, dynamic>{
          'additionalIdentifiers': <Map<String, String>>[
            <String, String>{Constants.ADD_EMAIL: 'a@b.com'},
            <String, String>{Constants.ADD_USER_ID: 'user-1'},
          ],
          'insiderIDResult': 'insiderIDResult',
        }),
      );
    });

    test('resolves the Insider ID the native side returned', () async {
      handlerReturn = 'native-insider-id';

      final result = await newUser().logoutResettingInsiderIDAsync(null);

      expect(result, equals('native-insider-id'));
    });

    test('resolves null when native returns "" (Android path)', () async {
      handlerReturn = '';

      final result = await newUser().logoutResettingInsiderIDAsync(null);

      expect(result, isNull);
    });

    test('resolves null when native returns an empty List (defensive)',
        () async {
      handlerReturn = <Object?>[];

      final result = await newUser().logoutResettingInsiderIDAsync(null);

      expect(result, isNull);
    });

    test('resolves null when native returns null (iOS nil)', () async {
      handlerReturn = null;

      final result = await newUser().logoutResettingInsiderIDAsync(null);

      expect(result, isNull);
    });

    test('resolves null and reports through putException when native throws',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        if (call.method == Constants.LOGOUT_RESETTING_INSIDER_ID) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }
        return null;
      });

      final result = await newUser().logoutResettingInsiderIDAsync(null);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT_RESETTING_INSIDER_ID, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed'),
      );
    });

    test('completes only after the native side answers', () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      var completed = false;

      final future = newUser()
          .logoutResettingInsiderIDAsync(null)
          .whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      gate.complete('merged-id');
      expect(await future, equals('merged-id'));
      expect(completed, isTrue);
    });

    test('resolves null when native does not answer within the given timeout',
        () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);

      final stopwatch = Stopwatch()..start();

      final result = await newUser().logoutResettingInsiderIDAsync(null,
          timeout: const Duration(milliseconds: 10));

      expect(result, isNull);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('reports a native failure that arrives after the timeout', () async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return call.method == Constants.LOGOUT_RESETTING_INSIDER_ID
            ? gate.future
            : null;
      });

      final result = await newUser().logoutResettingInsiderIDAsync(null,
          timeout: const Duration(milliseconds: 10));
      gate.completeError(
          PlatformException(code: 'ERROR', message: 'native failed late'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.LOGOUT_RESETTING_INSIDER_ID, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(
            capturedCalls.last.arguments as Map)['exception'],
        contains('native failed late'),
      );
    });

    testWidgets(
        'waits for the default timeout of 10 seconds before resolving null',
        (WidgetTester tester) async {
      final gate = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) => gate.future);
      Object? result = 'pending';

      newUser()
          .logoutResettingInsiderIDAsync(null)
          .then((String? id) => result = id);
      await tester.pump(const Duration(seconds: 9));

      expect(result, equals('pending'));

      await tester.pump(const Duration(seconds: 1));

      expect(result, isNull);
    });
  });
}

class _StringSetterCase {
  _StringSetterCase(this.name, this.apply, this.wireMethod, this.value);

  final String name;
  final FlutterInsiderUser Function(FlutterInsiderUser, String) apply;
  final String wireMethod;
  final String value;
}

class _OptinCase {
  _OptinCase(this.name, this.apply, this.wireMethod);

  final String name;
  final FlutterInsiderUser Function(FlutterInsiderUser, bool) apply;
  final String wireMethod;
}
