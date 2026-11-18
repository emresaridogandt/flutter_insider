import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/app_cards_error.dart';

void main() {
  group('InsiderAppCardsErrorCode enum', () {
    test('exposes the documented set of values', () {
      expect(InsiderAppCardsErrorCode.values, hasLength(6));
      expect(
        InsiderAppCardsErrorCode.values.toSet(),
        equals(<InsiderAppCardsErrorCode>{
          InsiderAppCardsErrorCode.unknown,
          InsiderAppCardsErrorCode.sdkNotInitialized,
          InsiderAppCardsErrorCode.invalidParameter,
          InsiderAppCardsErrorCode.networkError,
          InsiderAppCardsErrorCode.serverError,
          InsiderAppCardsErrorCode.parseError,
        }),
      );
    });

    test('each value name uses the camelCase wire contract', () {
      final names = InsiderAppCardsErrorCode.values.map((e) => e.name).toList();
      expect(
        names,
        containsAll(<String>[
          'unknown',
          'sdkNotInitialized',
          'invalidParameter',
          'networkError',
          'serverError',
          'parseError',
        ]),
      );
    });
  });

  group('InsiderAppCardsError.fromMap', () {
    test('maps every known code string to its enum value', () {
      const cases = <String, InsiderAppCardsErrorCode>{
        'unknown': InsiderAppCardsErrorCode.unknown,
        'sdkNotInitialized': InsiderAppCardsErrorCode.sdkNotInitialized,
        'invalidParameter': InsiderAppCardsErrorCode.invalidParameter,
        'networkError': InsiderAppCardsErrorCode.networkError,
        'serverError': InsiderAppCardsErrorCode.serverError,
        'parseError': InsiderAppCardsErrorCode.parseError,
      };

      cases.forEach((rawCode, expected) {
        final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
          'code': rawCode,
          'message': 'msg for $rawCode',
        });

        expect(error.code, equals(expected), reason: 'rawCode=$rawCode');
        expect(error.message, equals('msg for $rawCode'));
      });
    });

    test('falls back to unknown when code string is not recognized', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
        'code': 'something_we_did_not_define',
        'message': 'boom',
      });

      expect(error.code, equals(InsiderAppCardsErrorCode.unknown));
      expect(error.message, equals('boom'));
    });

    test('treats different casing as unknown (asNameMap is case-sensitive)', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
        'code': 'NetworkError',
        'message': 'wrong casing',
      });

      expect(error.code, equals(InsiderAppCardsErrorCode.unknown));
      expect(error.message, equals('wrong casing'));
    });

    test('falls back to unknown when code field is missing', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
        'message': 'no code here',
      });

      expect(error.code, equals(InsiderAppCardsErrorCode.unknown));
      expect(error.message, equals('no code here'));
    });

    test('uses the default message when message field is missing', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
        'code': 'serverError',
      });

      expect(error.code, equals(InsiderAppCardsErrorCode.serverError));
      expect(error.message, equals('An unexpected error occurred.'));
    });

    test('returns unknown + default message when both fields are missing', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{});

      expect(error.code, equals(InsiderAppCardsErrorCode.unknown));
      expect(error.message, equals('An unexpected error occurred.'));
    });

    test('accepts an empty string message verbatim (no default substitution)', () {
      final error = InsiderAppCardsError.fromMap(<dynamic, dynamic>{
        'code': 'networkError',
        'message': '',
      });

      expect(error.code, equals(InsiderAppCardsErrorCode.networkError));
      expect(error.message, equals(''));
    });
  });

  group('InsiderAppCardsError.toString', () {
    test('renders the documented format', () {
      const error = InsiderAppCardsError(
        code: InsiderAppCardsErrorCode.parseError,
        message: 'failed to decode',
      );

      expect(
        error.toString(),
        equals(
          'InsiderAppCardsError(code: InsiderAppCardsErrorCode.parseError, '
          'message: failed to decode)',
        ),
      );
    });
  });

  group('InsiderAppCardsException', () {
    test('toString includes the wrapped error message', () {
      const exception = InsiderAppCardsException(
        InsiderAppCardsError(
          code: InsiderAppCardsErrorCode.networkError,
          message: 'host unreachable',
        ),
      );

      expect(
        exception.toString(),
        equals('InsiderAppCardsException: host unreachable'),
      );
    });

    test('implements the Exception interface', () {
      const exception = InsiderAppCardsException(
        InsiderAppCardsError(
          code: InsiderAppCardsErrorCode.unknown,
          message: 'x',
        ),
      );

      expect(exception, isA<Exception>());
    });

    test('exposes the wrapped error instance', () {
      const wrapped = InsiderAppCardsError(
        code: InsiderAppCardsErrorCode.invalidParameter,
        message: 'bad arg',
      );
      const exception = InsiderAppCardsException(wrapped);

      expect(exception.error, same(wrapped));
      expect(exception.error.code,
          equals(InsiderAppCardsErrorCode.invalidParameter));
      expect(exception.error.message, equals('bad arg'));
    });

    test('can be thrown and caught as InsiderAppCardsException', () {
      InsiderAppCardsException? caught;
      try {
        throw const InsiderAppCardsException(
          InsiderAppCardsError(
            code: InsiderAppCardsErrorCode.serverError,
            message: '500',
          ),
        );
      } on InsiderAppCardsException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught.error.code, equals(InsiderAppCardsErrorCode.serverError));
    });
  });
}
