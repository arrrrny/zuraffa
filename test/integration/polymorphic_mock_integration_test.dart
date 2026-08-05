import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../regression/regression_test_utils.dart';
import '../helpers/project_root.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;
  late String zfaBin;
  late bool useCompiledBinary;

  setUpAll(() {
    final homeDir = Platform.environment['HOME'] ?? '';
    final compiledBin = p.join(homeDir, '.local', 'bin', 'zfa');
    final compiledExists = File(compiledBin).existsSync();

    if (compiledExists) {
      zfaBin = compiledBin;
      useCompiledBinary = true;
    } else {
      // Use findProjectRoot() instead of relative path (CWD may be poisoned).
      final projectRoot = findProjectRoot();
      zfaBin = p.join(projectRoot, 'bin', 'zfa.dart');
      useCompiledBinary = false;
    }
  });

  Future<ProcessResult> runZfa(List<String> args, {String? workingDirectory}) {
    if (useCompiledBinary) {
      return Process.run(zfaBin, args, workingDirectory: workingDirectory);
    }

    return Process.run('dart', [
      'run',
      zfaBin,
      ...args,
    ], workingDirectory: workingDirectory);
  }

  setUp(() async {
    workspace = await createWorkspace('polymorphic_mock');
    outputDir = workspace.outputDir;

    await writePubspec(workspace);

    // Clean up stale git index.lock files in pub-cache that can block
    // dependency resolution (e.g. git-based packages like zorphy).
    _cleanStaleGitLocks();

    final pubGet = await runFlutterPubGet(workspace);
    expect(
      pubGet.exitCode,
      equals(0),
      reason: '${pubGet.stdout}\n${pubGet.stderr}',
    );

    final fixturePath = p.join(
      findProjectRoot(),
      'test', 'fixtures', 'sealed_category_config.dart',
    );
    final fixtureContent = File(fixturePath).readAsStringSync();
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'category_config'),
    );
    await entityDir.create(recursive: true);
    await File(
      p.join(entityDir.path, 'category_config.dart'),
    ).writeAsString(fixtureContent);
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'zfa mock data generates compilable subtype mocks for sealed hierarchies',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final result = await runZfa([
        'mock',
        'data',
        'CategoryConfig',
        '--output',
        outputDir,
        '--force',
      ], workingDirectory: workspace.directory.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('Mock data generation complete for: CategoryConfig'),
      );

      final primaryMockFile = File(
        p.join(outputDir, 'data', 'mock', 'primary_category_mock_data.dart'),
      );
      final secondaryMockFile = File(
        p.join(outputDir, 'data', 'mock', 'secondary_category_mock_data.dart'),
      );
      final baseMockFile = File(
        p.join(outputDir, 'data', 'mock', 'category_config_mock_data.dart'),
      );

      expect(primaryMockFile.existsSync(), isTrue);
      expect(secondaryMockFile.existsSync(), isTrue);
      expect(baseMockFile.existsSync(), isFalse);

      final primaryContent = primaryMockFile.readAsStringSync();
      final secondaryContent = secondaryMockFile.readAsStringSync();

      expect(
        primaryContent,
        contains(
          "import '../../domain/entities/category_config/category_config.dart';",
        ),
      );
      expect(primaryContent, contains('PrimaryCategory('));
      expect(secondaryContent, contains('SecondaryCategory('));

      final analyze = await runDartAnalyze(workspace);
      expect(
        analyze.exitCode,
        equals(0),
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );
    },
  );
}

/// Remove stale `.git/index.lock` files from the pub-cache git directory.
///
/// These can be left behind by interrupted `dart pub get` / `git checkout`
/// operations and will block any subsequent dependency resolution for the
/// affected git package.
void _cleanStaleGitLocks() {
  try {
    final home = Platform.environment['HOME'] ?? '';
    final pubCache = Platform.environment['PUB_CACHE'] ??
        p.join(home, '.pub-cache');
    final gitDir = Directory(p.join(pubCache, 'git'));
    if (!gitDir.existsSync()) return;

    for (final entry in gitDir.listSync()) {
      if (entry is! Directory) continue;
      final lock = File(p.join(entry.path, '.git', 'index.lock'));
      if (lock.existsSync()) {
        lock.deleteSync();
      }
    }
  } catch (_) {
    // Best-effort cleanup - never block the test.
  }
}
