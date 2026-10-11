// Issue #1371 — `StepRunner.resolveEntrypoint` tier 1 returned
// `Platform.script` verbatim whenever its basename was zfa.dart /
// zuraffa.dart — WITHOUT an existence check (tiers 2/4/5 all check).
// Under the CLI's own global `-C <dir>` flag the scoped chdir re-anchors
// the relative launch arg (`bin/zfa.dart`) against the NEW cwd, so the
// tier-1 path names a file that does not exist and every step spawn dies
// with a Dart VM exit 254 (`Error when reading '<chdir>/bin/zfa.dart'`).
//
// Fix under test (spec 1371-step-entrypoint-existence): tier 1 applies
// the same existence check the other tiers use — a phantom script falls
// through to the package-path tier, which resolves via the VM's package
// config and is immune to the chdir.
//
// Behaviors:
//   B1 — a re-anchored (non-existent) zfa.dart script falls through to
//        the package tier (the -C repro).
//   B2 — an existing zfa.dart script is still returned verbatim (guard).
//   B3 — a phantom script with NOTHING resolvable still throws the
//        honest cannot-resolve error (no phantom path ever returned).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('zfa-1371');
    // The package-tier layout the injected resolver points at:
    // <tmp>/pkg/lib/src/zfa_cli.dart + <tmp>/pkg/bin/zfa.dart.
    final cli = File(p.join(tmpDir.path, 'pkg', 'lib', 'src', 'zfa_cli.dart'))
      ..createSync(recursive: true);
    cli.writeAsStringSync('// fixture\n');
    final binFile = File(p.join(tmpDir.path, 'pkg', 'bin', 'zfa.dart'));
    binFile.parent.createSync(recursive: true);
    binFile.writeAsStringSync('// fixture entrypoint\n');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<Uri?> packageResolver(Uri packageUri) async {
    // Mirrors Isolate.resolvePackageUri against the fixture package.
    return Uri.file(p.join(tmpDir.path, 'pkg', 'lib', 'src', 'zfa_cli.dart'));
  }

  test('B1: a re-anchored (phantom) zfa.dart script falls through to the '
      'package tier — the -C repro', () async {
    // The launch arg `bin/zfa.dart` re-anchored against the -C chdir:
    // the file does NOT exist there.
    final phantom = Uri.file(p.join(tmpDir.path, 'example', 'bin', 'zfa.dart'));
    expect(
      File(phantom.toFilePath()).existsSync(),
      isFalse,
      reason: 'precondition: the re-anchored script does not exist',
    );

    final bin = await StepRunner.resolveEntrypoint(
      script: phantom,
      resolvedExecutable: '/usr/bin/dart',
      environment: const {'PATH': '/usr/bin:/bin'},
      resolvePackageUri: packageResolver,
    );

    expect(
      bin,
      p.join(tmpDir.path, 'pkg', 'bin', 'zfa.dart'),
      reason:
          'the package tier resolves via the package config, '
          'immune to the chdir',
    );
    expect(File(bin).existsSync(), isTrue);
  });

  test('B2: an existing zfa.dart script is still returned verbatim', () async {
    final real = File(p.join(tmpDir.path, 'pkg', 'bin', 'zfa.dart'));

    final bin = await StepRunner.resolveEntrypoint(
      script: Uri.file(real.path),
      resolvedExecutable: '/usr/bin/dart',
      environment: const {'PATH': '/usr/bin:/bin'},
      resolvePackageUri: packageResolver,
    );

    expect(bin, real.path);
  });

  test('B3: a phantom script with nothing resolvable still throws the '
      'honest cannot-resolve error', () async {
    final phantom = Uri.file(p.join(tmpDir.path, 'example', 'bin', 'zfa.dart'));

    await expectLater(
      StepRunner.resolveEntrypoint(
        script: phantom,
        resolvedExecutable: '/usr/bin/dart',
        environment: const {'PATH': ''},
        resolvePackageUri: (uri) async => null,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('cannot resolve the zfa entrypoint'),
        ),
      ),
      reason: 'no phantom path is ever returned as a spawn entrypoint',
    );
  });
}
