import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/app_frames/insider_app_frames_status.dart';

void main() {
  group('insiderAppFramesStatusFromWire non-string input', () {
    // A payload that carries the status as anything but a String must degrade
    // rather than throw: the throw would cost the host the whole status
    // callback. It degrades to `unknown`, never to `detached` — `detached` is
    // the one non-loading status the widget does NOT collapse on, so using it
    // as the catch-all would leave an unaccountable frame holding its last
    // height with `isError` reading false.
    test('falls back to unknown when the value is null', () {
      expect(
        insiderAppFramesStatusFromWire(null),
        equals(InsiderAppFramesViewStatus.unknown),
      );
    });

    test('falls back to unknown when the value is a number', () {
      expect(
        insiderAppFramesStatusFromWire(7),
        equals(InsiderAppFramesViewStatus.unknown),
      );
    });

    test('falls back to unknown when the value is a map', () {
      expect(
        insiderAppFramesStatusFromWire(<String, Object?>{'status': 'ready'}),
        equals(InsiderAppFramesViewStatus.unknown),
      );
    });
  });

  group('insiderAppFramesStatusFromWire known vocabulary', () {
    test('parses every wire string both bridges send', () {
      for (final status in InsiderAppFramesViewStatus.values) {
        expect(
          insiderAppFramesStatusFromWire(status.name),
          equals(status),
          reason: 'round-trip failed for ${status.name}',
        );
      }
    });

    test('parses the unknown both native SDKs emit for themselves', () {
      // Not a Dart-only invention: `InsiderAppFramesViewStatusStringValue` on
      // iOS and `mapAppFramesStatus` on Android both return this string for a
      // status they cannot represent, so it arrives over the wire verbatim.
      expect(
        insiderAppFramesStatusFromWire('unknown'),
        equals(InsiderAppFramesViewStatus.unknown),
      );
    });

    test('an unrecognised string is unknown, not detached', () {
      expect(
        insiderAppFramesStatusFromWire('somethingBrandNew'),
        equals(InsiderAppFramesViewStatus.unknown),
      );
    });
  });
}
