// Spec 1098 — FeatureContract decorators: persistent knowledge across layers.
//
// Decorators are the persistence mechanism for the feature contract: emit
// `@FeatureOwned('<id>')` / `@FeatureContract(...)` comment anchors onto
// generated artifacts so the knowledge survives round-trips through
// hand-edits, re-generation, xray scans and slice compositions — without a
// separate registry that can rot. Slice computes "the minimal base for
// feature X" by READING decorators; xray groups the deck by the same
// annotations.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract_decorators.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_decorators_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('emit', () {
    test('ownedLine emits a single-line @FeatureOwned comment anchor', () {
      expect(
        FeatureContractDecorators.ownedLine('login'),
        "// @FeatureOwned('login')",
      );
    });

    test('contractHeader emits the full contract as comment anchors', () {
      final header = FeatureContractDecorators.contractHeader(
        FeatureContract(
          id: 'login',
          displayName: 'Login',
          entities: const ['User', 'Session'],
          routes: const {'/login', '/login/forgot'},
          xrayLayer: XRayLayer.presentation,
        ),
      );

      expect(header, contains("@FeatureContract(id: 'login')"));
      expect(header, contains("displayName: 'Login'"));
      expect(header, contains('entities: [User, Session]'));
      expect(header, contains('routes: [/login, /login/forgot]'));
      expect(header, contains('xrayLayer: presentation'));
      // Every line must be a comment anchor so the decorator survives Dart
      // formatting, hand-edits and codegen round-trips.
      for (final line in header.split('\n')) {
        if (line.trim().isEmpty) continue;
        expect(
          line.trimLeft().startsWith('//'),
          isTrue,
          reason: 'decorator lines must be comments, got: $line',
        );
      }
    });

    test('contractHeader omits unset surfaces', () {
      final header = FeatureContractDecorators.contractHeader(
        FeatureContract(id: 'logout', displayName: 'Logout'),
      );

      expect(header, contains("@FeatureContract(id: 'logout')"));
      expect(header, isNot(contains('entities:')));
      expect(header, isNot(contains('routes:')));
      expect(header, isNot(contains('xrayLayer:')));
    });
  });

  group('read', () {
    test('ownedFeatureOf extracts the feature id from a source file', () {
      const source = '''
// GENERATED — do not hand-edit above this line.
// @FeatureOwned('login')
class FakeLoginRepository {}
''';

      expect(FeatureContractDecorators.ownedFeatureOf(source), 'login');
    });

    test('ownedFeatureOf returns null without the anchor', () {
      expect(FeatureContractDecorators.ownedFeatureOf('class Foo {}'), isNull);
    });

    test('ownedFeatureOf reads the double-quoted form too', () {
      expect(
        FeatureContractDecorators.ownedFeatureOf('// @FeatureOwned("login")'),
        'login',
      );
    });

    test('scan groups artifact paths by owning feature id', () async {
      final loginDir = Directory(
        p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'login'),
      );
      await loginDir.create(recursive: true);
      await File(p.join(loginDir.path, 'user.dart')).writeAsString('''
// @FeatureOwned('login')
class User {}
''');

      final checkoutDir = Directory(
        p.join(workspace.path, 'lib', 'src', 'presentation', 'pages'),
      );
      await checkoutDir.create(recursive: true);
      await File(p.join(checkoutDir.path, 'checkout_view.dart')).writeAsString(
        '''
// @FeatureOwned('checkout')
class CheckoutView {}
''',
      );

      // A file with no decorator belongs to no feature.
      await File(
        p.join(workspace.path, 'lib', 'main.dart'),
      ).writeAsString('void main() {}\n');

      final grouped = FeatureContractDecorators.scan(workspace.path);

      expect(grouped.keys, containsAll(['login', 'checkout']));
      expect(
        grouped['login']!.where((f) => f.endsWith('user.dart')).isNotEmpty,
        isTrue,
      );
      expect(
        grouped['checkout']!.any((f) => f.endsWith('checkout_view.dart')),
        isTrue,
      );
      expect(
        grouped.values
            .expand((files) => files)
            .where((f) => f.endsWith('main.dart')),
        isEmpty,
      );
    });

    test(
      'scan is recursive and returns project-relative POSIX paths',
      () async {
        final deep = Directory(
          p.join(workspace.path, 'lib', 'src', 'a', 'b', 'c'),
        );
        await deep.create(recursive: true);
        await File(
          p.join(deep.path, 'deep.dart'),
        ).writeAsString("// @FeatureOwned('deep-feature')\nclass Deep {}\n");

        final grouped = FeatureContractDecorators.scan(workspace.path);

        expect(grouped['deep-feature'], hasLength(1));
        expect(grouped['deep-feature']!.single, 'lib/src/a/b/c/deep.dart');
      },
    );

    test('scan ignores non-dart files', () async {
      await File(
        p.join(workspace.path, 'notes.md'),
      ).writeAsString("// @FeatureOwned('login')\n");

      expect(FeatureContractDecorators.scan(workspace.path), isEmpty);
    });

    test(
      'groupFilesByFeature partitions a file list by owning feature',
      () async {
        final a = File(p.join(workspace.path, 'a.dart'))
          ..writeAsStringSync("// @FeatureOwned('login')\nclass A {}\n");
        final b = File(p.join(workspace.path, 'b.dart'))
          ..writeAsStringSync("// @FeatureOwned('checkout')\nclass B {}\n");

        final grouped = FeatureContractDecorators.groupFilesByFeature([
          a.path,
          b.path,
        ], root: workspace.path);

        expect(grouped['login'], hasLength(1));
        expect(grouped['checkout'], hasLength(1));
      },
    );
  });
}
