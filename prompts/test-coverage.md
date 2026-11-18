# flutter_insider Test Coverage Guidelines

Project rules for the AI Test Coverage analyzer. Applied on top of the universal
rules; where the two disagree, this file wins.

---

## ⛔ MANDATORY — READ BEFORE WRITING ANY TEST

**If you are about to create or modify a test file, you MUST first read
`.claude/rules/unit-tests.md` and follow it exactly.**

That file is the authoritative specification for test authoring in this repository: file location,
file naming, import order, the required `setUp`/`tearDown` shape, assertion rules, the shared
`test/wire_case.dart` harness, helper placement, error-path patterns, and naming conventions. It was
derived from all 12 existing `*_test.dart` files plus the shared `test/wire_case.dart` harness.

This applies to **every** agent that writes tests here, including the test-coverage auto-fixer.

Non-negotiable points, repeated here because getting them wrong is silent:

1. **Test files are flat: `test/<name>_test.dart`.** Do **not** mirror the source tree.
   `lib/src/user.dart` → `test/user_test.dart`, **never** `test/src/user_test.dart`.
   This explicitly overrides the auto-fixer's default path-mirroring rule.
2. **`await Future<void>.delayed(Duration.zero)`** after any action that triggers a channel call,
   before asserting. Omitting it yields a test that cannot fail.
3. **Null the mock handler in `tearDown`.** Omitting it cross-contaminates tests.
4. **Assert wire method names via `Constants.*`,** never a string literal.
5. **Never add a package to `pubspec.yaml`** and never introduce a mocking framework.
   `flutter_test` is the only test dependency; mocks are hand-built with
   `setMockMethodCallHandler`.
6. **Run `flutter test` before finishing.** A generated test that does not pass must be fixed or
   removed — never by changing source code.
7. **Decide the group first (`.claude/rules/unit-tests.md` §0).** A test that drives
   `FlutterInsider.Instance` belongs to the integration group and its file must carry
   `@Tags(['integration'])` above the imports. Untagged means unit — silently, and CI stays green
   while the Service Maturity dashboard reports one class short. Verify with
   `bash devops/check_test_groups.sh`.

A generated test that violates `.claude/rules/unit-tests.md` is to be treated as a defect, not an
acceptable approximation.

---

## Overview

- **Language**: Dart (Flutter plugin), with Java (Android) and Objective-C (iOS) native bridges
- **Repository Type**: Flutter plugin published to pub.dev as `flutter_insider`
- **Test Frameworks**: `flutter_test`, running **two groups**: unit and integration; plus
  native unit tests for the `FlutterInsiderUtils` helpers only (JUnit + Mockito in
  `android/src/test`, XCTest + OCMock in `ios/Tests`)
- **Test Gate**: `.github/workflows/run-tests.yml` runs the two groups as separate
  status checks (`Unit Tests`, `Integration Tests`) via
  `devops/unit_tests.sh --group <unit|integration>`, plus a `Coverage` job that
  runs the full suite unfiltered via `devops/unit_tests.sh --with-code-coverage`

Both groups are Dart tests over a mocked `MethodChannel`; they differ in **what
drives the code**, not in where they run. The only native tests cover the
`FlutterInsiderUtils` helpers, run through FlutterDemo by the `Android Native
Tests` / `iOS Native Tests` jobs (neither is a required check); there are no
on-device tests. The rest of the native side is a thin dispatch layer over the
vendored Insider SDKs, verified by the SDK teams' own repos, not here — for a
native-only change outside `FlutterInsiderUtils`, say so and route the
expectation to the Dart wire-contract test instead.

**Why the split matters.** The Service Maturity dashboard classifies a service by
the **required status-check names on the protected branch**, deriving the class
from the keyword in the name. A test that lands in the wrong group is not a style
problem: CI stays green and the dashboard silently reports one class short.

## Test Directory Structure

Layout is flat and identical for both groups — **the group is decided by a tag,
never by a directory**. Do not propose `test/unit/` or `test/integration/`.

```
UNIT:         test/*_test.dart  -  flutter_test  -  untagged (the default)
INTEGRATION:  test/*_test.dart  -  flutter_test  -  @Tags(['integration'])
```

| Path | Purpose |
|------|---------|
| `test/*_test.dart` | All tests, both groups. Flat layout, no nesting. |
| `test/wire_case.dart` | Shared table-test harness (not a test file itself) |

Commands:

```bash
flutter test                                     # all tests, both groups
flutter test --exclude-tags integration          # the unit group (as CI runs it)
flutter test --tags integration                  # the integration group
flutter test test/user_test.dart                 # single file
flutter test --name "setBirthday"                # by name pattern
bash devops/unit_tests.sh --group unit           # what the Unit Tests check runs
bash devops/unit_tests.sh --group integration    # what the Integration Tests check runs
bash devops/unit_tests.sh --with-code-coverage   # what the Coverage job runs
bash devops/check_test_groups.sh                 # tags agree with the SUT rule
```

## Test File Location Convention

> Authoritative spec: `.claude/rules/unit-tests.md` §1. Flat layout — never mirror the source tree.

Source file → test file, by source area rather than strict 1:1 mirroring:

| Source | Test |
|--------|------|
| `lib/src/user.dart` | `test/user_test.dart` |
| `lib/src/product.dart` | `test/product_test.dart` |
| `lib/src/event.dart` | `test/event_test.dart` |
| `lib/src/utils.dart` | `test/utils_test.dart` |
| `lib/src/identifiers.dart` | `test/identifiers_test.dart` |
| `lib/src/app_cards_error.dart` | `test/app_cards_error_test.dart` |
| `lib/src/app_cards_models.dart` | `test/insider_app_card_test.dart` |
| `lib/src/insider_app_cards.dart` | `test/insider_app_cards_test.dart` |
| `lib/flutter_insider.dart` | split by concern: `flutter_insider_test.dart`, `flutter_insider_commerce_test.dart`, `flutter_insider_lifecycle_test.dart`, `flutter_insider_queries_test.dart` |

`lib/flutter_insider.dart` is the 60+ method facade; its tests are split by
concern instead of into one oversized file. A new facade method belongs in the
matching concern file, not necessarily in `flutter_insider_test.dart`.

Those four concern files drive the production singleton and are therefore the
repository's **integration** group — they already carry `@Tags(['integration'])`.
A new facade test added to one of them inherits the tag; a facade test written
anywhere else must carry it.

## Unit Test Example

The dominant pattern: mock the `MethodChannel`, capture the outgoing
`MethodCall`, assert method name and arguments. From `test/user_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/constants.dart';
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
  Future<MethodCall> expectSingleCall(void Function() action) async {
    action();
    await Future<void>.delayed(Duration.zero); // drain pending microtasks
    expect(capturedCalls, hasLength(1));
    return capturedCalls.single;
  }

  test('setName sends method "setName" with raw string value', () async {
    final user = FlutterInsiderUser(channel);

    final call = await expectSingleCall(() => user.setName('Alice'));

    expect(call.method, equals(Constants.SET_NAME));
    expect(
      Map<String, dynamic>.from(call.arguments as Map),
      equals(<String, dynamic>{'key': Constants.SET_NAME, 'value': 'Alice'}),
    );
  });
}
```

Two details that are easy to get wrong and must be preserved:

- `await Future<void>.delayed(Duration.zero)` after the action — the platform
  channel delivers asynchronously; without draining microtasks the assertion
  runs before the call is captured.
- `tearDown` must null the handler. Leaking it across tests produces
  cross-contaminated `capturedCalls`.

Pure-logic code (no channel) is tested directly — see `test/utils_test.dart`
for `FlutterInsiderUtils.getDateForParsing`, and `test/app_cards_error_test.dart`
for enum/`fromMap` mapping.

## Test Utilities

`test/wire_case.dart` — the table-test harness for wire-contract assertions.
Prefer it whenever adding several methods that differ only in name/arguments.

- `WireCase({name, action, wireMethod, wireArgs, handlerReturn, expectResult})`
  — one row: a closure exercising one public method plus the expected wire output.
- `registerWireCases(List<WireCase>, MethodChannel)` — registers `setUp`/`tearDown`
  and emits one `test` per case, asserting exactly one `MethodCall`, its method
  name, its arguments, and optionally the return value.

Used by `flutter_insider_commerce_test.dart`, `flutter_insider_lifecycle_test.dart`,
and `flutter_insider_queries_test.dart`.

**The harness does not decide the group.** Those three files are integration
because their `action` closures drive `FlutterInsider.Instance`, not because they
use `WireCase`. The same harness is the right tool for a unit test whose `action`
drives a locally constructed SUT. Example:

```dart
import 'wire_case.dart';

registerWireCases([
  WireCase(
    name: 'visitHomePage (no args)',
    action: () => insider.visitHomePage(),
    wireMethod: Constants.VISIT_HOME_PAGE,
    wireArgs: <String, Object?>{},
  ),
], channel);
```

There are no mock factories or fixture directories — test data is built inline.

## Test Layer Selection

Two groups apply. Route by **what the test drives**, not by what changed —
see `.claude/rules/unit-tests.md` §0 for the decision procedure.

| Change | Expectation |
|--------|-------------|
| New/changed method on a **builder or helper class** (`user.dart`, `product.dart`, `event.dart`, `identifiers.dart`, `insider_app_cards.dart`) | **UNIT** — construct the SUT directly, assert method name + argument map |
| New/changed method on the **facade** `lib/flutter_insider.dart` | **INTEGRATION** — drives `FlutterInsider.Instance`; the test file must carry `@Tags(['integration'])` |
| New method-channel name in `lib/src/constants.dart` | Group follows whichever class exposes it — a wire-contract test referencing the constant, never a hardcoded string |
| Serialization logic (`FlutterInsiderUtils`, product/event builders) | **UNIT** — assert the serialized shape directly |
| Model/enum parsing (`app_cards_error.dart`, `app_cards_models.dart`) | **UNIT** — cover every enum value and the unknown/fallback branch |
| Native change to `FlutterInsiderUtils` (`.java` / `.m`) | **NATIVE** — a JUnit test in `android/src/test` / an XCTest in `ios/Tests` that mocks `Insider` and asserts the SDK call |
| Other native-only change (`android/**`, `ios/**`) | No Dart test possible in either group. Do not request one; note that the Dart wire contract is unchanged. |
| Version bumps (`pubspec.yaml`, `android/build.gradle`, `ios/flutter_insider.podspec`) | None — non-behavioral |

A new facade method that lands in an untagged file is a **defect**, not a style
issue: it runs in the unit group and the Service Maturity dashboard reports one
class short.

## Ignore Rules

DO NOT require tests for:

- **`devops/**` — release and CI automation.** Version bumping, changelog
  generation, Slack notification, GitHub release publishing, and the API-surface
  check tool. This code is not part of the published `flutter_insider` package
  and is not exercised by the SDK's test gate: CI runs only `flutter test` via
  `devops/unit_tests.sh`, and no workflow in this repo runs `pytest`. Changes
  here are validated by the GitHub Actions workflows that consume them
  (`api-surface-check.yml`, `create-release.yml`, `publish-release.yml`), not by
  the Dart suite. Explicitly includes all Python under
  `devops/api_surface_check/**` — its extractors, reporters, comparator, and
  `scripts/`. That package already carries an end-to-end test with fixtures at
  `devops/api_surface_check/tests/test_e2e.py`; adding a unit-test layer for it
  would create tests nothing runs.
- `.github/**` — workflow definitions
- `android/**`, `ios/**` outside `FlutterInsiderUtils` — native plugin code no
  native or Dart test layer covers; `android/src/test/**` and `ios/Tests/**`
  are the native tests themselves
- `lib/enum/*.dart` — constant-holder classes (`static const int` only, no
  methods or logic), e.g. `InsiderGender`, `InsiderCallbackAction`. Real Dart
  enums that carry parsing or mapping logic — such as
  `InsiderAppCardsErrorCode` in `lib/src/app_cards_error.dart` — live outside
  this directory and are **not** exempt.
- Barrel/re-export files with no logic
- Doc-only, comment-only, and formatting-only diffs
- Version-bump-only changes to `pubspec.yaml`, `android/build.gradle`,
  `ios/flutter_insider.podspec`, `CHANGELOG.md`
- Deletion-only diffs

> Reviewing the `devops/**` exemption: it holds as long as `devops/` stays
> release tooling and no CI job runs its tests. If a `pytest` job is ever added
> to this repo, or if product logic moves under `devops/`, revisit this rule
> rather than extending it.

## Backward Compatibility Detection

High-risk files — flag changes here for extra scrutiny even when a test exists,
because a silent break surfaces only at runtime in host apps:

| File | Risk |
|------|------|
| `lib/src/constants.dart` | Method-channel names are a contract with `FlutterInsiderPlugin.java` and `FlutterInsiderPlugin.m`. A renamed constant without both native sides updated is a silent no-op. |
| `lib/src/utils.dart` | `serializeCustomParameters()` emits the `[{type, key, value}]` shape both native `convertCustomParameters()` implementations parse. Changing a type tag (`string`, `integer`, `double`, `boolean`, `date`, `string_array`, `numeric_array`) breaks deserialization. |
| `lib/flutter_insider.dart` | Public API of the plugin. Signature changes, added required parameters, and removed methods break host apps. |
| `lib/src/product.dart`, `lib/src/event.dart` | Builder required/optional field sets are part of the payload contract. |
| `lib/src/app_cards_models.dart`, `lib/src/app_cards_error.dart` | Parsed from native payloads; a changed key or dropped enum case throws at runtime. |

Specifically scan diffs for: renamed or removed method-channel constants,
changed argument map keys, added required parameters, altered null-coalescing or
defaulting, and changed enum wire strings.
