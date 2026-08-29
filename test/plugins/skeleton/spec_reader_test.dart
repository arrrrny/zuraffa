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
        final file = await writeSpec(
          'my-feature',
          '''
# Feature: My Feature

## Key Entities

- **Product** — a catalog item
- **CartItem** — user selection

## Requirements

Something here.
''',
        );
        final result = reader.read(file);
        expect(result.entities, equals(['Product', 'CartItem']));
      },
    );

    test(
      'U6: a spec with no entity declarations yields an empty entity list',
      () async {
        final file = await writeSpec(
          'empty-feature',
          '''
# Feature: Empty

## Requirements

No entities declared.
''',
        );
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
        expect(
          result1.specVersion,
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );

        // Modify content → hash must change.
        await file.writeAsString('# Feature: V2\n\n## Key Entities\n\n- **Foo**\n');
        final result2 = reader.read(file);
        expect(result2.specVersion, isNot(equals(result1.specVersion)));
      },
    );

    test(
      'U8: feature slug is derived from the spec directory name',
      () async {
        final file = await writeSpec(
          '020-skeleton-plugin-bones',
          '# Feature: Skeleton\n\n## Key Entities\n\n- **Bone**\n',
        );
        final result = reader.read(file);
        expect(result.featureSlug, equals('020-skeleton-plugin-bones'));
      },
    );

    test(
      'U33: xray overlay markers are extracted from HTML comment annotations',
      () async {
        final file = await writeSpec(
          'xray-feature',
          '''
# Feature: Xray Feature

## Key Entities

- **Widget** — a UI component

<!-- xray: overlay: {"enabled": true, "color": "neon-green"} -->
<!-- xray: mode: development -->

## Requirements

- Widget must render correctly
''',
        );
        final result = reader.read(file);
        expect(result.xrayMarkers, containsPair('overlay', '{"enabled": true, "color": "neon-green"}'));
        expect(result.xrayMarkers, containsPair('mode', 'development'));
      },
    );

    test(
      'U34: extracts entities from a ### Key Entities section nested under ## Requirements',
      () async {
        final file = await writeSpec(
          'nested-entities',
          '''
# Feature: Nested

## Requirements

### Key Entities

- **Bone** — a scaffold
- **Manifest** — metadata

### Functional Requirements

- FR-001: something
''',
        );
        final result = reader.read(file);
        expect(result.entities, equals(['Bone', 'Manifest']));
      },
    );

    test(
      'U35: a multi-word bold entity name is captured and normalized to PascalCase',
      () async {
        final file = await writeSpec(
          'multi-word',
          '''
# Feature: Multi

## Key Entities

- **Dependency Graph** — an acyclic directed graph
- **Bone** — a scaffold
''',
        );
        final result = reader.read(file);
        expect(result.entities, equals(['DependencyGraph', 'Bone']));
      },
    );

    test(
      'U33: spec without xray markers yields empty xray map',
      () async {
        final file = await writeSpec(
          'no-xray-feature',
          '# Feature: No Xray\n\n## Key Entities\n\n- **Foo**\n',
        );
        final result = reader.read(file);
        expect(result.xrayMarkers, isEmpty);
      },
    );
  });
}
