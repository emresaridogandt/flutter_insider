import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/src/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('flutter_insider');
  const EventChannel eventChannel = EventChannel('insider_event_listener');
  const StandardMethodCodec codec = StandardMethodCodec();

  final FlutterInsiderEvents events = FlutterInsiderEvents(methodChannel);

  late List<MethodCall> capturedCalls;
  late MockStreamHandler streamHandler;
  late List<MethodCall> streamLifecycle;

  /// Every subscription created by a test, drained in tearDown.
  ///
  /// `FlutterInsiderEvents` tracks its live listener count in a static field
  /// (the native observer is process-global), so a subscription left dangling
  /// by one test would leak into the next one's count.
  late List<InsiderEventSubscription> openSubscriptions;

  Future<InsiderEventSubscription> register(
    void Function(InsiderRecordedEvent) callback,
  ) async {
    final subscription = await events.addObserver(callback);
    openSubscriptions.add(subscription);
    return subscription;
  }

  /// Emits a payload to every active subscriber of the event channel, going
  /// through the real StandardMethodCodec so encoding is exercised too.
  Future<void> emit(Object? payload) async {
    await TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'insider_event_listener',
      codec.encodeSuccessEnvelope(payload),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Map<String, dynamic> payloadOf({
    String name = 'purchase',
    Map<String, dynamic>? parameters,
    int timestamp = 1700000000,
  }) {
    return <String, dynamic>{
      'name': name,
      'parameters': parameters ?? <String, dynamic>{},
      'timestamp': timestamp,
    };
  }

  setUp(() {
    capturedCalls = <MethodCall>[];
    streamLifecycle = <MethodCall>[];
    openSubscriptions = <InsiderEventSubscription>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      capturedCalls.add(call);
      return null;
    });

    streamHandler = MockStreamHandler.inline(
      onListen: (Object? arguments, MockStreamHandlerEventSink events) {
        streamLifecycle.add(const MethodCall('listen'));
      },
      onCancel: (Object? arguments) {
        streamLifecycle.add(const MethodCall('cancel'));
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, streamHandler);
  });

  tearDown(() async {
    // Drain any subscription the test left open so the static listener count
    // returns to zero before the next test runs.
    for (final subscription in openSubscriptions) {
      await subscription.cancel();
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('events.addObserver', () {
    test('invokes registerEventListener on the method channel', () async {
      final subscription =
          await register((_) {});

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method, equals(Constants.REGISTER_EVENT_LISTENER));

      await subscription.cancel();
    });

    test('subscribes to the stream before invoking the method channel',
        () async {
      // Guarantees onListen installed the sink before native starts emitting.
      final subscription =
          await register((_) {});

      expect(streamLifecycle, isNotEmpty);
      expect(streamLifecycle.first.method, equals('listen'));

      await subscription.cancel();
    });

    test('delivers a recorded event to the callback', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(name: 'add_to_cart'));

      expect(received, hasLength(1));
      expect(received.single.name, equals('add_to_cart'));

      await subscription.cancel();
    });

    test('exposes name, parameters and timestamp from the payload', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(
        name: 'purchase',
        parameters: <String, dynamic>{'currency': 'USD', 'total': 42.5},
        timestamp: 1700000000,
      ));

      final event = received.single;
      expect(event.name, equals('purchase'));
      expect(event.parameters['currency'], equals('USD'));
      expect(event.parameters['total'], equals(42.5));
      expect(event.timestamp, equals(1700000000));

      await subscription.cancel();
    });

    test('passes the timestamp through unchanged, in seconds', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(timestamp: 1700000000));

      // Deliberately NOT rescaled to milliseconds - parity with native.
      expect(received.single.timestamp, equals(1700000000));

      await subscription.cancel();
    });

    test('recordedAt converts the seconds timestamp to a DateTime', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(timestamp: 1700000000));

      expect(
        received.single.recordedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)),
      );

      await subscription.cancel();
    });

    test('preserves nested parameter types through the codec', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(parameters: <String, dynamic>{
        'tags': <String>['a', 'b'],
        'scores': <num>[1, 2.5],
        'nested': <String, dynamic>{'flag': true, 'count': 3},
        'plain': 'value',
      }));

      final parameters = received.single.parameters;
      expect(parameters['tags'], equals(<String>['a', 'b']));
      expect(parameters['scores'], equals(<num>[1, 2.5]));
      expect(parameters['plain'], equals('value'));

      final nested = Map<String, dynamic>.from(parameters['nested'] as Map);
      expect(nested['flag'], isTrue);
      expect(nested['count'], equals(3));

      await subscription.cancel();
    });

    test('tolerates an empty parameters map', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(parameters: <String, dynamic>{}));

      expect(received.single.parameters, isEmpty);

      await subscription.cancel();
    });

    test('ignores malformed payloads without breaking the subscription',
        () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit('not-a-map');
      await emit(<String, dynamic>{'name': 'missing_timestamp'});
      await emit(payloadOf(name: 'good_event'));

      expect(received, hasLength(1));
      expect(received.single.name, equals('good_event'));

      await subscription.cancel();
    });

    test('delivers every event to multiple independent listeners', () async {
      final first = <InsiderRecordedEvent>[];
      final second = <InsiderRecordedEvent>[];

      final firstSubscription =
          await register(first.add);
      final secondSubscription =
          await register(second.add);

      await emit(payloadOf(name: 'shared_event'));

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(first.single.name, equals('shared_event'));
      expect(second.single.name, equals('shared_event'));

      await firstSubscription.cancel();
      await secondSubscription.cancel();
    });
  });

  group('InsiderEventSubscription.cancel', () {
    test('stops delivering events to the cancelled listener', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(name: 'before_cancel'));
      await subscription.cancel();
      await emit(payloadOf(name: 'after_cancel'));

      expect(received, hasLength(1));
      expect(received.single.name, equals('before_cancel'));
    });

    test('unregisters natively when the last listener is cancelled', () async {
      final subscription =
          await register((_) {});
      capturedCalls.clear();

      await subscription.cancel();

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method, equals(Constants.UNREGISTER_EVENT_LISTENER));
    });

    test('does not unregister while another listener is still active',
        () async {
      final firstSubscription =
          await register((_) {});
      final secondSubscription =
          await register((_) {});
      capturedCalls.clear();

      await firstSubscription.cancel();

      expect(
        capturedCalls.where((c) => c.method == Constants.UNREGISTER_EVENT_LISTENER),
        isEmpty,
        reason: 'a listener is still active',
      );

      await secondSubscription.cancel();

      expect(
        capturedCalls.where((c) => c.method == Constants.UNREGISTER_EVENT_LISTENER),
        hasLength(1),
        reason: 'the last listener went away',
      );
    });

    test('is idempotent', () async {
      final subscription =
          await register((_) {});
      capturedCalls.clear();

      await subscription.cancel();
      await subscription.cancel();

      expect(subscription.isCancelled, isTrue);
      expect(
        capturedCalls.where((c) => c.method == Constants.UNREGISTER_EVENT_LISTENER),
        hasLength(1),
      );
    });

    test('shares one native registration across separate instances',
        () async {
      final otherEvents = FlutterInsiderEvents(methodChannel);
      final received = <InsiderRecordedEvent>[];
      final firstSubscription = await register(received.add);
      final secondSubscription = await otherEvents.addObserver((_) {});
      openSubscriptions.add(secondSubscription);
      capturedCalls.clear();

      await secondSubscription.cancel();
      await emit(payloadOf(name: 'after_other_instance_cancel'));

      expect(
        capturedCalls.where((c) => c.method == Constants.UNREGISTER_EVENT_LISTENER),
        isEmpty,
        reason: 'the first instance still has a live listener',
      );
      expect(received.single.name, equals('after_other_instance_cancel'));

      await firstSubscription.cancel();

      expect(
        capturedCalls.where((c) => c.method == Constants.UNREGISTER_EVENT_LISTENER),
        hasLength(1),
      );
    });
  });

  group('InsiderRecordedEvent.fromPlatform', () {
    test('returns null for a non-map payload', () {
      expect(InsiderRecordedEvent.fromPlatform('nope'), isNull);
    });

    test('returns null when the timestamp is not an int', () {
      expect(
        InsiderRecordedEvent.fromPlatform(<String, dynamic>{
          'name': 'x',
          'parameters': <String, dynamic>{},
          'timestamp': 'not-an-int',
        }),
        isNull,
      );
    });

    test('coerces non-string parameter keys to strings', () {
      final event = InsiderRecordedEvent.fromPlatform(<Object?, Object?>{
        'name': 'x',
        'parameters': <Object?, Object?>{1: 'one'},
        'timestamp': 5,
      });

      expect(event, isNotNull);
      expect(event!.parameters['1'], equals('one'));
    });

    test('drops a parameter with a null key and keeps the other entries', () {
      final event = InsiderRecordedEvent.fromPlatform(<Object?, Object?>{
        'name': 'x',
        'parameters': <Object?, Object?>{null: 'dropped', 'kept': 'value'},
        'timestamp': 5,
      });

      expect(event, isNotNull);
      expect(event!.parameters, equals(<String, dynamic>{'kept': 'value'}));
    });

    test('toString lists name, parameters and timestamp', () {
      final event = InsiderRecordedEvent.fromPlatform(<Object?, Object?>{
        'name': 'purchase',
        'parameters': <Object?, Object?>{'currency': 'USD'},
        'timestamp': 1700000000,
      });

      expect(
        event.toString(),
        equals('InsiderRecordedEvent(name: purchase, '
            'parameters: {currency: USD}, timestamp: 1700000000)'),
      );
    });
  });

  group('date parameters', () {
    // Neither native bridge converts dates: `addParameterWithDate` already
    // stores a formatted date String in both SDKs (Android
    // `StaticUtils.formatDate`, iOS an RFC-format NSString), so no native date
    // object reaches the encoder and the value reaches Dart as a `String`.
    //
    // The top-level `timestamp` is unrelated: it stays in whole SECONDS.
    test('arrive as the formatted String the native SDK recorded', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(
        parameters: <String, dynamic>{'signup_date': '2023-11-14T22:13:20Z'},
        timestamp: 1700000000,
      ));

      final event = received.single;

      expect(event.parameters['signup_date'], isA<String>());
      expect(event.parameters['signup_date'], equals('2023-11-14T22:13:20Z'));

      await subscription.cancel();
    });

    test('are not epoch numbers, so casting one to int throws', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(
        parameters: <String, dynamic>{'signup_date': '2023-11-14T22:13:20Z'},
      ));

      final parameters = received.single.parameters;

      expect(() => parameters['signup_date'] as int, throwsA(isA<TypeError>()));

      await subscription.cancel();
    });

    test('stay Strings inside nested maps and lists', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(parameters: <String, dynamic>{
        'profile': <String, dynamic>{'last_seen': '2023-11-14T22:13:20Z'},
        'milestones': <String>['2020-09-13T12:26:40Z', '2023-11-14T22:13:20Z'],
      }));

      final parameters = received.single.parameters;

      final profile = Map<String, dynamic>.from(parameters['profile'] as Map);
      expect(profile['last_seen'], equals('2023-11-14T22:13:20Z'));
      expect(parameters['milestones'],
          equals(<String>['2020-09-13T12:26:40Z', '2023-11-14T22:13:20Z']));

      await subscription.cancel();
    });

    test('an unsupported value degrades to a string without dropping the event',
        () async {
      // The native encoders fall back to a string description for types the
      // codec cannot represent, so one bad value cannot fail encoding and take
      // the entire event with it.
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await emit(payloadOf(
        name: 'purchase',
        parameters: <String, dynamic>{
          'currency': 'USD',
          'opaque': '<InsiderUnsupportedType>',
        },
      ));

      final event = received.single;
      expect(event.name, equals('purchase'));
      expect(event.parameters['currency'], equals('USD'));
      expect(event.parameters['opaque'], equals('<InsiderUnsupportedType>'));

      await subscription.cancel();
    });
  });

  group('forwarding to a third-party analytics SDK', () {
    // Mirrors the dartdoc example on events.addObserver: analytics SDKs
    // expect epoch MILLISECONDS, while `timestamp` is in seconds.
    test('the documented conversion yields milliseconds for the analytics SDK',
        () async {
      final forwarded = <Map<String, Object>>[];
      final names = <String>[];

      final subscription = await register((event) {
        final millis = event.timestamp * 1000;

        names.add(event.name);
        forwarded.add(<String, Object>{
          for (final entry in event.parameters.entries)
            if (entry.value is String ||
                entry.value is num ||
                entry.value is bool)
              entry.key: entry.value as Object,
          'insider_recorded_at_ms': millis,
        });
      });

      await emit(payloadOf(
        name: 'purchase',
        parameters: <String, dynamic>{
          'currency': 'USD',
          'total': 42.5,
          'is_first': true,
          // Nested values are dropped by the documented flattening, since most
          // analytics SDKs only accept flat primitive property maps.
          'items': <String>['sku-1', 'sku-2'],
        },
        timestamp: 1700000000,
      ));

      expect(names, equals(<String>['purchase']));

      final properties = forwarded.single;
      expect(properties['insider_recorded_at_ms'], equals(1700000000000));
      expect(properties['currency'], equals('USD'));
      expect(properties['total'], equals(42.5));
      expect(properties['is_first'], isTrue);
      expect(properties.containsKey('items'), isFalse);

      // The same instant the SDK would receive via recordedAt.
      expect(
        properties['insider_recorded_at_ms'],
        equals(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)
            .millisecondsSinceEpoch),
      );

      await subscription.cancel();
    });
  });

  group('registration failure', () {
    /// Makes the next `registerEventListener` method-channel call throw, so
    /// the Dart side sees what a native `addObserver` failure looks like.
    void failRegistration() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        capturedCalls.add(call);

        if (call.method == Constants.REGISTER_EVENT_LISTENER) {
          throw PlatformException(code: 'ERROR', message: 'addObserver failed');
        }

        return null;
      });
    }

    test('throws instead of returning a subscription that cannot deliver',
        () async {
      failRegistration();

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );
    });

    test('rolls the stream back so the platform subscription is released',
        () async {
      failRegistration();

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );

      // onListen ran when we subscribed; onCancel must follow, otherwise the
      // platform stream stays open behind a listener the caller never got.
      expect(
        streamLifecycle.map((c) => c.method),
        equals(<String>['listen', 'cancel']),
      );
    });

    test('a later call retries rather than being blocked by the failed one',
        () async {
      failRegistration();

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );

      // Restore a healthy channel — the retry must reach native again.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        capturedCalls.add(call);
        return null;
      });

      final subscription = await register((_) {});

      expect(
        capturedCalls
            .where((c) => c.method == Constants.REGISTER_EVENT_LISTENER)
            .length,
        equals(2),
        reason: 'the failed attempt must not leave the bridge thinking it is '
            'already registered',
      );
      expect(subscription.isCancelled, isFalse);
    });
  });

  group('event immutability', () {
    test('parameters cannot be mutated by a listener', () {
      final event = InsiderRecordedEvent.fromPlatform(<dynamic, dynamic>{
        'name': 'purchase',
        'parameters': <dynamic, dynamic>{'currency': 'USD'},
        'timestamp': 1700000000,
      })!;

      // The same instance is fanned out to every listener, so a write here
      // would change what the next one sees.
      expect(
        () => event.parameters['currency'] = 'EUR',
        throwsUnsupportedError,
      );
      expect(event.parameters['currency'], equals('USD'));
    });

    test('does not mutate the payload the platform handed us', () {
      final rawParameters = <dynamic, dynamic>{'currency': 'USD'};

      final event = InsiderRecordedEvent.fromPlatform(<dynamic, dynamic>{
        'name': 'purchase',
        'parameters': rawParameters,
        'timestamp': 1700000000,
      })!;

      expect(() => event.parameters['added'] = 1, throwsUnsupportedError);
      expect(rawParameters.containsKey('added'), isFalse);
    });
  });

  group('wire method names', () {
    // The native sides switch on these literals — FlutterInsiderPlugin.java
    // and FlutterInsiderPlugin.m match the strings, not the constants — so the
    // value itself is the contract and is pinned here as well as the name.
    test('registerEventListener is the literal the native sides match', () {
      expect(
        Constants.REGISTER_EVENT_LISTENER,
        equals('registerEventListener'),
      );
    });

    test('unregisterEventListener is the literal the native sides match', () {
      expect(
        Constants.UNREGISTER_EVENT_LISTENER,
        equals('unregisterEventListener'),
      );
    });
  });

  group('error reporting and stream lifecycle', () {
    /// Makes every call to [failingMethod] on the method channel throw a
    /// PlatformException, while still recording it in `capturedCalls`.
    void failMethod(String failingMethod) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        capturedCalls.add(call);

        if (call.method == failingMethod) {
          throw PlatformException(code: 'ERROR', message: 'native failed');
        }

        return null;
      });
    }

    test('a failed registration reports the error through putException',
        () async {
      failMethod(Constants.REGISTER_EVENT_LISTENER);

      Object? thrown;
      try {
        await events.addObserver((_) {});
      } catch (error) {
        thrown = error;
      }
      await Future<void>.delayed(Duration.zero);

      expect(thrown, isA<PlatformException>());
      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.REGISTER_EVENT_LISTENER, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(capturedCalls.last.arguments as Map),
        equals(<String, dynamic>{'exception': thrown.toString()}),
      );
    });

    test('cancel completes without rethrowing when unregister fails',
        () async {
      final subscription = await register((_) {});
      failMethod(Constants.UNREGISTER_EVENT_LISTENER);

      await expectLater(subscription.cancel(), completes);
    });

    test('cancel reports an unregister failure through putException',
        () async {
      final subscription = await register((_) {});
      failMethod(Constants.UNREGISTER_EVENT_LISTENER);
      capturedCalls.clear();

      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.UNREGISTER_EVENT_LISTENER, 'putException']),
      );
      expect(
        Map<String, dynamic>.from(capturedCalls.last.arguments as Map),
        equals(<String, dynamic>{
          'exception': PlatformException(code: 'ERROR', message: 'native failed')
              .toString(),
        }),
      );
    });

    test('cancel still closes the platform stream when unregister fails',
        () async {
      final subscription = await register((_) {});
      failMethod(Constants.UNREGISTER_EVENT_LISTENER);
      streamLifecycle.clear();

      await subscription.cancel();

      expect(streamLifecycle.map((c) => c.method), equals(<String>['cancel']));
    });

    test('a platform stream error is reported through putException', () async {
      final subscription = await register((_) {});
      capturedCalls.clear();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'insider_event_listener',
        codec.encodeErrorEnvelope(code: 'STREAM_ERROR', message: 'boom'),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method, equals('putException'));
      expect(
        Map<String, dynamic>.from(capturedCalls.single.arguments as Map),
        equals(<String, dynamic>{
          'exception':
              PlatformException(code: 'STREAM_ERROR', message: 'boom').toString(),
        }),
      );

      await subscription.cancel();
    });

    test('a platform stream error is not delivered to the callback', () async {
      final received = <InsiderRecordedEvent>[];
      final subscription = await register(received.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'insider_event_listener',
        codec.encodeErrorEnvelope(code: 'STREAM_ERROR', message: 'boom'),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);

      await subscription.cancel();
    });

    test(
        'addObserver started while the last cancel is closing the stream '
        'gets a fresh stream and receives events', () async {
      final first = await register((_) {});

      final received = <InsiderRecordedEvent>[];
      Future<InsiderEventSubscription>? pendingObserver;

      // Re-install the stream handler so a new addObserver starts from inside
      // the platform cancel — i.e. while _closeEventStream is still awaiting
      // the old subscription's cancel.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
            streamLifecycle.add(const MethodCall('listen'));
          },
          onCancel: (Object? arguments) {
            streamLifecycle.add(const MethodCall('cancel'));
            pendingObserver ??= events.addObserver(received.add);
          },
        ),
      );

      await first.cancel();
      expect(pendingObserver, isNotNull);

      final second = await pendingObserver!;
      openSubscriptions.add(second);

      await emit(payloadOf(name: 'after_race'));

      expect(received, hasLength(1));
      expect(received.single.name, equals('after_race'));
    });

    test(
        'a failed registration with a live listener keeps delivering events '
        'to that listener', () async {
      final received = <InsiderRecordedEvent>[];
      await register(received.add);
      failMethod(Constants.REGISTER_EVENT_LISTENER);

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );

      await emit(payloadOf(name: 'still_live'));

      expect(received, hasLength(1));
      expect(received.single.name, equals('still_live'));
    });

    test(
        'a failed registration with a live listener does not churn the '
        'platform stream', () async {
      await register((_) {});
      failMethod(Constants.REGISTER_EVENT_LISTENER);
      streamLifecycle.clear();

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );

      expect(streamLifecycle, isEmpty);
    });

    test(
        'a failed registration with a live listener leaves one listener '
        'counted, so the next cancel unregisters', () async {
      final live = await register((_) {});
      failMethod(Constants.REGISTER_EVENT_LISTENER);

      await expectLater(
        events.addObserver((_) {}),
        throwsA(isA<PlatformException>()),
      );
      capturedCalls.clear();

      await live.cancel();

      expect(
        capturedCalls.map((c) => c.method),
        equals(<String>[Constants.UNREGISTER_EVENT_LISTENER]),
      );
    });
  });

  group('InsiderRecordedEvent.fromPlatform guards and defaults', () {
    test('returns null when the name is missing', () {
      expect(
        InsiderRecordedEvent.fromPlatform(<String, dynamic>{
          'parameters': <String, dynamic>{},
          'timestamp': 5,
        }),
        isNull,
      );
    });

    test('returns null when the name is not a String', () {
      expect(
        InsiderRecordedEvent.fromPlatform(<String, dynamic>{
          'name': 42,
          'parameters': <String, dynamic>{},
          'timestamp': 5,
        }),
        isNull,
      );
    });

    test('defaults missing parameters to an empty map', () {
      final event = InsiderRecordedEvent.fromPlatform(<String, dynamic>{
        'name': 'x',
        'timestamp': 5,
      });

      expect(event, isNotNull);
      expect(event!.parameters, isEmpty);
    });

    test('defaults non-Map parameters to an empty map', () {
      final event = InsiderRecordedEvent.fromPlatform(<String, dynamic>{
        'name': 'x',
        'parameters': 'not-a-map',
        'timestamp': 5,
      });

      expect(event, isNotNull);
      expect(event!.parameters, isEmpty);
    });

    test('the defaulted parameters map is unmodifiable', () {
      final event = InsiderRecordedEvent.fromPlatform(<String, dynamic>{
        'name': 'x',
        'timestamp': 5,
      })!;

      expect(() => event.parameters['added'] = 1, throwsUnsupportedError);
    });
  });
}
