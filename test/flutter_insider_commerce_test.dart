@Tags(['integration'])
library flutter_insider_commerce_test;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/flutter_insider.dart';
import 'package:flutter_insider/src/constants.dart';
import 'package:flutter_insider/src/product.dart';

import 'wire_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_insider');
  final insider = FlutterInsider.Instance;

  FlutterInsiderProduct buildProduct() => insider.createNewProduct(
      'PROD1', 'Test Product', <String>['cat'], 'https://img.url', 9.99, 'USD');

  Map<String, Object?> productMap(FlutterInsiderProduct p) => <String, Object?>{
        'requiredFields': p.requiredFields,
        'optionalFields': p.optionalFields,
        'productCustomParameters': p.customParameters,
      };

  group('FlutterInsider commerce wire contract — page visits', () {
    registerWireCases([
      WireCase(
        name: 'visitHomePage (no args)',
        action: () => insider.visitHomePage(),
        wireMethod: Constants.VISIT_HOME_PAGE,
        wireArgs: <String, Object?>{},
      ),
      WireCase(
        name: 'visitHomePage with customParameters',
        action: () => insider.visitHomePage(
            customParameters: <String, Object>{'plan': 'gold'}),
        wireMethod: Constants.VISIT_HOME_PAGE,
        wireArgs: <String, Object?>{
          Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
            {'type': 'string', 'key': 'plan', 'value': 'gold'},
          ],
        },
      ),
      WireCase(
        name: 'visitListingPage forwards taxonomy',
        action: () => insider.visitListingPage(<String>['shoes', 'running']),
        wireMethod: Constants.VISIT_LISTING_PAGE,
        wireArgs: <String, Object?>{
          'taxonomy': <String>['shoes', 'running'],
        },
      ),
      WireCase(
        name: 'visitListingPage with customParameters',
        action: () => insider.visitListingPage(
          <String>['shoes'],
          customParameters: <String, Object>{'sort': 'price'},
        ),
        wireMethod: Constants.VISIT_LISTING_PAGE,
        wireArgs: <String, Object?>{
          'taxonomy': <String>['shoes'],
          Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
            {'type': 'string', 'key': 'sort', 'value': 'price'},
          ],
        },
      ),
    ], channel);
  });

  group('FlutterInsider commerce wire contract — product-bearing actions',
      () {
    final capturedCalls = <MethodCall>[];

    setUp(() {
      capturedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('visitProductDetailPage', () async {
      final product = buildProduct();
      await insider.visitProductDetailPage(product);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method,
          equals(Constants.VISIT_PRODUCT_DETAIL_PAGE));
      expect(capturedCalls.single.arguments, equals(productMap(product)));
    });

    test('visitProductDetailPage with customParameters', () async {
      final product = buildProduct();
      await insider.visitProductDetailPage(product,
          customParameters: <String, Object>{'origin': 'home'});
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.arguments, equals(<String, Object?>{
        ...productMap(product),
        Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
          {'type': 'string', 'key': 'origin', 'value': 'home'},
        ],
      }));
    });

    test('visitCartPage with one product (no saleID, no custom)', () async {
      final product = buildProduct();
      await insider.visitCartPage(<FlutterInsiderProduct>[product]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.method, equals(Constants.VISIT_CART_PAGE));
      expect(capturedCalls.single.arguments, equals(<String, Object?>{
        Constants.PRODUCTS: <Map<String, Object?>>[productMap(product)],
      }));
    });

    test('visitCartPage drops empty saleID', () async {
      final product = buildProduct();
      await insider.visitCartPage(<FlutterInsiderProduct>[product], saleID: '');
      await Future<void>.delayed(Duration.zero);

      final args =
          Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
      expect(args.containsKey('saleID'), isFalse);
    });

    test('visitCartPage forwards non-empty saleID', () async {
      final product = buildProduct();
      await insider.visitCartPage(<FlutterInsiderProduct>[product],
          saleID: 'SALE-1');
      await Future<void>.delayed(Duration.zero);

      final args =
          Map<String, dynamic>.from(capturedCalls.single.arguments as Map);
      expect(args['saleID'], equals('SALE-1'));
    });

    test('visitWishlistPage with one product', () async {
      final product = buildProduct();
      await insider.visitWishlistPage(<FlutterInsiderProduct>[product]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.method,
          equals(Constants.VISIT_WISHLIST_PAGE));
      expect(capturedCalls.single.arguments, equals(<String, Object?>{
        Constants.PRODUCTS: <Map<String, Object?>>[productMap(product)],
      }));
    });

    test('itemPurchased', () async {
      final product = buildProduct();
      await insider.itemPurchased('SALE-X', product);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.method, equals(Constants.ITEM_PURCHASED));
      expect(capturedCalls.single.arguments, equals(<String, Object?>{
        'uniqueSaleID': 'SALE-X',
        ...productMap(product),
      }));
    });

    test('itemAddedToCart', () async {
      final product = buildProduct();
      await insider.itemAddedToCart(product);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.method,
          equals(Constants.ITEM_ADDED_TO_CART));
      expect(capturedCalls.single.arguments, equals(productMap(product)));
    });

    test('lists every product a cart page visit leaves out in one warning',
        () async {
      final messages = <String?>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = original);

      final bad1 = insider.createNewProduct('PROD7', 'A', <String>['cat'],
          'https://img.url', double.nan, 'USD');
      final bad2 = insider.createNewProduct('PROD8', 'B', <String>['cat'],
          'https://img.url', double.infinity, 'USD');
      await insider.visitCartPage(
          <FlutterInsiderProduct>[bad1, buildProduct(), bad2]);
      await Future<void>.delayed(Duration.zero);

      expect(
        messages.where((m) => m!.contains('left out')).last,
        equals('[Insider] visitCartPage left out PROD7, PROD8: their price is '
            'NaN or infinite. The rest of the call was still sent.'),
      );
    });

    test('names the skipped call when the product price is not finite',
        () async {
      final messages = <String?>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = original);

      final product = insider.createNewProduct(
          'PROD9', 'Test Product', <String>['cat'], 'https://img.url',
          double.nan, 'USD');
      await insider.itemPurchased('SALE-X', product);
      await insider.visitCartPage(<FlutterInsiderProduct>[product]);
      await Future<void>.delayed(Duration.zero);

      expect(
        messages
            .where((m) => m!.contains('PROD9') && !m.contains('createNewProduct'))
            .toList(),
        equals(<String>[
          '[Insider] itemPurchased skipped PROD9: its price is NaN or '
              'infinite, so the call carrying it was not sent.',
          '[Insider] visitCartPage left out PROD9: their price is NaN or '
              'infinite. The rest of the call was still sent.',
        ]),
      );
    });

    test('skips single-product events when the product price is not finite',
        () async {
      final product = insider.createNewProduct(
          'PROD1', 'Test Product', <String>['cat'], 'https://img.url',
          double.nan, 'USD');

      await insider.visitProductDetailPage(product);
      await insider.itemPurchased('SALE-X', product);
      await insider.itemAddedToCart(product);
      await insider.itemAddedToWishlist(product);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });

    test('visitCartPage and visitWishlistPage leave out products whose price is not finite',
        () async {
      final valid = buildProduct();
      final invalid = insider.createNewProduct(
          'PROD2', 'Test Product', <String>['cat'], 'https://img.url',
          double.infinity, 'USD');

      await insider.visitCartPage(<FlutterInsiderProduct>[invalid, valid]);
      await insider.visitWishlistPage(<FlutterInsiderProduct>[valid, invalid]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.map((c) => c.method),
          equals(<String>[Constants.VISIT_CART_PAGE, Constants.VISIT_WISHLIST_PAGE]));
      for (final call in capturedCalls) {
        expect(call.arguments,
            equals(<String, Object?>{Constants.PRODUCTS: <Object?>[productMap(valid)]}));
      }
    });

    test('visitCartPage and visitWishlistPage still reach native when no product has a finite price',
        () async {
      final invalid = insider.createNewProduct(
          'PROD2', 'Test Product', <String>['cat'], 'https://img.url',
          double.nan, 'USD');

      await insider.visitCartPage(<FlutterInsiderProduct>[invalid]);
      await insider.visitWishlistPage(<FlutterInsiderProduct>[]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.map((c) => c.method),
          equals(<String>[Constants.VISIT_CART_PAGE, Constants.VISIT_WISHLIST_PAGE]));
      for (final call in capturedCalls) {
        expect(call.arguments,
            equals(<String, Object?>{Constants.PRODUCTS: <Object?>[]}));
      }
    });

    test('visitWishlistPage still reaches native when every given product has a non-finite price',
        () async {
      final nanPrice = insider.createNewProduct(
          'PROD2', 'Test Product', <String>['cat'], 'https://img.url',
          double.nan, 'USD');
      final infinitePrice = insider.createNewProduct(
          'PROD3', 'Test Product', <String>['cat'], 'https://img.url',
          double.infinity, 'USD');

      await insider
          .visitWishlistPage(<FlutterInsiderProduct>[nanPrice, infinitePrice]);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.single.method, equals(Constants.VISIT_WISHLIST_PAGE));
      expect(capturedCalls.single.arguments,
          equals(<String, Object?>{Constants.PRODUCTS: <Object?>[]}));
    });

    test('itemAddedToWishlist', () async {
      final product = buildProduct();
      await insider.itemAddedToWishlist(product);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls.single.method,
          equals(Constants.ITEM_ADDED_TO_WISH_LIST));
      expect(capturedCalls.single.arguments, equals(productMap(product)));
    });
  });

  group('FlutterInsider commerce wire contract — id/clear actions', () {
    registerWireCases([
      WireCase(
        name: 'itemRemovedFromCart (no saleID)',
        action: () => insider.itemRemovedFromCart('PROD1'),
        wireMethod: Constants.ITEM_REMOVED_FROM_CART,
        wireArgs: <String, Object?>{'productID': 'PROD1'},
      ),
      WireCase(
        name: 'itemRemovedFromCart drops empty saleID',
        action: () => insider.itemRemovedFromCart('PROD1', saleID: ''),
        wireMethod: Constants.ITEM_REMOVED_FROM_CART,
        wireArgs: <String, Object?>{'productID': 'PROD1'},
      ),
      WireCase(
        name: 'itemRemovedFromCart forwards saleID',
        action: () =>
            insider.itemRemovedFromCart('PROD1', saleID: 'SALE-9'),
        wireMethod: Constants.ITEM_REMOVED_FROM_CART,
        wireArgs: <String, Object?>{
          'productID': 'PROD1',
          'saleID': 'SALE-9',
        },
      ),
      WireCase(
        name: 'itemRemovedFromCart with customParameters',
        action: () => insider.itemRemovedFromCart(
          'PROD1',
          customParameters: <String, Object>{'reason': 'price'},
        ),
        wireMethod: Constants.ITEM_REMOVED_FROM_CART,
        wireArgs: <String, Object?>{
          'productID': 'PROD1',
          Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
            {'type': 'string', 'key': 'reason', 'value': 'price'},
          ],
        },
      ),
      WireCase(
        name: 'itemRemovedFromWishlist',
        action: () => insider.itemRemovedFromWishlist('PROD1'),
        wireMethod: Constants.ITEM_REMOVED_FROM_WISH_LIST,
        wireArgs: <String, Object?>{'productID': 'PROD1'},
      ),
      WireCase(
        name: 'cartCleared (no args)',
        action: () => insider.cartCleared(),
        wireMethod: Constants.CART_CLEARED,
        wireArgs: <String, Object?>{},
      ),
      WireCase(
        name: 'cartCleared with customParameters',
        action: () => insider.cartCleared(
            customParameters: <String, Object>{'reason': 'logout'}),
        wireMethod: Constants.CART_CLEARED,
        wireArgs: <String, Object?>{
          Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
            {'type': 'string', 'key': 'reason', 'value': 'logout'},
          ],
        },
      ),
      WireCase(
        name: 'wishlistCleared (no args)',
        action: () => insider.wishlistCleared(),
        wireMethod: Constants.WISH_LIST_CLEARED,
        wireArgs: <String, Object?>{},
      ),
      WireCase(
        name: 'signUpConfirmation (no args)',
        action: () => insider.signUpConfirmation(),
        wireMethod: Constants.SIGN_UP_CONFIRMATION,
        wireArgs: <String, Object?>{},
      ),
      WireCase(
        name: 'signUpConfirmation with customParameters',
        action: () => insider.signUpConfirmation(
            customParameters: <String, Object>{'method': 'email'}),
        wireMethod: Constants.SIGN_UP_CONFIRMATION,
        wireArgs: <String, Object?>{
          Constants.CUSTOM_PARAMETERS: <Map<String, Object>>[
            {'type': 'string', 'key': 'method', 'value': 'email'},
          ],
        },
      ),
    ], channel);
  });
}
