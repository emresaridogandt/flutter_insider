import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/enum/InsiderAppCardActionType.dart';
import 'package:flutter_insider/enum/InsiderAppCardDeeplinkType.dart';
import 'package:flutter_insider/enum/InsiderAppCardType.dart';
import 'package:flutter_insider/flutter_insider.dart' as entry
    show
        InsiderAppCardActionType,
        InsiderAppCardDeeplinkType,
        InsiderAppCardType;
import 'package:flutter_insider/src/app_cards_models.dart';
import 'package:flutter_insider/src/app_cards_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('InsiderAppCardContent', () {
    test('should create content with title and description', () {
      final content = InsiderAppCardContent(
        title: 'Welcome',
        description: 'Welcome to our app!',
      );

      expect(content.title, equals('Welcome'));
      expect(content.description, equals('Welcome to our app!'));
    });
  });

  group('InsiderAppCardImage', () {
    test('should create image with url', () {
      final image = InsiderAppCardImage(
        url: 'https://example.com/image.jpg',
      );

      expect(image.url, equals('https://example.com/image.jpg'));
    });
  });

  group('InsiderAppCardCategory', () {
    test('should create category from map', () {
      final category = InsiderAppCardCategory.fromMap({
        'id': 3,
        'name': 'promotion',
      });

      expect(category, isNotNull);
      expect(category!.id, equals(3));
      expect(category.name, equals('promotion'));
    });

    test('should return null for invalid maps', () {
      expect(InsiderAppCardCategory.fromMap(null), isNull);
      expect(InsiderAppCardCategory.fromMap({'name': 'promotion'}), isNull);
      expect(InsiderAppCardCategory.fromMap({'id': 3}), isNull);
      expect(
          InsiderAppCardCategory.fromMap(
              {'id': 'not-int', 'name': 'promotion'}),
          isNull);
    });

    test('should expose toMap with original structure', () {
      final category = InsiderAppCardCategory(id: 7, name: 'sale');

      expect(category.toMap(), equals({'id': 7, 'name': 'sale'}));
    });
  });

  group('InsiderAppCardButton', () {
    const MethodChannel channel = MethodChannel('flutter_insider');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should create button with all properties', () {
      final button = InsiderAppCardButton(
        id: 'btn-1',
        text: 'Click Me',
        appCardId: 'card-1',
        action: null,
      );

      expect(button.id, equals('btn-1'));
      expect(button.text, equals('Click Me'));
      expect(button.appCardId, equals('card-1'));
      expect(button.action, isNull);
    });

    test('should expose toMap method with original structure', () {
      final button = InsiderAppCardButton(
        id: '262bf03d44f0c6b3cff4d821c2a473885562c8f7c60c51603783ed1f98a6bf506a26c1ee9a85c7ef9b90a35cd6f9fb80',
        text: 'Demo',
        appCardId: 'card-1',
        action: InsiderAppCardDeeplinkAction(
          externalBrowserUrl: 'https://insiderone.com/request-a-demo/',
        ),
      );

      final data = button.toMap();
      expect(
          data['id'],
          equals(
              '262bf03d44f0c6b3cff4d821c2a473885562c8f7c60c51603783ed1f98a6bf506a26c1ee9a85c7ef9b90a35cd6f9fb80'));
      expect(data['text'], equals('Demo'));
      expect(data['action'], isNotNull);
      expect(data['action']['type'], equals('deep_link'));
      expect(data['action']['external_browser_url'],
          equals('https://insiderone.com/request-a-demo/'));
    });

    test('should have correct properties for button click', () {
      final button = InsiderAppCardButton(
        id: 'btn-1',
        text: 'Click Me',
        appCardId: 'card-1',
        action: InsiderAppCardDeeplinkAction(
          externalBrowserUrl: 'https://example.com',
        ),
      );

      final data = button.toMap();
      expect(data['id'], equals('btn-1'));
      expect(data['text'], equals('Click Me'));
      expect(data['action'], isNotNull);
      expect(data['action']['type'], equals('deep_link'));
      expect(button.appCardId, equals('card-1'));
    });
  });

  group('InsiderAppCardDeeplinkAction', () {
    test('should create deeplink action with urlScheme', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: 'app://home',
      );

      expect(action.actionType, equals('deep_link'));
      expect(action.url, equals('app://home'));
    });

    test('should return url with priority order', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: 'app://scheme',
        internalBrowserUrl: 'https://internal.com',
        externalBrowserUrl: 'https://external.com',
      );

      expect(action.url, equals('app://scheme'));
    });

    test('should expose json as a map', () {
      final action = InsiderAppCardDeeplinkAction(
        json: {'url': 'app://home', 'param': 'value'},
      );

      expect(action.json!['url'], equals('app://home'));
      expect(action.json!['param'], equals('value'));
    });

    test('should return null json when json string is missing', () {
      final action = InsiderAppCardDeeplinkAction();

      expect(action.json, isNull);
    });

    test('should expose keysAndValues as raw list', () {
      final action = InsiderAppCardDeeplinkAction(
        keysAndValues: [
          {'key': 'url', 'value': 'app://home'},
          {'key': 'param', 'value': 'value'},
        ],
      );

      expect(action.keysAndValues, hasLength(2));
      expect(action.keysAndValues![0]['key'], equals('url'));
      expect(action.keysAndValues![0]['value'], equals('app://home'));
      expect(action.keysAndValues![1]['key'], equals('param'));
      expect(action.keysAndValues![1]['value'], equals('value'));
    });
  });

  group('deeplinkType', () {
    test('returns url_scheme when the URL scheme is non-empty', () {
      final action = InsiderAppCardDeeplinkAction(urlScheme: 'app://home');

      expect(
          action.deeplinkType, equals(InsiderAppCardDeeplinkType.URL_SCHEME));
    });

    test('returns internal when the URL scheme is empty and internal is set',
        () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: '',
        internalBrowserUrl: 'https://internal.example.com',
      );

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.INTERNAL));
    });

    test('returns internal when only the internal browser URL is non-empty',
        () {
      final action = InsiderAppCardDeeplinkAction(
        internalBrowserUrl: 'https://internal.example.com',
      );

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.INTERNAL));
    });

    test('returns external when only the external browser URL is non-empty',
        () {
      final action = InsiderAppCardDeeplinkAction(
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.EXTERNAL));
    });

    test(
        'returns unknown when the external browser URL is the only, empty field',
        () {
      final action = InsiderAppCardDeeplinkAction(externalBrowserUrl: '');

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.UNKNOWN));
    });

    test('returns unknown when no URL field is set', () {
      final action = InsiderAppCardDeeplinkAction();

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.UNKNOWN));
    });

    test('returns url_scheme when all three URL fields are set', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: 'app://scheme',
        internalBrowserUrl: 'https://internal.example.com',
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(
          action.deeplinkType, equals(InsiderAppCardDeeplinkType.URL_SCHEME));
    });

    test('returns internal when both browser URLs are set', () {
      final action = InsiderAppCardDeeplinkAction(
        internalBrowserUrl: 'https://internal.example.com',
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.INTERNAL));
    });

    test('returns external when the URL scheme and internal URL are empty', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: '',
        internalBrowserUrl: '',
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.EXTERNAL));
    });

    test('resolves an empty url_scheme on a card action to internal', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'action': {
          'type': InsiderAppCardActionType.DEEP_LINK,
          'url_scheme': '',
          'internal_browser_url': 'https://internal.example.com',
        },
      });

      final action = card!.action as InsiderAppCardDeeplinkAction;
      expect(action.deeplinkType, equals(InsiderAppCardDeeplinkType.INTERNAL));
    });

    test('resolves an empty url_scheme from a native payload to internal', () {
      final action = InsiderAppCardDeeplinkAction.fromMap({
        'type': InsiderAppCardActionType.DEEP_LINK,
        'url_scheme': '',
        'internal_browser_url': 'https://internal.example.com',
      });

      expect(action!.deeplinkType, equals(InsiderAppCardDeeplinkType.INTERNAL));
      expect(action.url, equals('https://internal.example.com'));
    });

    test('treats a non-string URL field from a native payload as unset', () {
      final action = InsiderAppCardDeeplinkAction.fromMap({
        'type': InsiderAppCardActionType.DEEP_LINK,
        'url_scheme': 42,
        'internal_browser_url': true,
        'external_browser_url': 'https://external.example.com',
      });

      expect(action!.deeplinkType, equals(InsiderAppCardDeeplinkType.EXTERNAL));
      expect(action.url, equals('https://external.example.com'));
      expect(
        action.toMap(),
        equals(<String, dynamic>{
          'type': InsiderAppCardActionType.DEEP_LINK,
          'external_browser_url': 'https://external.example.com',
        }),
      );
    });
  });

  group('url empty-value skipping', () {
    test('returns the internal browser URL when the URL scheme is empty', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: '',
        internalBrowserUrl: 'https://internal.example.com',
      );

      expect(action.url, equals('https://internal.example.com'));
    });

    test('returns the external browser URL when the earlier fields are empty',
        () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: '',
        internalBrowserUrl: '',
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(action.url, equals('https://external.example.com'));
    });

    test('returns an empty string when every URL field is empty', () {
      final action = InsiderAppCardDeeplinkAction(
        urlScheme: '',
        internalBrowserUrl: '',
        externalBrowserUrl: '',
      );

      expect(action.url, equals(''));
    });

    test('returns the internal URL when both browser URLs are set', () {
      final action = InsiderAppCardDeeplinkAction(
        internalBrowserUrl: 'https://internal.example.com',
        externalBrowserUrl: 'https://external.example.com',
      );

      expect(action.url, equals('https://internal.example.com'));
    });

    test('returns an empty string when no URL field is set', () {
      final action = InsiderAppCardDeeplinkAction();

      expect(action.url, equals(''));
    });
  });

  group('InsiderAppCardDeeplinkType', () {
    test('exposes the deeplink type wire values', () {
      expect(InsiderAppCardDeeplinkType.URL_SCHEME, equals('url_scheme'));
      expect(InsiderAppCardDeeplinkType.INTERNAL, equals('internal'));
      expect(InsiderAppCardDeeplinkType.EXTERNAL, equals('external'));
      expect(InsiderAppCardDeeplinkType.UNKNOWN, equals('unknown'));
    });

    test('is importable from the package entry point with the action types',
        () {
      expect(entry.InsiderAppCardDeeplinkType.URL_SCHEME,
          equals(InsiderAppCardDeeplinkType.URL_SCHEME));
      expect(entry.InsiderAppCardActionType.DEEP_LINK,
          equals(InsiderAppCardActionType.DEEP_LINK));
    });

    test('exposes the card type constants from the package entry point', () {
      expect(
          entry.InsiderAppCardType.MESSAGE, equals(InsiderAppCardType.MESSAGE));
    });
  });

  group('InsiderAppCardOpenSettingsAction', () {
    test('should create open settings action', () {
      final action = InsiderAppCardOpenSettingsAction();

      expect(action.actionType, equals('open_settings'));
    });
  });

  group('InsiderAppCardFeedbackAction', () {
    test('should create feedback action', () {
      final action = InsiderAppCardFeedbackAction();

      expect(action.actionType, equals('feedback'));
    });
  });

  group('InsiderAppCard', () {
    test('should create card with basic properties', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
      });

      expect(card, isNotNull);
      expect(card!.id, equals('card-1'));
      expect(card.type, equals('message'));
      expect(card.isRead, equals(false));
      expect(card.images, isNull);
      expect(card.content, isNull);
      expect(card.buttons, isNull);
      expect(card.action, isNull);
    });

    test('should create card with content', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'content': {
          'title': 'Test Title',
          'description': 'Test Description',
        },
      });

      expect(card!.content, isNotNull);
      expect(card.content!.title, equals('Test Title'));
      expect(card.content!.description, equals('Test Description'));
    });

    test('should create card with images', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'image',
        'read': true,
        'images': [
          {'url': 'https://example.com/img1.jpg'},
          {'url': 'https://example.com/img2.jpg'},
        ],
      });

      expect(card!.images, hasLength(2));
      expect(card.images![0].url, equals('https://example.com/img1.jpg'));
      expect(card.images![1].url, equals('https://example.com/img2.jpg'));
    });

    test('should create card with buttons', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'buttons': [
          {
            'id': 'btn-1',
            'text': 'Action 1',
          },
          {
            'id': 'btn-2',
            'text': 'Action 2',
          },
        ],
      });

      expect(card!.buttons, hasLength(2));
      expect(card.buttons![0].id, equals('btn-1'));
      expect(card.buttons![0].text, equals('Action 1'));
      expect(card.buttons![0].appCardId, equals('card-1'));
      expect(card.buttons![1].id, equals('btn-2'));
      expect(card.buttons![1].text, equals('Action 2'));
      expect(card.buttons![1].appCardId, equals('card-1'));
    });

    test('should create card with categories', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'categories': [
          {'id': 1, 'name': 'promotion'},
          {'id': 2, 'name': 'sale'},
        ],
      });

      expect(card!.categories, hasLength(2));
      expect(card.categories![0].id, equals(1));
      expect(card.categories![0].name, equals('promotion'));
      expect(card.categories![1].id, equals(2));
      expect(card.categories![1].name, equals('sale'));
    });

    test('should skip malformed categories', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'categories': [
          {'id': 1, 'name': 'promotion'},
          {'name': 'missing-id'},
          {'id': 'not-int', 'name': 'bad-id'},
        ],
      });

      expect(card!.categories, hasLength(1));
      expect(card.categories![0].name, equals('promotion'));
    });

    test('should include categories in toMap as empty list when absent', () {
      final card = InsiderAppCard(id: 'card-1', type: 'message');

      expect(card.categories, isNull);
      expect(card.toMap()['categories'], equals([]));
    });

    test('should include categories in toMap', () {
      final card = InsiderAppCard(
        id: 'card-1',
        type: 'message',
        categories: [InsiderAppCardCategory(id: 5, name: 'onboarding')],
      );

      expect(
          card.toMap()['categories'],
          equals([
            {'id': 5, 'name': 'onboarding'}
          ]));
    });

    test('should create card with deeplink action', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'action': {
          'type': 'deep_link',
          'url_scheme': 'app://promo',
        },
      });

      expect(card!.action, isA<InsiderAppCardDeeplinkAction>());
      expect(card.action!.actionType, equals('deep_link'));
      expect(
        (card.action as InsiderAppCardDeeplinkAction).url,
        equals('app://promo'),
      );
    });

    test('should create card with open settings action', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'action': {
          'type': 'open_settings',
        },
      });

      expect(card!.action, isA<InsiderAppCardOpenSettingsAction>());
      expect(card.action!.actionType, equals('open_settings'));
    });

    test('should create card with feedback action', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'action': {
          'type': 'feedback',
        },
      });

      expect(card!.action, isA<InsiderAppCardFeedbackAction>());
      expect(card.action!.actionType, equals('feedback'));
    });

    test('should handle unknown action type', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-1',
        'type': 'message',
        'read': false,
        'action': {
          'type': 'unknown_type',
        },
      });

      expect(card!.action, isNull);
    });

    test('should create complete card with all properties', () {
      final card = InsiderAppCard.fromMap({
        'id': 'card-complete',
        'type': 'message',
        'read': false,
        'content': {
          'title': 'Complete Card',
          'description': 'This card has everything',
        },
        'images': [
          {'url': 'https://example.com/image.jpg'}
        ],
        'buttons': [
          {
            'id': 'btn-1',
            'text': 'Click Here',
          },
        ],
        'action': {
          'type': 'deep_link',
          'url_scheme': 'app://details',
        },
      });

      expect(card!.id, equals('card-complete'));
      expect(card.type, equals('message'));
      expect(card.isRead, equals(false));
      expect(card.content, isNotNull);
      expect(card.images, hasLength(1));
      expect(card.buttons, hasLength(1));
      expect(card.action, isA<InsiderAppCardDeeplinkAction>());
    });

    group('markAsRead', () {
      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          null,
        );
      });

      test('should call markAsRead with card ID and update isRead on success',
          () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: false,
        );

        List<String>? capturedAppCardIds;
        String? capturedMethod;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsRead') {
              capturedMethod = methodCall.method;
              capturedAppCardIds =
                  List<String>.from(methodCall.arguments['appCardIds']);
              return '';
            }
            return null;
          },
        );

        await card.markAsRead();

        expect(capturedMethod, equals('appCardsMarkAsRead'));
        expect(capturedAppCardIds, equals(['card-1']));
        expect(card.isRead, equals(true));
      });

      test('should not update isRead when markAsRead fails', () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsRead') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Failed to mark as read',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.markAsRead(),
          throwsA(isA<InsiderAppCardsException>()),
        );
        expect(card.isRead, equals(false));
      });

      test(
          'should return a promise that resolves and updates isRead on success',
          () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsRead') {
              return '';
            }
            return null;
          },
        );

        await expectLater(card.markAsRead(), completes);
        expect(card.isRead, equals(true));
      });

      test(
          'should return a promise that rejects and keeps isRead unchanged on failure',
          () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsRead') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Network error',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.markAsRead(),
          throwsA(isA<InsiderAppCardsException>()),
        );
        expect(card.isRead, equals(false));
      });
    });

    group('markAsUnread', () {
      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          null,
        );
      });

      test('should call markAsUnread with card ID and update isRead on success',
          () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: true,
        );

        List<String>? capturedAppCardIds;
        String? capturedMethod;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsUnread') {
              capturedMethod = methodCall.method;
              capturedAppCardIds =
                  List<String>.from(methodCall.arguments['appCardIds']);
              return '';
            }
            return null;
          },
        );

        await card.markAsUnread();

        expect(capturedMethod, equals('appCardsMarkAsUnread'));
        expect(capturedAppCardIds, equals(['card-1']));
        expect(card.isRead, equals(false));
      });

      test('should not update isRead when markAsUnread fails', () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: true,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsUnread') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Failed to mark as unread',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.markAsUnread(),
          throwsA(isA<InsiderAppCardsException>()),
        );
        expect(card.isRead, equals(true));
      });

      test(
          'should return a promise that resolves and updates isRead on success',
          () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: true,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsUnread') {
              return '';
            }
            return null;
          },
        );

        await expectLater(card.markAsUnread(), completes);
        expect(card.isRead, equals(false));
      });

      test(
          'should return a promise that rejects and keeps isRead unchanged on failure',
          () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: true,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsMarkAsUnread') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Network error',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.markAsUnread(),
          throwsA(isA<InsiderAppCardsException>()),
        );
        expect(card.isRead, equals(true));
      });
    });

    group('delete', () {
      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          null,
        );
      });

      test('should call delete with card ID on success', () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: false,
        );

        List<String>? capturedAppCardIds;
        String? capturedMethod;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsDelete') {
              capturedMethod = methodCall.method;
              capturedAppCardIds =
                  List<String>.from(methodCall.arguments['appCardIds']);
              return '';
            }
            return null;
          },
        );

        await card.delete();

        expect(capturedMethod, equals('appCardsDelete'));
        expect(capturedAppCardIds, equals(['card-1']));
      });

      test('should throw error when delete fails', () async {
        final card = InsiderAppCard(
          id: 'card-1',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsDelete') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Failed to delete card',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.delete(),
          throwsA(isA<InsiderAppCardsException>()),
        );
      });

      test('should return a promise that resolves on success', () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsDelete') {
              return '';
            }
            return null;
          },
        );

        await expectLater(card.delete(), completes);
      });

      test('should return a promise that rejects on failure', () async {
        final card = InsiderAppCard(
          id: 'card-2',
          type: 'message',
          isRead: false,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_insider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'appCardsDelete') {
              throw PlatformException(
                code: 'APP_CARDS_ERROR',
                message: 'Network error',
              );
            }
            return null;
          },
        );

        await expectLater(
          card.delete(),
          throwsA(isA<InsiderAppCardsException>()),
        );
      });
    });
  });

  group('InsiderAppCardCampaignsResponse', () {
    test('should create response with cards', () {
      final response = InsiderAppCardCampaignsResponse.fromMap({
        'items': [
          {
            'id': 'card-1',
            'type': 'message',
            'read': false,
          },
          {
            'id': 'card-2',
            'type': 'image',
            'read': true,
          },
        ],
      });

      expect(response!.appCards, hasLength(2));
      expect(response.appCards[0].id, equals('card-1'));
      expect(response.appCards[1].id, equals('card-2'));
    });

    test('should create empty response when items is empty array', () {
      final response = InsiderAppCardCampaignsResponse.fromMap({'items': []});

      expect(response!.appCards, hasLength(0));
    });

    test('should handle undefined items', () {
      final response = InsiderAppCardCampaignsResponse.fromMap({});

      expect(response!.appCards, hasLength(0));
    });
  });

  group('InsiderAppCard convenience methods', () {
    test('view() method exists and can be called', () {
      final card = InsiderAppCard(
        id: 'card-1',
        type: 'message',
      );

      expect(card.view, isA<Function>());
    });

    test('click() method exists and can be called', () {
      final card = InsiderAppCard(
        id: 'card-1',
        type: 'message',
      );

      expect(card.click, isA<Function>());
    });
  });
}
