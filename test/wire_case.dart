import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ActionFn = Future<Object?> Function();
typedef ResultExpect = void Function(Object? result);

/// One row in a wire-protocol table test.
///
/// Each [WireCase] declares an [action] (a closure that exercises a single
/// public method) and the [wireMethod] / [wireArgs] that the action is
/// expected to push through the [MethodChannel].
class WireCase {
  final String name;
  final ActionFn action;
  final String wireMethod;
  final Object? wireArgs;
  final Object? handlerReturn;
  final ResultExpect? expectResult;

  WireCase({
    required this.name,
    required this.action,
    required this.wireMethod,
    this.wireArgs,
    this.handlerReturn,
    this.expectResult,
  });
}

/// Registers `setUp`/`tearDown` for the given [channel] and emits one
/// [test] per [WireCase], asserting:
///   1. exactly one MethodCall captured
///   2. method name equals `c.wireMethod`
///   3. arguments equal `c.wireArgs`
///   4. (optional) action's return value matches `c.expectResult`
///
/// Must be called from within a `group` or directly inside `main`.
void registerWireCases(List<WireCase> cases, MethodChannel channel) {
  final capturedCalls = <MethodCall>[];
  Object? pendingReturn;

  setUp(() {
    capturedCalls.clear();
    pendingReturn = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedCalls.add(call);
      return pendingReturn;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final c in cases) {
    test(c.name, () async {
      pendingReturn = c.handlerReturn;
      final result = await c.action();
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, hasLength(1),
          reason: '${c.name}: expected exactly one MethodCall');
      expect(capturedCalls.single.method, equals(c.wireMethod),
          reason: '${c.name}: wire method name');
      expect(capturedCalls.single.arguments, equals(c.wireArgs),
          reason: '${c.name}: wire arguments');
      if (c.expectResult != null) {
        c.expectResult!(result);
      }
    });
  }
}
