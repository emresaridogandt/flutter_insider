import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_insider/src/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Redirects `debugPrint` for the current test and returns the messages.
  List<String?> captureDebugPrint() {
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    return messages;
  }

  const MethodChannel channel = MethodChannel('flutter_insider');

  FlutterInsiderProduct buildProduct({
    String productID = 'sku-1',
    String name = 'Widget',
    List<String> taxonomy = const <String>['home', 'tools'],
    String imageURL = 'https://example.com/w.png',
    double unitPrice = 9.99,
    String currency = 'USD',
  }) =>
      FlutterInsiderProduct(
        channel,
        productID,
        name,
        taxonomy,
        imageURL,
        unitPrice,
        currency,
      );

  group('constructor', () {
    test('populates the required fields with the snake_case wire keys', () {
      final product = buildProduct();

      expect(
          product.requiredFields,
          equals(<String, dynamic>{
            'product_id': 'sku-1',
            'name': 'Widget',
            'taxonomy': <String>['home', 'tools'],
            'image_url': 'https://example.com/w.png',
            'price': 9.99,
            'currency': 'USD',
          }));
    });

    test('starts with empty optional fields and custom parameters', () {
      final product = buildProduct();

      expect(product.optionalFields, isEmpty);
      expect(product.customParameters, isEmpty);
    });
  });

  group('blank keys', () {
    test('every custom attribute setter drops a blank key and names itself',
        () {
      final messages = captureDebugPrint();
      final product = buildProduct()
        ..setCustomAttributeWithString('', 'v')
        ..setCustomAttributeWithInt('  ', 1)
        ..setCustomAttributeWithDouble('', 1.5)
        ..setCustomAttributeWithBoolean('  ', true)
        ..setCustomAttributeWithDate('', DateTime.utc(2024, 1, 1))
        ..setCustomAttributeWithStringArray('  ', <String>['a'])
        ..setCustomAttributeWithNumericArray('', <num>[1])
        ..setCustomAttributeWithString('kept', 'v');

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'string', 'key': 'kept', 'value': 'v'},
          ]));
      expect(
        messages,
        equals(<String>[
          for (final method in <String>[
            'setCustomAttributeWithString',
            'setCustomAttributeWithInt',
            'setCustomAttributeWithDouble',
            'setCustomAttributeWithBoolean',
            'setCustomAttributeWithDate',
            'setCustomAttributeWithStringArray',
            'setCustomAttributeWithNumericArray',
          ])
            '[Insider] $method ignored the call: an empty or whitespace-only key cannot be sent to native.',
        ]),
      );
    });
  });

  group('the native key rule at the product surface', () {
    test('every custom attribute setter refuses a key native would reject', () {
      // A blank key is rejected by a different branch, so a camelCase key is
      // what tells the two apart: it is the spelling a Dart caller reaches
      // for by default, and native drops it without a word.
      final messages = captureDebugPrint();
      final product = buildProduct()
        ..setCustomAttributeWithString('firstName', 'v')
        ..setCustomAttributeWithInt('lastSeen', 1)
        ..setCustomAttributeWithDouble('Ratio', 1.5)
        ..setCustomAttributeWithBoolean('isActive', true)
        ..setCustomAttributeWithDate('joinedAt', DateTime.utc(2024, 1, 1))
        ..setCustomAttributeWithStringArray('tagList', <String>['a'])
        ..setCustomAttributeWithNumericArray('9scores', <num>[1])
        ..setCustomAttributeWithString('kept_key', 'v');

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'string', 'key': 'kept_key', 'value': 'v'},
          ]));
      expect(
        messages,
        equals(<String>[
          for (final method in <String>[
            'setCustomAttributeWithString',
            'setCustomAttributeWithInt',
            'setCustomAttributeWithDouble',
            'setCustomAttributeWithBoolean',
            'setCustomAttributeWithDate',
            'setCustomAttributeWithStringArray',
            'setCustomAttributeWithNumericArray',
          ])
            '[Insider] $method ignored the call: a key must start with a '
                'lowercase letter and hold only lowercase letters, digits '
                'and underscores.',
        ]),
      );
    });
  });

  group('non-finite numbers', () {
    test('a finite price makes the product sendable', () {
      expect(buildProduct().hasSendablePrice, isTrue);
    });

    test('a NaN or infinite price makes the product unsendable and warns', () {
      final messages = captureDebugPrint();

      final nanProduct = buildProduct(unitPrice: double.nan);
      final infProduct = buildProduct(unitPrice: double.infinity);

      expect(nanProduct.hasSendablePrice, isFalse);
      expect(infProduct.hasSendablePrice, isFalse);
      expect(
          messages,
          equals(<String>[
            '[Insider] createNewProduct: the price of sku-1 is NaN or infinite, so '
                'this product will be left out of every call that carries it.',
            '[Insider] createNewProduct: the price of sku-1 is NaN or infinite, so '
                'this product will be left out of every call that carries it.',
          ]));
    });

    test('optional double setters ignore NaN and infinity with a warning', () {
      final messages = captureDebugPrint();

      final product = buildProduct()
        ..setSalePrice(double.nan)
        ..setShippingCost(double.infinity)
        ..setVoucherDiscount(double.negativeInfinity)
        ..setPromotionDiscount(double.nan)
        ..setCustomAttributeWithDouble('score', double.nan);

      expect(product.optionalFields, isEmpty);
      expect(product.customParameters, isEmpty);
      expect(
          messages,
          equals(<String>[
            '[Insider] setSalePrice ignored sale_price: NaN and infinite numbers '
                'cannot be sent to native.',
            '[Insider] setShippingCost ignored shipping_cost: NaN and infinite '
                'numbers cannot be sent to native.',
            '[Insider] setVoucherDiscount ignored voucher_discount: NaN and '
                'infinite numbers cannot be sent to native.',
            '[Insider] setPromotionDiscount ignored promotion_discount: NaN and '
                'infinite numbers cannot be sent to native.',
            '[Insider] setCustomAttributeWithDouble ignored score: NaN and '
                'infinite numbers cannot be sent to native.',
          ]));
    });
  });

  group('productMustMap', () {
    test('returns the required fields verbatim', () {
      final product = buildProduct();

      expect(product.productMustMap, same(product.requiredFields));
    });
  });

  group('simple optional-field setters', () {
    // (setter name, function applying the setter, expected wire key, value)
    final cases = <_OptCase>[
      _OptCase('setColor', (p) => p.setColor('red'), 'color', 'red'),
      _OptCase('setVoucherName', (p) => p.setVoucherName('SUMMER'),
          'voucher_name', 'SUMMER'),
      _OptCase('setPromotionName', (p) => p.setPromotionName('FLASH'),
          'promotion_name', 'FLASH'),
      _OptCase('setSalePrice', (p) => p.setSalePrice(7.5), 'sale_price', 7.5),
      _OptCase('setShippingCost', (p) => p.setShippingCost(2.5),
          'shipping_cost', 2.5),
      _OptCase('setVoucherDiscount', (p) => p.setVoucherDiscount(1.0),
          'voucher_discount', 1.0),
      _OptCase('setPromotionDiscount', (p) => p.setPromotionDiscount(0.5),
          'promotion_discount', 0.5),
      _OptCase('setStock', (p) => p.setStock(42), 'stock', 42),
      _OptCase('setQuantity', (p) => p.setQuantity(3), 'quantity', 3),
      _OptCase('setSize', (p) => p.setSize('M'), 'size', 'M'),
      _OptCase('setGroupCode', (p) => p.setGroupCode('GRP-1'), 'group_code',
          'GRP-1'),
      _OptCase('setDescription', (p) => p.setDescription('desc'), 'description',
          'desc'),
      _OptCase('setSku', (p) => p.setSku('SKU-1'), 'sku', 'SKU-1'),
      _OptCase('setMultipack', (p) => p.setMultipack('6'), 'multipack', '6'),
      _OptCase('setProductType', (p) => p.setProductType('physical'),
          'product_type', 'physical'),
      _OptCase('setGtin', (p) => p.setGtin('1234567890123'), 'gtin',
          '1234567890123'),
      _OptCase('setInStock', (p) => p.setInStock(true), 'in_stock', true),
      _OptCase(
        'setTags',
        (p) => p.setTags(<String>['a', 'b']),
        'tags',
        <String>['a', 'b'],
      ),
    ];

    for (final c in cases) {
      test('${c.name} writes ${c.value} under "${c.wireKey}"', () {
        final product = buildProduct();
        c.apply(product);

        expect(product.optionalFields[c.wireKey], equals(c.value));
        expect(product.optionalFields, hasLength(1));
      });

      test('${c.name} returns the same instance for chaining', () {
        final product = buildProduct();

        expect(identical(c.apply(product), product), isTrue);
      });
    }
  });

  group('int setters bounded by the 32-bit bridges', () {
    // (setter name, function applying the setter, wire key)
    final cases = <_IntCase>[
      _IntCase('setStock', (p, v) => p.setStock(v), 'stock'),
      _IntCase('setQuantity', (p, v) => p.setQuantity(v), 'quantity'),
    ];

    for (final c in cases) {
      test('${c.name} stores the highest value the bridges carry', () {
        final product = buildProduct();
        c.apply(product, 2147483647);

        expect(product.optionalFields[c.wireKey], equals(2147483647));
      });

      test('${c.name} stores the lowest value the bridges carry', () {
        final product = buildProduct();
        c.apply(product, -2147483647);

        expect(product.optionalFields[c.wireKey], equals(-2147483647));
      });

      test('${c.name} refuses a value wider than the 32-bit range', () {
        final messages = captureDebugPrint();
        final product = buildProduct();
        c.apply(product, 3000000000);

        expect(product.optionalFields.containsKey(c.wireKey), isFalse);
        expect(
          messages.single,
          equals('[Insider] ${c.name} ignored ${c.wireKey}: only whole '
              'numbers within the 32-bit range can be sent to native.'),
        );
      });

      test('${c.name} refuses the 32-bit floor, as every wrapper does', () {
        final product = buildProduct();
        c.apply(product, -2147483648);

        expect(product.optionalFields.containsKey(c.wireKey), isFalse);
      });

      test('${c.name} returns the same instance for a refused value', () {
        final product = buildProduct();

        expect(identical(c.apply(product, 3000000000), product), isTrue);
      });
    }
  });

  group('setters that skip empty strings', () {
    test('setBrand stores a non-empty value', () {
      final product = buildProduct()..setBrand('Acme');

      expect(product.optionalFields['brand'], equals('Acme'));
    });

    test('setBrand silently ignores an empty value', () {
      final product = buildProduct()..setBrand('');

      expect(product.optionalFields.containsKey('brand'), isFalse);
    });

    test('setGender stores a non-empty value', () {
      final product = buildProduct()..setGender('female');

      expect(product.optionalFields['gender'], equals('female'));
    });

    test('setGender silently ignores an empty value', () {
      final product = buildProduct()..setGender('');

      expect(product.optionalFields.containsKey('gender'), isFalse);
    });

    test('setProductURL stores a non-empty value', () {
      final product = buildProduct()..setProductURL('https://x');

      expect(product.optionalFields['product_url'], equals('https://x'));
    });

    test('setProductURL silently ignores an empty value', () {
      final product = buildProduct()..setProductURL('');

      expect(product.optionalFields.containsKey('product_url'), isFalse);
    });
  });

  group('typed custom attributes', () {
    test('setCustomAttributeWithString appends a "string" entry', () {
      final product = buildProduct()
        ..setCustomAttributeWithString('plan', 'gold');

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'string', 'key': 'plan', 'value': 'gold'},
          ]));
    });

    test('setCustomAttributeWithInt appends an "integer" entry', () {
      final product = buildProduct()..setCustomAttributeWithInt('age', 30);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'integer', 'key': 'age', 'value': 30},
          ]));
    });

    test('setCustomAttributeWithInt skips a value past the 32-bit range', () {
      final messages = captureDebugPrint();

      final product = buildProduct()
        ..setCustomAttributeWithInt('big', 3000000000)
        ..setCustomAttributeWithInt('age', 30);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'integer', 'key': 'age', 'value': 30},
          ]));
      expect(
        messages.single,
        equals('[Insider] setCustomAttributeWithInt ignored big: only whole '
            'numbers within the 32-bit range can be sent to native.'),
      );
    });

    test('setCustomAttributeWithDouble appends a "double" entry', () {
      final product = buildProduct()..setCustomAttributeWithDouble('s', 4.5);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'double', 'key': 's', 'value': 4.5},
          ]));
    });

    test('setCustomAttributeWithBoolean appends a "boolean" entry', () {
      final product = buildProduct()
        ..setCustomAttributeWithBoolean('flag', true);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'boolean', 'key': 'flag', 'value': true},
          ]));
    });

    test('setCustomAttributeWithDate stores epoch ms as a string', () {
      final date = DateTime.utc(2024, 1, 15);
      final product = buildProduct()..setCustomAttributeWithDate('d', date);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {
              'type': 'date',
              'key': 'd',
              'value': date.millisecondsSinceEpoch.toString(),
            },
          ]));
    });

    test('typed custom-attribute setters return the same instance', () {
      final product = buildProduct();

      expect(identical(product.setCustomAttributeWithString('k', 'v'), product),
          isTrue);
      expect(identical(product.setCustomAttributeWithInt('k', 1), product),
          isTrue);
      expect(identical(product.setCustomAttributeWithDouble('k', 1.0), product),
          isTrue);
      expect(
          identical(product.setCustomAttributeWithBoolean('k', true), product),
          isTrue);
      expect(
          identical(product.setCustomAttributeWithDate('k', DateTime.utc(2024)),
              product),
          isTrue);
    });
  });

  group('setCustomAttributeWithStringArray', () {
    test('keeps empty strings and stores type "strings", as native does', () {
      final product = buildProduct()
        ..setCustomAttributeWithStringArray('tags', <String>['a', '', 'b']);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {
              'type': 'strings',
              'key': 'tags',
              'value': <String>['a', '', 'b']
            },
          ]));
    });

    test('stores an array whose values are all empty', () {
      final product = buildProduct()
        ..setCustomAttributeWithStringArray('tags', <String>['', '']);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {
              'type': 'strings',
              'key': 'tags',
              'value': <String>['', '']
            },
          ]));
    });

    test('returns the same instance for chaining', () {
      final product = buildProduct();

      expect(
        identical(
          product.setCustomAttributeWithStringArray('k', <String>['a']),
          product,
        ),
        isTrue,
      );
    });
  });

  group('setCustomAttributeWithNumericArray', () {
    test('filters non-finite values and stores type "numbers"', () {
      final product = buildProduct()
        ..setCustomAttributeWithNumericArray(
          'scores',
          <num>[1, double.nan, 2.5, double.infinity, -3],
        );

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {
              'type': 'numbers',
              'key': 'scores',
              'value': <num>[1, 2.5, -3]
            },
          ]));
    });

    test('stores an empty array when every value is non-finite, as native does',
        () {
      final product = buildProduct()
        ..setCustomAttributeWithNumericArray(
          'scores',
          <num>[double.nan, double.infinity],
        );

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {'type': 'numbers', 'key': 'scores', 'value': <num>[]},
          ]));
    });

    test('returns the same instance for chaining', () {
      final product = buildProduct();

      expect(
        identical(
          product.setCustomAttributeWithNumericArray('k', <num>[1]),
          product,
        ),
        isTrue,
      );
    });
  });

  group('setCustomAttributeWithArray (deprecated)', () {
    test('stores values verbatim under type "strings" with no filtering', () {
      final product = buildProduct()
        // ignore: deprecated_member_use_from_same_package
        ..setCustomAttributeWithArray('tags', <String>['a', '', 'b']);

      expect(
          product.customParameters,
          equals(<Map<String, dynamic>>[
            {
              'type': 'strings',
              'key': 'tags',
              'value': <String>['a', '', 'b']
            },
          ]));
    });
  });

  group('productOptMap', () {
    test('returns optional fields when no custom parameters are present', () {
      final product = buildProduct()
        ..setColor('red')
        ..setStock(10);

      expect(
        product.productOptMap,
        equals(<String, dynamic>{'color': 'red', 'stock': 10}),
      );
    });

    test('merges custom parameter values keyed by their "key" field', () {
      final product = buildProduct()
        ..setColor('red')
        ..setCustomAttributeWithString('plan', 'gold')
        ..setCustomAttributeWithInt('age', 30);

      expect(
        product.productOptMap,
        equals(<String, dynamic>{
          'color': 'red',
          'plan': 'gold',
          'age': 30,
        }),
      );
    });

    test('a custom parameter overrides an optional field on key collision', () {
      final product = buildProduct()
        ..setColor('red')
        ..setCustomAttributeWithString('color', 'blue');

      expect(product.productOptMap['color'], equals('blue'));
    });

    test('returns a new map each call (does not leak the optionalFields ref)',
        () {
      final product = buildProduct()..setColor('red');

      final first = product.productOptMap;
      first['color'] = 'mutated';

      expect(product.optionalFields['color'], equals('red'));
      expect(product.productOptMap['color'], equals('red'));
    });
  });

  group('full chaining', () {
    test('mixed required + optional + custom builder produces the merged maps',
        () {
      final product = buildProduct()
          .setColor('red')
          .setBrand('Acme')
          .setStock(10)
          .setCustomAttributeWithString('plan', 'gold')
          .setCustomAttributeWithBoolean('vip', true);

      expect(product.requiredFields['product_id'], equals('sku-1'));
      expect(
          product.productOptMap,
          equals(<String, dynamic>{
            'color': 'red',
            'brand': 'Acme',
            'stock': 10,
            'plan': 'gold',
            'vip': true,
          }));
    });
  });
}

class _OptCase {
  _OptCase(this.name, this.apply, this.wireKey, this.value);

  final String name;
  final FlutterInsiderProduct Function(FlutterInsiderProduct) apply;
  final String wireKey;
  final Object value;
}

class _IntCase {
  _IntCase(this.name, this.apply, this.wireKey);

  final String name;
  final FlutterInsiderProduct Function(FlutterInsiderProduct, int) apply;
  final String wireKey;
}
