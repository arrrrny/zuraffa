import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';

void main() {
  group('zfa init Zorphy v3 scaffold', () {
    test('emits a principal-key entity without the v2 surface', () {
      final source = InitializeCommand.generateEntityContent('Product');

      expect(source, contains('@ZorphyEntity(principalKey: #id)'));
      expect(source, contains('String get id;'));
      expect(source, contains("part 'product.zorphy.dart';"));
      expect(source, isNot(contains('@Zorphy(')));
      expect(source, isNot(contains('_br_/')));
    });
  });

  group('EntityFieldResolver AST contract', () {
    test('reads fields from compact class declarations', () {
      final fields = EntityFieldResolver.parseEntityFields('''
@ZorphyEntity(principalKey: #id)
abstract class \$Invoice { String get id; String get number; }
''');

      expect(fields.map((field) => field.name), ['id', 'number']);
      expect(fields.map((field) => field.type), ['String', 'String']);
    });

    test('reads principalKey after nested annotation argument text', () {
      const source = '''
@ZorphyEntity(discriminator: ')', principalKey: #sku)
abstract class \$Ticket {
  String get id;
  String get sku;
}
''';

      expect(EntityFieldResolver.principalKeyField(source), 'sku');
      expect(
        EntityFieldResolver.resolveFromSource(source)?.idField?.name,
        'sku',
      );
    });

    test('ignores annotation text inside string literals', () {
      const source = '''
const example = '@ZorphyValue()';
abstract class \$Product {
  String get id;
}
''';

      expect(EntityFieldResolver.detectsValueObject(source), isFalse);
      expect(
        EntityFieldResolver.resolveFromSource(source)?.idField?.name,
        'id',
      );
    });

    test('ignores static and sibling-class fields', () {
      const source = '''
abstract class \$Ticket {
  static String? id;
  String get tenantId;
}

class TicketHelper {
  String get id;
}
''';

      expect(
        EntityFieldResolver.resolveFromSource(source)?.idField?.name,
        'tenantId',
      );
    });

    test('selects the requested entity instead of an earlier helper value', () {
      const source = '''
@ZorphyValue()
abstract class \$Metadata {
  String get label;
}

@ZorphyEntity(principalKey: #id)
abstract class \$Product {
  String get id;
}
''';

      final resolved = EntityFieldResolver.resolveFromSource(
        source,
        className: r'$Product',
      );

      expect(resolved?.isValueObject, isFalse);
      expect(resolved?.idField?.name, 'id');
    });

    test('merges inherited identity from generated EntityFields', () {
      const source = '''
@ZorphyEntity(principalKey: #sku)
abstract class \$Base {
  String get sku;
}

@ZorphyEntity()
abstract class \$Ticket extends \$Base {
  String get title;
}

final class Base implements \$Base, ZorphyEntityBase<String> {
  final String sku;
}

final class Ticket implements \$Ticket, ZorphyEntityBase<String> {
  final String sku;
  final String title;
}

abstract final class TicketFields {
  static const ZorphyField<Ticket, String> sku = ZorphyField(name: 'sku');
  static const ZorphyField<Ticket, String> title = ZorphyField(name: 'title');
}
''';

      final resolved = EntityFieldResolver.resolveFromSource(
        source,
        className: r'$Ticket',
      );

      expect(resolved?.idField?.name, 'sku');
      expect(resolved?.idField?.type, 'String');
    });

    test(
      'resolveIdField reads inherited keys from the colocated part',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'issue_2172_resolver_',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final dir = Directory(
          p.join(root.path, 'lib', 'src', 'domain', 'entities', 'ticket'),
        )..createSync(recursive: true);

        File(p.join(dir.path, 'ticket.dart')).writeAsStringSync('''
part 'ticket.zorphy.dart';

@ZorphyEntity(principalKey: #sku)
abstract class \$Base {
  String get sku;
}

@ZorphyEntity()
abstract class \$Ticket extends \$Base {
  String get title;
}
''');
        File(p.join(dir.path, 'ticket.zorphy.dart')).writeAsStringSync('''
part of 'ticket.dart';

final class Base implements \$Base, ZorphyEntityBase<String> {
  final String sku;
}

final class Ticket implements \$Ticket, ZorphyEntityBase<String> {
  final String sku;
  final String title;
}

abstract final class TicketFields {
  static const ZorphyField<Ticket, String> sku = ZorphyField(name: 'sku');
  static const ZorphyField<Ticket, String> title = ZorphyField(name: 'title');
}
''');

        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'Ticket',
          projectRoot: root.path,
        );

        expect(resolved?.idField?.name, 'sku');
        expect(resolved?.idField?.type, 'String');
      },
    );

    test('keeps generated-only value-object parts identity-free', () {
      const source = '''
final class Money implements ZorphyValueBase {
  final String? ownerId;
  final double amount;
}

abstract final class MoneyFields {
  static const ZorphyField<Money, String?> ownerId =
      ZorphyField(name: 'ownerId');
  static const ZorphyField<Money, double> amount =
      ZorphyField(name: 'amount');
}
''';

      final resolved = EntityFieldResolver.resolveFromSource(source);

      expect(resolved?.isValueObject, isTrue);
      expect(resolved?.hasId, isFalse);
    });

    test('reads generated EntityFields descriptor names and value types', () {
      final fields = EntityFieldResolver.parseEntityFields('''
abstract final class ProductFields {
  static const ZorphyField<Product, String> id =
      ZorphyField(name: 'id');
  static const ZorphyField<Product, double> price =
      ZorphyField(name: 'price');
  static final List<ZorphyField<Product, Object?>> all = [id, price];
}
''');

      expect(fields.map((field) => field.name), ['id', 'price']);
      expect(fields.map((field) => field.type), ['String', 'double']);
    });

    test('keeps ZorphyValue declarations identity-free', () {
      const source = '''
@ZorphyValue()
abstract class \$Money {
  String? get ownerId;
  double get amount;
}
''';

      final resolved = EntityFieldResolver.resolveFromSource(source);

      expect(resolved?.isValueObject, isTrue);
      expect(resolved?.hasId, isFalse);
    });
  });
}
