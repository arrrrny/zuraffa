/// Tests for SpecReader (U5-U8, U33).
///
/// Behaviors traced to test-list.md:
///   U5: extracts entity names from `## Key Entities` bold entries
///   U6: a spec with no entity declarations yields an empty entity list
///   U7: spec_version is SHA-256 of spec bytes and changes with content
///   U8: feature slug is derived from the spec's directory name
///   U33: xray overlay markers are extracted from `<!-- xray: ... -->` comments
///
/// Uses temporary files for filesystem tests; cleans up after.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/spec_reader.dart';

void main() {
  late SpecReader reader;
  late Directory tmpDir;

  setUp(() async {
    reader = SpecReader();
    tmpDir = await Directory.systemTemp.createTemp('spec_reader_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> writeSpec(String dirName, String content) async {
    final dir = await Directory('${tmpDir.path}/$dirName').create();
    final file = File('${dir.path}/spec.md');
    await file.writeAsString(content);
    return file;
  }

  group('SpecReader.read', () {
    test(
      'U5: extracts entity names from the ## Key Entities bold entries',
      () async {
        final file = await writeSpec('my-feature', '''
# Feature: My Feature

## Key Entities

- **Product** — a catalog item
- **CartItem** — user selection

## Requirements

Something here.
''');
        final result = reader.read(file);
        expect(result.entities, equals(['Product', 'CartItem']));
      },
    );

    test(
      'U6: a spec with no entity declarations yields an empty entity list',
      () async {
        final file = await writeSpec('empty-feature', '''
# Feature: Empty

## Requirements

No entities declared.
''');
        final result = reader.read(file);
        expect(result.entities, isEmpty);
      },
    );

    test(
      'U7: spec_version is SHA-256 of spec bytes and changes with content',
      () async {
        final file = await writeSpec(
          'versioned',
          '# Feature: V1\n\n## Key Entities\n\n- **Foo**\n',
        );
        final result1 = reader.read(file);

        // spec_version must be a 64-char hex string (SHA-256).
        expect(result1.specVersion, hasLength(64));
        expect(result1.specVersion, matches(RegExp(r'^[0-9a-f]{64}$')));

        // Modify content → hash must change.
        await file.writeAsString(
          '# Feature: V2\n\n## Key Entities\n\n- **Foo**\n',
        );
        final result2 = reader.read(file);
        expect(result2.specVersion, isNot(equals(result1.specVersion)));
      },
    );

    test('U8: feature slug is derived from the spec directory name', () async {
      final file = await writeSpec(
        '020-skeleton-plugin-bones',
        '# Feature: Skeleton\n\n## Key Entities\n\n- **Bone**\n',
      );
      final result = reader.read(file);
      expect(result.featureSlug, equals('020-skeleton-plugin-bones'));
    });

    test(
      'U33: xray overlay markers are extracted from HTML comment annotations',
      () async {
        final file = await writeSpec('xray-feature', '''
# Feature: Xray Feature

## Key Entities

- **Widget** — a UI component

<!-- xray: overlay: {"enabled": true, "color": "neon-green"} -->
<!-- xray: mode: development -->

## Requirements

- Widget must render correctly
''');
        final result = reader.read(file);
        expect(
          result.xrayMarkers,
          containsPair('overlay', '{"enabled": true, "color": "neon-green"}'),
        );
        expect(result.xrayMarkers, containsPair('mode', 'development'));
      },
    );

    test(
      'U34: extracts entities from a ### Key Entities section nested under ## Requirements',
      () async {
        final file = await writeSpec('nested-entities', '''
# Feature: Nested

## Requirements

### Key Entities

- **Bone** — a scaffold
- **Manifest** — metadata

### Functional Requirements

- FR-001: something
''');
        final result = reader.read(file);
        expect(result.entities, equals(['Bone', 'Manifest']));
      },
    );

    test(
      'U35: a multi-word bold entity name is captured and normalized to PascalCase',
      () async {
        final file = await writeSpec('multi-word', '''
# Feature: Multi

## Key Entities

- **Dependency Graph** — an acyclic directed graph
- **Bone** — a scaffold
''');
        final result = reader.read(file);
        expect(result.entities, equals(['DependencyGraph', 'Bone']));
      },
    );

    test('U33: spec without xray markers yields empty xray map', () async {
      final file = await writeSpec(
        'no-xray-feature',
        '# Feature: No Xray\n\n## Key Entities\n\n- **Foo**\n',
      );
      final result = reader.read(file);
      expect(result.xrayMarkers, isEmpty);
    });
  });

  group('SpecReader field parsing (042 working slice)', () {
    test(
      '042-U1: parses indented "- name: Type" lines into entity fields',
      () async {
        final file = await writeSpec('profile-feature', '''
# Feature: Profile

## Key Entities

- **User** — the profile owner
  - id: String
  - displayName: String
  - age: int

## Requirements

- Users own their profile
''');
        final result = reader.read(file);
        expect(result.entities, equals(['User']));
        final user = result.entityFields['User']!;
        expect(user, hasLength(3));
        expect(user[0].name, equals('id'));
        expect(user[0].type, equals('String'));
        expect(user[1].name, equals('displayName'));
        expect(user[2].type, equals('int'));
      },
    );

    test('042-U2: "?" suffix marks a field nullable', () async {
      final file = await writeSpec('nullable-feature', '''
# Feature: Nullable

## Key Entities

- **User** — owner
  - id: String
  - email?: String
''');
      final result = reader.read(file);
      final fields = result.entityFields['User']!;
      expect(fields[1].name, equals('email'));
      expect(fields[1].nullable, isTrue);
      expect(fields[0].nullable, isFalse);
    });

    test('042-U3: unknown field type produces a spec read error naming entity, '
        'field, and allowed types', () async {
      final file = await writeSpec('bad-type', '''
# Feature: Bad Type

## Key Entities

- **User** — owner
  - id: String
  - avatar: UIImage
''');
      expect(
        () => reader.read(file),
        throwsA(
          isA<SpecReadError>()
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('User'),
                  contains('avatar'),
                  contains('UIImage'),
                ),
              )
              .having((e) => e.message, 'message', contains('String')),
        ),
      );
    });

    test('042-U4: specs without field lines keep entity-name-only extraction '
        '(backward compatible)', () async {
      final file = await writeSpec('old-feature', '''
# Feature: Old

## Key Entities

- **Product** — a catalog item
- **CartItem** — user selection

## Requirements

- Products have a name and price
''');
      final result = reader.read(file);
      expect(result.entities, equals(['Product', 'CartItem']));
      expect(result.entityFields['Product'], isEmpty);
      expect(result.entityFields['CartItem'], isEmpty);
    });

    test('042-U5: fields bind to the entity above them and stop at the next '
        'heading or bold entry', () async {
      final file = await writeSpec('binding', '''
# Feature: Binding

## Key Entities

- **User** — owner
  - id: String
- **Post** — content
  - title: String

## Requirements

- The word id in requirement text must not become a field
''');
      final result = reader.read(file);
      expect(result.entityFields['User']!.map((f) => f.name), equals(['id']));
      expect(
        result.entityFields['Post']!.map((f) => f.name),
        equals(['title']),
      );
      expect(result.entityFields.containsKey('Requirements'), isFalse);
    });

    test('all documented types parse without error', () async {
      final file = await writeSpec('all-types', '''
# Feature: Types

## Key Entities

- **Everything** — every supported field type
  - s: String
  - i: int
  - d: double
  - n: num
  - b: bool
  - l: List<String>
  - m: Map<String, dynamic>
  - dt: DateTime
''');
      final result = reader.read(file);
      expect(result.entityFields['Everything'], hasLength(8));
    });
  });
}
