import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/constants.dart';
import 'package:flutter_insider/src/identifiers.dart';

void main() {
  /// Redirects `debugPrint` for the current test and returns the messages.
  List<String?> captureDebugPrint() {
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    return messages;
  }

  group('FlutterInsiderIdentifiers constructor', () {
    test('initializes with a non-null empty identifiers map', () {
      final builder = FlutterInsiderIdentifiers();

      expect(builder.getIdentifiers(), isNotNull);
      expect(builder.getIdentifiers(), isEmpty);
    });
  });

  group('blank values and keys', () {
    test('an empty value is dropped with a warning on every identifier', () {
      final messages = captureDebugPrint();
      final builder = FlutterInsiderIdentifiers()
          .addEmail('')
          .addPhoneNumber('')
          .addUserID('')
          .addCustomIdentifier('loyalty', '')
          .addEmail('a@b.com');

      expect(builder.getIdentifiers(), equals({Constants.ADD_EMAIL: 'a@b.com'}));
      expect(
        messages,
        equals(<String>[
          for (final method in <String>[
            Constants.ADD_EMAIL,
            Constants.ADD_PHONE_NUMBER,
            Constants.ADD_USER_ID,
            'addCustomIdentifier',
          ])
            '[Insider] $method ignored the call: an empty value cannot be sent '
                'to native.',
        ]),
      );
    });

    test('a whitespace-only value is forwarded, as native accepts it', () {
      final messages = captureDebugPrint();
      final builder = FlutterInsiderIdentifiers()
          .addUserID('   ')
          .addCustomIdentifier('loyalty', '  ');

      expect(
        builder.getIdentifiers(),
        equals(<String, String>{
          Constants.ADD_USER_ID: '   ',
          'loyalty': '  ',
        }),
      );
      expect(messages, isEmpty);
    });

    test('a camelCase custom identifier key is dropped with a warning', () {
      // Native applies the same name rule here (`InsiderIdentifiers`
      // -> `isNameValid`), and camelCase is the spelling a Dart caller
      // reaches for by default.
      final messages = captureDebugPrint();
      final builder = FlutterInsiderIdentifiers().addCustomIdentifier(
          'crmId', 'v');

      expect(builder.getIdentifiers(), isEmpty);
      expect(
        messages.single,
        equals('[Insider] addCustomIdentifier ignored the call: a key must '
            'start with a lowercase letter and hold only lowercase letters, '
            'digits and underscores.'),
      );
    });

    test('a blank custom identifier key is dropped with a warning', () {
      final messages = captureDebugPrint();
      final builder = FlutterInsiderIdentifiers().addCustomIdentifier('  ', 'v');

      expect(builder.getIdentifiers(), isEmpty);
      expect(
        messages.single,
        equals('[Insider] addCustomIdentifier ignored the call: an empty or '
            'whitespace-only key cannot be sent to native.'),
      );
    });
  });

  group('addEmail', () {
    test('writes the value under Constants.ADD_EMAIL', () {
      final builder = FlutterInsiderIdentifiers().addEmail('a@b.com');

      expect(builder.getIdentifiers(), equals({Constants.ADD_EMAIL: 'a@b.com'}));
      expect(Constants.ADD_EMAIL, equals('addEmail'));
    });

    test('returns the same builder instance for chaining', () {
      final builder = FlutterInsiderIdentifiers();

      expect(identical(builder.addEmail('a@b.com'), builder), isTrue);
    });

    test('overwrites a previous email when called twice', () {
      final builder = FlutterInsiderIdentifiers()
          .addEmail('first@b.com')
          .addEmail('second@b.com');

      expect(builder.getIdentifiers(),
          equals({Constants.ADD_EMAIL: 'second@b.com'}));
    });
  });

  group('addPhoneNumber', () {
    test('writes the value under Constants.ADD_PHONE_NUMBER', () {
      final builder = FlutterInsiderIdentifiers().addPhoneNumber('+905551112233');

      expect(
        builder.getIdentifiers(),
        equals({Constants.ADD_PHONE_NUMBER: '+905551112233'}),
      );
      expect(Constants.ADD_PHONE_NUMBER, equals('addPhoneNumber'));
    });

    test('returns the same builder instance for chaining', () {
      final builder = FlutterInsiderIdentifiers();

      expect(identical(builder.addPhoneNumber('+1'), builder), isTrue);
    });

    test('overwrites a previous phone number when called twice', () {
      final builder = FlutterInsiderIdentifiers()
          .addPhoneNumber('+1')
          .addPhoneNumber('+2');

      expect(builder.getIdentifiers(),
          equals({Constants.ADD_PHONE_NUMBER: '+2'}));
    });
  });

  group('addUserID', () {
    test('writes the value under Constants.ADD_USER_ID', () {
      final builder = FlutterInsiderIdentifiers().addUserID('user-42');

      expect(
        builder.getIdentifiers(),
        equals({Constants.ADD_USER_ID: 'user-42'}),
      );
      expect(Constants.ADD_USER_ID, equals('addUserID'));
    });

    test('returns the same builder instance for chaining', () {
      final builder = FlutterInsiderIdentifiers();

      expect(identical(builder.addUserID('u'), builder), isTrue);
    });

    test('overwrites a previous user id when called twice', () {
      final builder = FlutterInsiderIdentifiers()
          .addUserID('first')
          .addUserID('second');

      expect(builder.getIdentifiers(),
          equals({Constants.ADD_USER_ID: 'second'}));
    });
  });

  group('addCustomIdentifier', () {
    test('writes the given key/value into the map verbatim', () {
      final builder =
          FlutterInsiderIdentifiers().addCustomIdentifier('loyalty_id', 'L-99');

      expect(builder.getIdentifiers(), equals({'loyalty_id': 'L-99'}));
    });

    test('returns the same builder instance for chaining', () {
      final builder = FlutterInsiderIdentifiers();

      expect(
        identical(builder.addCustomIdentifier('k', 'v'), builder),
        isTrue,
      );
    });

    test('refuses a key native would reject, leaving the built-in intact', () {
      // Constants.ADD_EMAIL is camelCase, which native's own key rule
      // (`InsiderIdentifiers.addCustomIdentifier` -> `isNameValid`) rejects,
      // so the collision this used to pin was never reachable natively.
      final messages = captureDebugPrint();
      final builder = FlutterInsiderIdentifiers()
          .addEmail('a@b.com')
          .addCustomIdentifier(Constants.ADD_EMAIL, 'overridden');

      expect(builder.getIdentifiers(),
          equals({Constants.ADD_EMAIL: 'a@b.com'}));
      // The refusal has to be visible, or a silent guard would pass this too.
      expect(
        messages.single,
        equals('[Insider] addCustomIdentifier ignored the call: a key must '
            'start with a lowercase letter and hold only lowercase letters, '
            'digits and underscores.'),
      );
    });
  });

  group('chaining', () {
    test('combines all identifiers into a single map', () {
      final builder = FlutterInsiderIdentifiers()
          .addEmail('a@b.com')
          .addPhoneNumber('+1')
          .addUserID('user-1')
          .addCustomIdentifier('loyalty_id', 'L-1');

      expect(
        builder.getIdentifiers(),
        equals({
          Constants.ADD_EMAIL: 'a@b.com',
          Constants.ADD_PHONE_NUMBER: '+1',
          Constants.ADD_USER_ID: 'user-1',
          'loyalty_id': 'L-1',
        }),
      );
      expect(builder.getIdentifiers(), hasLength(4));
    });
  });

  group('getIdentifiers', () {
    test('returns an empty map for a fresh builder', () {
      expect(FlutterInsiderIdentifiers().getIdentifiers(), isEmpty);
    });

    test('returns the live internal map (mutations are visible)', () {
      final builder = FlutterInsiderIdentifiers().addEmail('a@b.com');

      final firstView = builder.getIdentifiers();
      builder.addUserID('user-1');
      final secondView = builder.getIdentifiers();

      expect(identical(firstView, secondView), isTrue);
      expect(secondView, hasLength(2));
    });
  });
}
