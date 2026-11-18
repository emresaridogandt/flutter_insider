import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_insider/src/app_frames/insider_app_frames_error.dart';
import 'package:flutter_insider/src/app_frames/insider_app_frames_status.dart';
import 'package:flutter_insider/src/app_frames/insider_app_frames_view.dart';
import 'package:flutter_insider/src/constants.dart';

/// Stands in for the platform-views system channel so `AndroidView`/`UiKitView`
/// believe a native view was created, which is what makes the widget open its
/// per-view channel.
class _FakePlatformViews {
  final List<MethodCall> calls = <MethodCall>[];
  int _nextTextureId = 1;

  /// When true, `create` is rejected the way the engine rejects an unregistered
  /// view type.
  bool failCreate = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views,
            (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'create':
          if (failCreate) {
            throw PlatformException(
              code: 'error',
              message: 'Trying to create a platform view of unregistered type: '
                  '${Constants.APP_FRAMES_VIEW_TYPE}',
            );
          }
          return _nextTextureId++;
        default:
          return null;
      }
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  }

  /// The view id the widget's per-view channel is keyed on.
  int get lastViewId {
    final create = calls.lastWhere((c) => c.method == 'create');
    return (create.arguments as Map)['id'] as int;
  }
}

/// Sends a native -> Dart call on the per-view channel, the way the Android and
/// iOS bridges do.
Future<void> _emit(int viewId, String method, [Object? arguments]) {
  final channel =
      MethodChannel('${Constants.APP_FRAMES_CHANNEL_PREFIX}$viewId');
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(Constants.CHANNEL_NAME);

  late _FakePlatformViews platformViews;
  late List<MethodCall> capturedCalls;

  setUp(() {
    platformViews = _FakePlatformViews()..install();
    capturedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    platformViews.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// The exceptions the widget forwarded to Insider via `putException`.
  List<MethodCall> reportedExceptions() =>
      capturedCalls.where((c) => c.method == 'putException').toList();

  // The widget branches on the host platform; pin it so the tests exercise a
  // real platform-view path rather than the unsupported-platform fallback.
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  Future<void> pumpFrame(
    WidgetTester tester, {
    String placementId = 'home_page',
    double? height,
    bool collapseOnDismiss = true,
    ValueChanged<InsiderAppFramesError>? onLoadFailed,
    ValueChanged<double>? onHeightChanged,
    ValueChanged<Map<String, dynamic>>? onActionTriggered,
    void Function(
      InsiderAppFramesViewStatus status,
      InsiderAppFramesViewStatus previousStatus,
    )? onStatusChanged,
    VoidCallback? onDismissRequested,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InsiderAppFramesView(
            placementId: placementId,
            height: height,
            collapseOnDismiss: collapseOnDismiss,
            onStatusChanged: onStatusChanged,
            onLoadFailed: onLoadFailed,
            onHeightChanged: onHeightChanged,
            onDismissRequested: onDismissRequested,
            onActionTriggered: onActionTriggered,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double frameHeight(WidgetTester tester) =>
      tester.getSize(find.byType(InsiderAppFramesView)).height;

  // Every assertion below goes through `Constants`, so a typo in one of these
  // values would keep the suite green while silently breaking the contract the
  // Android and iOS bridges have to implement. Pin the literals themselves.
  group('wire contract', () {
    test('pins the channel and platform view names', () {
      expect(Constants.CHANNEL_NAME, equals('flutter_insider'));
      expect(
        Constants.APP_FRAMES_VIEW_TYPE,
        equals('com.useinsider.insider.flutter_insider/app_frames_view'),
      );
      expect(
        Constants.APP_FRAMES_CHANNEL_PREFIX,
        equals('flutter_insider_app_frames_'),
      );
    });

    test('pins the native -> Dart method names', () {
      expect(Constants.APP_FRAMES_ON_STATUS_CHANGED, equals('onStatusChanged'));
      expect(Constants.APP_FRAMES_ON_LOAD_FAILED, equals('onLoadFailed'));
      expect(
        Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED,
        equals('onHeightChangeRequested'),
      );
      expect(
        Constants.APP_FRAMES_ON_DISMISS_REQUESTED,
        equals('onDismissRequested'),
      );
      expect(
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        equals('onActionTriggered'),
      );
    });

    test('pins the payload argument keys', () {
      expect(Constants.APP_FRAMES_PLACEMENT_ID, equals('placementId'));
      expect(Constants.APP_FRAMES_HEIGHT, equals('height'));
      expect(Constants.APP_FRAMES_ACTION_DATA, equals('actionData'));
      expect(Constants.APP_FRAMES_ERROR_CODE, equals('code'));
      expect(Constants.APP_FRAMES_ERROR_MESSAGE, equals('message'));
      expect(Constants.APP_FRAMES_DISMISS_CODE, equals('dismissCode'));
      expect(Constants.APP_FRAMES_ERROR_CAUSE, equals('cause'));
      expect(Constants.APP_FRAMES_STATUS, equals('status'));
      expect(Constants.APP_FRAMES_PREVIOUS_STATUS, equals('previousStatus'));
    });

    test('pins the status wire vocabulary both bridges emit', () {
      // Pins the Dart side to itself: renaming a `Constants.APP_FRAMES_STATUS_*`
      // value without the matching enum member fails here. A rename on a NATIVE
      // bridge is NOT covered — no test in this repo reads a Java or
      // Objective-C string, and such a rename falls back to `unknown` at
      // runtime with nothing to catch it.
      expect(
        InsiderAppFramesViewStatus.values.map((s) => s.name).toList(),
        equals(kInsiderAppFramesStatusWireNames),
      );
    });

  });

  group('platform view creation', () {
    testWidgets('creates the platform view with the placement id', (t) async {
      await pumpFrame(t, placementId: 'checkout');

      final create =
          platformViews.calls.singleWhere((c) => c.method == 'create');
      final args = create.arguments as Map;
      expect(args['viewType'], equals(Constants.APP_FRAMES_VIEW_TYPE));

      final params = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(args['params'] as Uint8List),
      ) as Map;
      expect(params[Constants.APP_FRAMES_PLACEMENT_ID], equals('checkout'));
    }, variant: iOS);

    testWidgets(
        'holds a one pixel bootstrap height so the native view can subscribe',
        (t) async {
      await pumpFrame(t);

      // Effectively collapsed, but NOT zero: Flutter refuses to create a
      // platform view that lays out to zero size, so a real 0 would mean the
      // native view never attaches and never loads.
      expect(frameHeight(t), equals(1));
      expect(platformViews.calls.where((c) => c.method == 'create'), hasLength(1));
    }, variant: iOS);
  });

  group('height', () {
    testWidgets('grows when the template reports its optimal height',
        (t) async {
      final reported = <double>[];
      await pumpFrame(t, onHeightChanged: reported.add);
      expect(frameHeight(t), equals(1));

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 220.0});
      await t.pumpAndSettle();

      expect(frameHeight(t), equals(220));
      expect(reported, equals(<double>[220.0]));
    }, variant: iOS);

    testWidgets('an explicit height wins over the reported one', (t) async {
      final reported = <double>[];
      await pumpFrame(t, height: 100, onHeightChanged: reported.add);
      expect(frameHeight(t), equals(100));

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 220.0});
      await t.pumpAndSettle();

      // Still host-controlled, but the callback is delivered either way.
      expect(frameHeight(t), equals(100));
      expect(reported, equals(<double>[220.0]));
    }, variant: iOS);

    testWidgets('ignores a malformed height payload', (t) async {
      await pumpFrame(t);
      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 'tall'});
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(1));
    }, variant: iOS);
  });

  group('dismiss', () {
    testWidgets('collapses and tears the platform view down by default',
        (t) async {
      var dismissed = false;
      await pumpFrame(t, onDismissRequested: () => dismissed = true);

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 180.0});
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(180));

      await _emit(
          platformViews.lastViewId, Constants.APP_FRAMES_ON_DISMISS_REQUESTED);
      await t.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(frameHeight(t), equals(0));
      // Dropping the view detaches it from the window, which unsubscribes it.
      expect(platformViews.calls.any((c) => c.method == 'dispose'), isTrue);
    }, variant: iOS);

    testWidgets('keeps the frame when collapseOnDismiss is false', (t) async {
      var dismissed = false;
      await pumpFrame(t,
          collapseOnDismiss: false, onDismissRequested: () => dismissed = true);

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 180.0});
      await t.pumpAndSettle();

      await _emit(
          platformViews.lastViewId, Constants.APP_FRAMES_ON_DISMISS_REQUESTED);
      await t.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(frameHeight(t), equals(180));
    }, variant: iOS);

    testWidgets('flipping collapseOnDismiss to false does not restore the frame',
        (t) async {
      // The flag decides whether a dismissal collapses the frame at the moment
      // it arrives. Re-reading it on every build instead would let a host that
      // flips it afterwards rebuild the platform view from scratch — and hold
      // it at the height of a template that is gone.
      await pumpFrame(t);

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED,
          {Constants.APP_FRAMES_HEIGHT: 200.0});
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(200));

      await _emit(
          platformViews.lastViewId, Constants.APP_FRAMES_ON_DISMISS_REQUESTED);
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(0));

      final createsBeforeFlip =
          platformViews.calls.where((c) => c.method == 'create').length;

      await pumpFrame(t, collapseOnDismiss: false);

      expect(frameHeight(t), equals(0),
          reason: 'the dismissal is latched, not re-derived from the flag');
      expect(
        platformViews.calls.where((c) => c.method == 'create').length,
        equals(createsBeforeFlip),
        reason: 'no second native view is created for a dismissed frame',
      );
    }, variant: iOS);
  });

  group('status', () {
    testWidgets('forwards the new and previous status', (t) async {
      InsiderAppFramesViewStatus? status;
      InsiderAppFramesViewStatus? previous;
      await pumpFrame(t, onStatusChanged: (s, p) {
        status = s;
        previous = p;
      });

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      await t.pumpAndSettle();

      expect(status, equals(InsiderAppFramesViewStatus.ready));
      expect(previous, equals(InsiderAppFramesViewStatus.rendering));
    }, variant: iOS);

    testWidgets('falls back to unknown for an unrecognised status', (t) async {
      // A native SDK newer than the plugin may report a status this enum does
      // not know; losing the callback entirely would be worse than reporting
      // the idle state.
      InsiderAppFramesViewStatus? status;
      await pumpFrame(t, onStatusChanged: (s, _) => status = s);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: 'somethingBrandNew',
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_READY,
        },
      );
      await t.pumpAndSettle();

      expect(status, equals(InsiderAppFramesViewStatus.unknown));
    }, variant: iOS);

    test('pins the non-loading statuses so a new member must be classified', () {
      // NOT a collapse-behaviour test — `_contentGoneStatuses` is private and
      // the real coverage for it is the table-driven loop below. This is an
      // enum-membership tripwire: adding a status fails here, which is what
      // forces someone to decide whether it collapses.
      expect(
        InsiderAppFramesViewStatus.values
            .where((s) => !s.isLoading)
            .where((s) => s != InsiderAppFramesViewStatus.ready)
            .toSet(),
        equals(<InsiderAppFramesViewStatus>{
          InsiderAppFramesViewStatus.detached,
          InsiderAppFramesViewStatus.noPlacement,
          InsiderAppFramesViewStatus.disabled,
          InsiderAppFramesViewStatus.unavailable,
          InsiderAppFramesViewStatus.dismissed,
          InsiderAppFramesViewStatus.errorResolving,
          InsiderAppFramesViewStatus.errorDownloading,
          InsiderAppFramesViewStatus.errorRendering,
          InsiderAppFramesViewStatus.unknown,
        }),
      );
    });

    testWidgets('collapses when the frame loses its content', (t) async {
      // Both SDKs zero their own height in these states WITHOUT firing a height
      // callback. The widget drives the height itself, so a frame that reached
      // `ready` would otherwise keep the old content's height as an empty gap.
      for (final gone in <InsiderAppFramesViewStatus>[
        InsiderAppFramesViewStatus.noPlacement,
        InsiderAppFramesViewStatus.disabled,
        InsiderAppFramesViewStatus.unavailable,
        InsiderAppFramesViewStatus.dismissed,
        InsiderAppFramesViewStatus.errorResolving,
        InsiderAppFramesViewStatus.errorDownloading,
        InsiderAppFramesViewStatus.errorRendering,
        InsiderAppFramesViewStatus.unknown,
      ]) {
        await pumpFrame(t, collapseOnDismiss: false);
        await _emit(
          platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED,
          <String, dynamic>{Constants.APP_FRAMES_HEIGHT: 191.0},
        );
        await t.pumpAndSettle();
        expect(frameHeight(t), equals(191), reason: 'grew for $gone');

        await _emit(
          platformViews.lastViewId,
          Constants.APP_FRAMES_ON_STATUS_CHANGED,
          <String, dynamic>{
            Constants.APP_FRAMES_STATUS: gone.name,
            Constants.APP_FRAMES_PREVIOUS_STATUS:
                Constants.APP_FRAMES_STATUS_READY,
          },
        );
        await t.pumpAndSettle();
        // Back to the bootstrap sliver, not zero: the native view must stay
        // attached so it can grow again when fresh content arrives.
        expect(frameHeight(t), equals(1), reason: 'collapsed for $gone');
      }
    }, variant: iOS);

    testWidgets('keeps its height when the view merely detaches', (t) async {
      // `detached` means off-window, not content-gone — collapsing there would
      // make the frame flicker on the way back.
      await pumpFrame(t);
      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED,
        <String, dynamic>{Constants.APP_FRAMES_HEIGHT: 191.0},
      );
      await t.pumpAndSettle();

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_DETACHED,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_READY,
        },
      );
      await t.pumpAndSettle();

      expect(frameHeight(t), equals(191));
    }, variant: iOS);

    test('isLoading and isError group the phases', () {
      expect(InsiderAppFramesViewStatus.resolving.isLoading, isTrue);
      expect(InsiderAppFramesViewStatus.downloading.isLoading, isTrue);
      expect(InsiderAppFramesViewStatus.rendering.isLoading, isTrue);
      expect(InsiderAppFramesViewStatus.ready.isLoading, isFalse);

      expect(InsiderAppFramesViewStatus.errorResolving.isError, isTrue);
      expect(InsiderAppFramesViewStatus.errorDownloading.isError, isTrue);
      expect(InsiderAppFramesViewStatus.errorRendering.isError, isTrue);
      // Not an error: it means no campaign targets the placement.
      expect(InsiderAppFramesViewStatus.unavailable.isError, isFalse);
      expect(InsiderAppFramesViewStatus.disabled.isError, isFalse);
    });

    testWidgets('maps a failure payload onto the typed error', (t) async {
      InsiderAppFramesError? error;
      await pumpFrame(t, onLoadFailed: (e) => error = e);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_LOAD_FAILED,
        {
          Constants.APP_FRAMES_ERROR_CODE: 'resolutionFailed',
          Constants.APP_FRAMES_ERROR_MESSAGE:
              'No App Frame is available for this placement.',
        },
      );
      await t.pumpAndSettle();

      expect(error, isNotNull);
      expect(error!.code, equals(InsiderAppFramesErrorCode.resolutionFailed));
      expect(error!.dismissCode, isNull);
    }, variant: iOS);

    testWidgets('a failure does not collapse or throw', (t) async {
      await pumpFrame(t);
      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 90.0});
      await t.pumpAndSettle();

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_LOAD_FAILED,
          {Constants.APP_FRAMES_ERROR_CODE: 'contentDisplayFailed'});
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(frameHeight(t), equals(90));
    }, variant: iOS);
  });

  group('action', () {
    testWidgets('decodes the campaign-defined JSON payload', (t) async {
      Map<String, dynamic>? action;
      await pumpFrame(t, onActionTriggered: (a) => action = a);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        {
          Constants.APP_FRAMES_ACTION_DATA: jsonEncode({
            'coupon_code': 'ASDF1234',
            'nested': {'a': 1},
          }),
        },
      );
      await t.pumpAndSettle();

      expect(action, isNotNull);
      expect(action!['coupon_code'], equals('ASDF1234'));
      expect(action!['nested'], equals({'a': 1}));
    }, variant: iOS);

    testWidgets('swallows a malformed payload instead of crashing', (t) async {
      var called = false;
      await pumpFrame(t, onActionTriggered: (_) => called = true);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        {Constants.APP_FRAMES_ACTION_DATA: 'not json at all {'},
      );
      await t.pumpAndSettle();

      expect(called, isFalse);
      expect(t.takeException(), isNull);
      // The decode failure is SDK-side, so it goes to Insider.
      expect(reportedExceptions(), hasLength(1));
    }, variant: iOS);

    testWidgets('reports action data that is not a string', (t) async {
      var called = false;
      await pumpFrame(t, onActionTriggered: (_) => called = true);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        {
          Constants.APP_FRAMES_ACTION_DATA: <String, dynamic>{'coupon': 'X'},
        },
      );
      await t.pumpAndSettle();

      // A bridge sending the payload pre-decoded is a contract mismatch, not a
      // host bug: skipping the callback silently would leave nothing to
      // diagnose it by.
      expect(called, isFalse);
      expect(t.takeException(), isNull);
      expect(reportedExceptions(), hasLength(1));
    }, variant: iOS);

    testWidgets('reports JSON that does not decode to an object', (t) async {
      var called = false;
      await pumpFrame(t, onActionTriggered: (_) => called = true);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        {Constants.APP_FRAMES_ACTION_DATA: jsonEncode(<int>[1, 2, 3])},
      );
      await t.pumpAndSettle();

      expect(called, isFalse);
      expect(t.takeException(), isNull);
      expect(reportedExceptions(), hasLength(1));
    }, variant: iOS);

    testWidgets('stays silent when there is no action data', (t) async {
      var called = false;
      await pumpFrame(t, onActionTriggered: (_) => called = true);

      // An action need not carry a payload, so neither the callback nor an
      // error report is due.
      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_ACTION_TRIGGERED, const <String, dynamic>{});
      await t.pumpAndSettle();

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        {Constants.APP_FRAMES_ACTION_DATA: ''},
      );
      await t.pumpAndSettle();

      expect(called, isFalse);
      expect(t.takeException(), isNull);
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);
  });

  group('action data privacy', () {
    testWidgets('a payload that is not valid JSON is reported without its text',
        (t) async {
      // `jsonDecode`'s FormatException stringifies with the offending source
      // inline. Letting it reach `putException` would ship the raw campaign
      // payload — coupon codes, customer e-mail addresses — to Insider's error
      // backend, which is exactly what the report is documented not to carry.
      const secret = '{"coupon_code":"SECRET-ASDF1234",'
          '"email":"user@example.com"';

      await pumpFrame(t, placementId: 'checkout_banner');
      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        <String, dynamic>{Constants.APP_FRAMES_ACTION_DATA: secret},
      );
      await t.pumpAndSettle();

      final reports = reportedExceptions();
      expect(reports, hasLength(1));
      final reported =
          (reports.single.arguments as Map)['exception'] as String;

      expect(reported, isNot(contains('SECRET-ASDF1234')));
      expect(reported, isNot(contains('user@example.com')));
      expect(reported, isNot(contains('coupon_code')));
      // ...but it still says which placement and which argument broke.
      expect(reported, contains('checkout_banner'));
      expect(reported, contains(Constants.APP_FRAMES_ACTION_DATA));
    }, variant: iOS);

    testWidgets('a non-string payload is reported by shape, not by value',
        (t) async {
      // Every plugin surface funnels into one `putException` stream, so the
      // report has to name the placement or support cannot answer the only
      // question it is ever asked about one: which placement broke.
      await pumpFrame(t, placementId: 'cart_upsell');
      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        <String, dynamic>{
          Constants.APP_FRAMES_ACTION_DATA: <String, dynamic>{
            'coupon_code': 'SECRET-ASDF1234',
          },
        },
      );
      await t.pumpAndSettle();

      final reports = reportedExceptions();
      expect(reports, hasLength(1));
      final reported =
          (reports.single.arguments as Map)['exception'] as String;

      expect(reported, isNot(contains('SECRET-ASDF1234')));
      expect(reported, contains('cart_upsell'));
      expect(reported, contains(Constants.APP_FRAMES_ACTION_DATA));
    }, variant: iOS);
  });

  group('host callback failures', () {
    testWidgets(
        'a throwing host callback is reported to the host app, not to Insider',
        (t) async {
      await pumpFrame(
        t,
        onStatusChanged: (_, __) => throw StateError('bug in the host app'),
      );

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      await t.pumpAndSettle();

      // The host developer sees their own bug in their own console...
      expect(t.takeException(), isA<StateError>());
      // ...and Insider's error stream does not fill up with customer-code bugs.
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);

    testWidgets('the frame survives a throwing host callback', (t) async {
      await pumpFrame(
        t,
        onHeightChanged: (_) => throw StateError('bug in the host app'),
      );

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 140.0});
      await t.pumpAndSettle();

      expect(t.takeException(), isA<StateError>());
      // The height still applied: the callback failure is not the SDK's failure.
      expect(frameHeight(t), equals(140));
    }, variant: iOS);

    // The rule is one line of code per callback, so a refactor that replaced a
    // `_notifyHost(...)` with a direct call would send the host's own bug into
    // Insider's stream — the thing the split exists to prevent — with the suite
    // still green. Cover every callback, not a representative one.
    testWidgets('a throwing onLoadFailed does not reach Insider', (t) async {
      await pumpFrame(
        t,
        onLoadFailed: (_) => throw StateError('bug in the host app'),
      );

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_LOAD_FAILED,
        <String, dynamic>{
          Constants.APP_FRAMES_ERROR_CODE: 'renderingFailed',
          Constants.APP_FRAMES_ERROR_MESSAGE: 'boom',
        },
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isA<StateError>());
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);

    testWidgets('a throwing onDismissRequested does not reach Insider',
        (t) async {
      await pumpFrame(
        t,
        onDismissRequested: () => throw StateError('bug in the host app'),
      );

      await _emit(
          platformViews.lastViewId, Constants.APP_FRAMES_ON_DISMISS_REQUESTED);
      await t.pumpAndSettle();

      expect(t.takeException(), isA<StateError>());
      expect(reportedExceptions(), isEmpty);
      // The dismissal itself still took effect.
      expect(frameHeight(t), equals(0));
    }, variant: iOS);

    testWidgets('a throwing onActionTriggered does not reach Insider',
        (t) async {
      await pumpFrame(
        t,
        onActionTriggered: (_) => throw StateError('bug in the host app'),
      );

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_ACTION_TRIGGERED,
        <String, dynamic>{
          Constants.APP_FRAMES_ACTION_DATA: jsonEncode(<String, dynamic>{
            'deeplink': 'app://cart',
          }),
        },
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isA<StateError>());
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);
  });

  group('teardown', () {
    testWidgets('a disposed view removes its per-view channel handler',
        (t) async {
      // What this actually proves: `dispose` nulls the handler, so a later
      // native call on that view id reaches nothing. It does NOT isolate the
      // `!mounted` guards in `_notifyHost` / `_onPlatformViewCreated` — those
      // have no reachable path today and are defence only (see their comments).
      final statuses = <InsiderAppFramesViewStatus>[];
      await pumpFrame(t, onStatusChanged: (s, _) => statuses.add(s));
      final viewId = platformViews.lastViewId;

      await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await t.pumpAndSettle();

      await _emit(
        viewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      await t.pumpAndSettle();

      expect(statuses, isEmpty);
      expect(t.takeException(), isNull);
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);
  });

  // The Android branch takes a different embedding path from iOS
  // (`PlatformViewLink` + `initExpensiveAndroidView` rather than `UiKitView`),
  // so the assertions above say nothing about it.
  group('android embedding', () {
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('embeds with full hybrid composition', (t) async {
      await pumpFrame(t);

      final create =
          platformViews.calls.singleWhere((c) => c.method == 'create');
      final args = create.arguments as Map;

      // `hybrid: true` is what distinguishes `initExpensiveAndroidView` from
      // the texture-layer variants. It is load-bearing: the native view hosts a
      // WebView with a JavaScript bridge, and `initSurfaceAndroidView` would
      // start it as a texture and later re-host it, aborting with "The Android
      // view returned from PlatformView#getView() was already added to a parent
      // view."
      expect(args['hybrid'], isTrue);
      // The cheaper texture-layer path is negotiated by asking for a size up
      // front; hybrid composition never does.
      expect(args.containsKey('width'), isFalse);
      expect(args.containsKey('height'), isFalse);
    }, variant: android);

    testWidgets('creates the platform view with the placement id', (t) async {
      await pumpFrame(t, placementId: 'checkout');

      final create =
          platformViews.calls.singleWhere((c) => c.method == 'create');
      final args = create.arguments as Map;
      expect(args['viewType'], equals(Constants.APP_FRAMES_VIEW_TYPE));

      final params = const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(args['params'] as Uint8List),
      ) as Map;
      expect(params[Constants.APP_FRAMES_PLACEMENT_ID], equals('checkout'));
    }, variant: android);

    testWidgets('opens the per-view channel', (t) async {
      // On this path the widget has to register its own
      // `addOnPlatformViewCreatedListener` alongside the one `PlatformViewLink`
      // needs; if that were dropped the frame would render but stay deaf.
      var heard = false;
      await pumpFrame(t, onStatusChanged: (_, __) => heard = true);

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_RESOLVING,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_DETACHED,
        },
      );
      await t.pumpAndSettle();

      expect(heard, isTrue);
    }, variant: android);

    testWidgets('grows when the template reports its optimal height',
        (t) async {
      await pumpFrame(t);
      expect(frameHeight(t), equals(1));

      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 220.0});
      await t.pumpAndSettle();

      expect(frameHeight(t), equals(220));
    }, variant: android);

    testWidgets('tears the platform view down on dismiss', (t) async {
      await pumpFrame(t);

      await _emit(
          platformViews.lastViewId, Constants.APP_FRAMES_ON_DISMISS_REQUESTED);
      await t.pumpAndSettle();

      expect(frameHeight(t), equals(0));
      expect(platformViews.calls.any((c) => c.method == 'dispose'), isTrue);
    }, variant: android);

    testWidgets('rebuilds the native view when the placement changes',
        (t) async {
      await pumpFrame(t, placementId: 'a');
      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 150.0});
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(150));

      await pumpFrame(t, placementId: 'b');

      expect(
          platformViews.calls.where((c) => c.method == 'create'), hasLength(2));
      expect(frameHeight(t), equals(1));
    }, variant: android);

    testWidgets('collapses when the native view cannot be created', (t) async {
      // Nothing awaits `create()`, so before the failure was handled this
      // rejection reached the host app as an unhandled zone error — which is
      // exactly what a Dart-only release, or an old native SDK, would produce.
      platformViews.failCreate = true;

      await pumpFrame(t);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(frameHeight(t), equals(0));
      // Failing silently for the end user still means telling Insider.
      expect(reportedExceptions(), hasLength(1));
    }, variant: android);
  });

  group('unsupported platform', () {
    testWidgets('creates no native view and does not throw', (t) async {
      await pumpFrame(t);

      expect(platformViews.calls.where((c) => c.method == 'create'), isEmpty);
      expect(t.takeException(), isNull);
      // Takes up no space: the bootstrap pixel only exists to get a native view
      // created, so reserving it where there can be no native view is pointless.
      expect(frameHeight(t), equals(0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('placement changes', () {
    testWidgets('rebuilds the native view and resets the height', (t) async {
      await pumpFrame(t, placementId: 'a');
      await _emit(platformViews.lastViewId,
          Constants.APP_FRAMES_ON_HEIGHT_CHANGE_REQUESTED, {Constants.APP_FRAMES_HEIGHT: 150.0});
      await t.pumpAndSettle();
      expect(frameHeight(t), equals(150));

      await pumpFrame(t, placementId: 'b');

      // A second native view was created for the new placement...
      expect(
          platformViews.calls.where((c) => c.method == 'create'), hasLength(2));
      // ...and it starts collapsed rather than inheriting the old height, which
      // the native views never reset on their own.
      expect(frameHeight(t), equals(1));
    }, variant: iOS);
  });

  group('stale per-view channels', () {
    testWidgets(
        'a native call on the previous view id reaches no host callback',
        (t) async {
      // Changing the placement creates a SECOND native view, so the state holds
      // a new per-view channel. The one it overwrote must have had its handler
      // cleared on the way out: `dispose` only ever cleans up the latest, so a
      // handler left on the binary messenger for the old view id would keep
      // firing the host's callbacks — and hold the closures alive — with
      // nothing left to remove it.
      final statuses = <InsiderAppFramesViewStatus>[];
      await pumpFrame(
        t,
        placementId: 'a',
        onStatusChanged: (s, _) => statuses.add(s),
      );
      final firstViewId = platformViews.lastViewId;

      await pumpFrame(
        t,
        placementId: 'b',
        onStatusChanged: (s, _) => statuses.add(s),
      );
      expect(platformViews.lastViewId, isNot(equals(firstViewId)));

      await _emit(
        firstViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      await t.pumpAndSettle();

      expect(statuses, isEmpty);
    }, variant: iOS);

    testWidgets('a native call on the previous view id reports nothing',
        (t) async {
      await pumpFrame(t, placementId: 'a');
      final firstViewId = platformViews.lastViewId;

      await pumpFrame(t, placementId: 'b');

      await _emit(
        firstViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(reportedExceptions(), isEmpty);
    }, variant: iOS);
  });

  group('unexpected failures while handling a native call', () {
    testWidgets('the report names the placement and the method', (t) async {
      // A host app that installs a strict `FlutterError.onError` — rethrowing,
      // or a crash reporter that itself fails — turns `_notifyHost`'s own
      // reporting into a throw, which escapes past it into the generic catch.
      // Every plugin surface funnels into one `putException` stream, so a bare
      // exception string would land there unable to answer the only question
      // support is ever asked: which placement, and which callback.
      await pumpFrame(
        t,
        placementId: 'checkout_banner',
        onStatusChanged: (_, __) => throw StateError('bug in the host app'),
      );

      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = (FlutterErrorDetails details) {
        throw StateError('the host error reporter exploded');
      };

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      FlutterError.onError = originalOnError;
      await t.pumpAndSettle();

      final reports = reportedExceptions();
      expect(reports, hasLength(1));
      final reported =
          (reports.single.arguments as Map)['exception'] as String;

      expect(reported, contains('checkout_banner'));
      expect(reported, contains(Constants.APP_FRAMES_ON_STATUS_CHANGED));
    }, variant: iOS);

    testWidgets('the failure never reaches the host app as an exception',
        (t) async {
      await pumpFrame(
        t,
        placementId: 'checkout_banner',
        onStatusChanged: (_, __) => throw StateError('bug in the host app'),
      );

      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = (FlutterErrorDetails details) {
        throw StateError('the host error reporter exploded');
      };

      await _emit(
        platformViews.lastViewId,
        Constants.APP_FRAMES_ON_STATUS_CHANGED,
        <String, dynamic>{
          Constants.APP_FRAMES_STATUS: Constants.APP_FRAMES_STATUS_READY,
          Constants.APP_FRAMES_PREVIOUS_STATUS:
              Constants.APP_FRAMES_STATUS_RENDERING,
        },
      );
      FlutterError.onError = originalOnError;
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
    }, variant: iOS);
  });
}
