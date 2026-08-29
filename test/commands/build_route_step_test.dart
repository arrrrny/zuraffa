import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/build_command.dart';

void writeFile(String root, String relative, String content) {
  final file = File('$root/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_build_route_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('BuildCommand.compileRouteAnnotations (zfa build pre-step)', () {
    test('success: writes artifacts and returns 0', () async {
      writeFile(tempDir.path, 'pubspec.yaml', 'name: test_app\n');
      writeFile(
        tempDir.path,
        'lib/home_view.dart',
        '@Route(path: \'/home\')\nclass HomeView {}\n',
      );

      final lines = <String>[];
      final code = await BuildCommand.compileRouteAnnotations(
        tempDir.path,
        printFn: lines.add,
      );

      expect(code, 0);
      expect(
        File('${tempDir.path}/lib/src/routing/zfa_router.g.dart').existsSync(),
        true,
      );
      expect(lines.join('\n'), contains('route'));
    });

    test('validation failure: returns 1 and prints every error', () async {
      writeFile(tempDir.path, 'pubspec.yaml', 'name: test_app\n');
      writeFile(
        tempDir.path,
        'lib/a_view.dart',
        '@Route(path: \'/dupe\')\nclass AView {}\n',
      );
      writeFile(
        tempDir.path,
        'lib/b_view.dart',
        '@Route(path: \'/dupe\')\nclass BView {}\n',
      );

      final lines = <String>[];
      final code = await BuildCommand.compileRouteAnnotations(
        tempDir.path,
        printFn: lines.add,
      );

      expect(code, 1, reason: 'route validation failure must fail the build');
      final output = lines.join('\n');
      expect(output, contains('AView'));
      expect(output, contains('BView'));
      expect(output.toLowerCase(), contains('error'));
    });

    test('zero annotations + no stale router: no-op returning 0', () async {
      writeFile(tempDir.path, 'pubspec.yaml', 'name: test_app\n');
      writeFile(tempDir.path, 'lib/main.dart', 'void main() {}\n');

      final lines = <String>[];
      final code = await BuildCommand.compileRouteAnnotations(
        tempDir.path,
        printFn: lines.add,
      );

      expect(code, 0);
      expect(
        File('${tempDir.path}/lib/src/routing/zfa_router.g.dart').existsSync(),
        false,
      );
    });
  });
}
