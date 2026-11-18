import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/app_frames/insider_app_frames_error.dart';
import 'package:flutter_insider/src/constants.dart';

void main() {
  group('InsiderAppFramesErrorCode enum', () {
    test('exposes the documented set of values', () {
      expect(InsiderAppFramesErrorCode.values, hasLength(7));
      expect(
        InsiderAppFramesErrorCode.values.toSet(),
        equals(<InsiderAppFramesErrorCode>{
          InsiderAppFramesErrorCode.unknown,
          InsiderAppFramesErrorCode.resolutionFailed,
          InsiderAppFramesErrorCode.responseMalformed,
          InsiderAppFramesErrorCode.downloadingFailed,
          InsiderAppFramesErrorCode.placementUntrusted,
          InsiderAppFramesErrorCode.contentDisplayFailed,
          InsiderAppFramesErrorCode.renderingFailed,
        }),
      );
    });

    test('each value name uses the camelCase wire contract', () {
      final names = InsiderAppFramesErrorCode.values.map((e) => e.name).toList();
      expect(
        names,
        containsAll(<String>[
          'unknown',
          'resolutionFailed',
          'responseMalformed',
          'downloadingFailed',
          'placementUntrusted',
          'contentDisplayFailed',
          'renderingFailed',
        ]),
      );
    });
  });

  group('InsiderAppFramesError.fromMap', () {
    test('maps every known code string to its enum value', () {
      const cases = <String, InsiderAppFramesErrorCode>{
        'unknown': InsiderAppFramesErrorCode.unknown,
        'resolutionFailed': InsiderAppFramesErrorCode.resolutionFailed,
        'responseMalformed': InsiderAppFramesErrorCode.responseMalformed,
        'downloadingFailed': InsiderAppFramesErrorCode.downloadingFailed,
        'placementUntrusted': InsiderAppFramesErrorCode.placementUntrusted,
        'contentDisplayFailed': InsiderAppFramesErrorCode.contentDisplayFailed,
        'renderingFailed': InsiderAppFramesErrorCode.renderingFailed,
      };

      cases.forEach((wireCode, expected) {
        final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
          Constants.APP_FRAMES_ERROR_CODE: wireCode,
          Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        });
        expect(error.code, equals(expected), reason: 'for wire code $wireCode');
      });
    });

    test('falls back to unknown for an unrecognised code', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'somethingBrandNew',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
      });
      expect(error.code, equals(InsiderAppFramesErrorCode.unknown));
    });

    test('code matching is case sensitive', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'HtmlLoadFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
      });
      expect(error.code, equals(InsiderAppFramesErrorCode.unknown));
    });

    test('applies defaults when fields are missing', () {
      final error = InsiderAppFramesError.fromMap(const <dynamic, dynamic>{});
      expect(error.code, equals(InsiderAppFramesErrorCode.unknown));
      expect(error.message, equals('An unexpected error occurred.'));
      expect(error.dismissCode, isNull);
    });

    test('falls back instead of throwing when code is not a string', () {
      // A cast here would throw, and the throw would cost the host its
      // onLoadFailed callback — the only place it learns the frame failed.
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 404,
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
      });
      expect(error.code, equals(InsiderAppFramesErrorCode.unknown));
      expect(error.message, equals('msg'));
    });

    test('falls back instead of throwing when message is not a string', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'contentDisplayFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: <String, String>{'nested': 'msg'},
      });
      expect(error.code, equals(InsiderAppFramesErrorCode.contentDisplayFailed));
      expect(error.message, equals('An unexpected error occurred.'));
    });

    test('reads dismissCode when the native side sends one', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'renderingFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'The App Frame template reported an error dismissal.',
        Constants.APP_FRAMES_DISMISS_CODE: 96,
      });
      expect(error.code, equals(InsiderAppFramesErrorCode.renderingFailed));
      expect(error.dismissCode, equals(96));
    });

    test('reads a non-integral dismissCode as an int', () {
      // A native side may send the dismiss code as a floating-point number.
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'renderingFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_DISMISS_CODE: 96.0,
      });
      expect(error.dismissCode, equals(96));
    });

    test('truncates a fractional dismissCode towards zero', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'renderingFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_DISMISS_CODE: 96.7,
      });
      expect(error.dismissCode, equals(96));
    });

    test('leaves dismissCode null when the key is absent or not a number', () {
      final absent = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'contentDisplayFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
      });
      expect(absent.dismissCode, isNull);

      final wrongType = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'contentDisplayFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_DISMISS_CODE: 'twelve',
      });
      expect(wrongType.dismissCode, isNull);
    });

    test('reads the underlying cause when the native side sends one', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'resolutionFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_ERROR_CAUSE: 'SocketTimeoutException: timeout',
      });
      expect(error.cause, equals('SocketTimeoutException: timeout'));
    });

    test('leaves cause null when the key is absent', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'resolutionFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
      });
      expect(error.cause, isNull);
    });

    test('treats an empty cause as no cause', () {
      // An empty string would read as a cause that exists but says nothing.
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'resolutionFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_ERROR_CAUSE: '',
      });
      expect(error.cause, isNull);
    });

    test('falls back instead of throwing when cause is not a string', () {
      final error = InsiderAppFramesError.fromMap(<dynamic, dynamic>{
        Constants.APP_FRAMES_ERROR_CODE: 'resolutionFailed',
        Constants.APP_FRAMES_ERROR_MESSAGE: 'msg',
        Constants.APP_FRAMES_ERROR_CAUSE: <String, String>{'nested': 'boom'},
      });
      expect(error.cause, isNull);
      expect(error.message, equals('msg'));
    });
  });

  group('InsiderAppFramesError.toString', () {
    test('omits dismissCode when there is none', () {
      const error = InsiderAppFramesError(
        code: InsiderAppFramesErrorCode.contentDisplayFailed,
        message: 'Failed to load App Frame content.',
      );
      expect(
        error.toString(),
        equals(
          'InsiderAppFramesError(code: InsiderAppFramesErrorCode.contentDisplayFailed, '
          'message: Failed to load App Frame content.)',
        ),
      );
    });

    test('includes dismissCode when present', () {
      const error = InsiderAppFramesError(
        code: InsiderAppFramesErrorCode.renderingFailed,
        message: 'reported',
        dismissCode: 96,
      );
      expect(error.toString(), contains('dismissCode: 96'));
    });

    test('omits cause when there is none', () {
      const error = InsiderAppFramesError(
        code: InsiderAppFramesErrorCode.contentDisplayFailed,
        message: 'msg',
      );
      expect(error.toString(), isNot(contains('cause')));
    });

    test('includes cause when present', () {
      const error = InsiderAppFramesError(
        code: InsiderAppFramesErrorCode.resolutionFailed,
        message: 'msg',
        cause: 'SocketTimeoutException: timeout',
      );
      expect(
        error.toString(),
        equals(
          'InsiderAppFramesError(code: '
          'InsiderAppFramesErrorCode.resolutionFailed, message: msg, '
          'cause: SocketTimeoutException: timeout)',
        ),
      );
    });

    test('renders dismissCode before cause when both are present', () {
      const error = InsiderAppFramesError(
        code: InsiderAppFramesErrorCode.renderingFailed,
        message: 'msg',
        dismissCode: 96,
        cause: 'template said no',
      );
      expect(
        error.toString(),
        equals(
          'InsiderAppFramesError(code: '
          'InsiderAppFramesErrorCode.renderingFailed, message: msg, '
          'dismissCode: 96, cause: template said no)',
        ),
      );
    });
  });
}
