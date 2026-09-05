@Tags(['slow', 'integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec 1001 (issue #1001) — the end-to-end certification proof, driven
/// through the REAL CLI (`dart run bin/zfa.dart`) in a throwaway project:
///
/// 1. `zfa mock create Login --certify` generates the mock, runs the
///    auto-generated contract test in a temp sandbox (dart analyze +
///    dart test), and writes `mock-cert.Login.json` with every method
///    `satisfied: true` and the contract digest.
/// 2. Removing a method from the repository interface makes the
///    committed contract test fail to compile — `zfa mock certify` goes
///    red (exit 3) and the receipt honestly records the failure.
/// 3. `zfa mock certify <Entity>` registers the mock in the #832
///    fixture registry entry (manifest `mocks` provenance + the receipt
///    hashed into the world digest + `kind: mock-cert` cycle evidence).
///
/// The subject entity is hand-shaped like a zorphy-generated one (the
/// generated mock stack calls `copyWithField` and `<E>Patch.applyTo`)
/// so no build_runner run is needed in the fixture project.
void main() {
  late Directory tempProject;
  late String repoRoot;

  setUp(() async {
    tempProject = await Directory.systemTemp.createTemp('zfa_1001_e2e_');
    repoRoot = Directory.current.path;
    final entityDir = Directory(
      p.join(tempProject.path, 'lib', 'src', 'domain', 'entities', 'login'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'login.dart')).writeAsString('''
import 'package:zuraffa/mock.dart';

class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});

  Login copyWith({String? id, String? username}) => Login(
        id: id ?? this.id,
        username: username ?? this.username,
      );

  Login copyWithField(Field<Login, dynamic> field, dynamic value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'username':
        return copyWith(username: value as String);
      default:
        throw ArgumentError.value(field.name, 'field');
    }
  }
}

class LoginPatch {
  Login applyTo(Login entity) => entity;
}
''');
  });

  tearDown(() async {
    if (tempProject.existsSync()) {
      await tempProject.delete(recursive: true);
    }
  });

  Future<ProcessOutput> zfa(List<String> args) async {
    final proc = await Process.run(
      'dart',
      ['run', p.join(repoRoot, 'bin', 'zfa.dart'), ...args],
      workingDirectory: tempProject.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return ProcessOutput(proc.exitCode, '${proc.stdout}', '${proc.stderr}');
  }

  test(
    'zfa mock create Login --certify: contract green + receipt all true',
    () async {
      final result = await zfa(['mock', 'create', 'Login', '--certify']);

      expect(
        result.exitCode,
        0,
        reason:
            'certification must succeed on a conforming mock\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('mock-cert: entity=Login'));

      final receiptFile = File(
        p.join(
          tempProject.path,
          'test',
          'mock',
          'login',
          'mock-cert.Login.json',
        ),
      );
      expect(
        receiptFile.existsSync(),
        isTrue,
        reason: 'the mock-cert.Login.json receipt is written',
      );
      final receipt =
          jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;
      expect(receipt['spec'], 1001);
      expect(receipt['entity'], 'Login');
      expect(receipt['contract_digest'], isA<String>());
      final methods = (receipt['methods'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(methods, isNotEmpty);
      for (final method in methods) {
        expect(
          method['satisfied'],
          isTrue,
          reason: '${method['name']} must be satisfied',
        );
      }

      final contractTest = File(
        p.join(
          tempProject.path,
          'test',
          'mock',
          'login',
          'login_mock_contract_test.dart',
        ),
      );
      expect(
        contractTest.existsSync(),
        isTrue,
        reason: 'the auto-generated contract test is committed',
      );
      final source = await contractTest.readAsString();
      expect(source, contains('final LoginDataSource dataSource ='));
      expect(source, contains('dataSource.get;'));
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    'zfa mock create Login --seed=42 replays byte-identical mocks',
    () async {
      final dirB = await Directory.systemTemp.createTemp('zfa_1001_seed_');
      try {
        final first = await zfa(['mock', 'create', 'Login', '--seed=42']);
        expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');

        final secondProject = dirB.path;
        await Directory(
          p.join(secondProject, 'lib', 'src', 'domain', 'entities', 'login'),
        ).create(recursive: true);
        await File(
          p.join(
            secondProject,
            'lib',
            'src',
            'domain',
            'entities',
            'login',
            'login.dart',
          ),
        ).writeAsString(
          await File(
            p.join(
              tempProject.path,
              'lib',
              'src',
              'domain',
              'entities',
              'login',
              'login.dart',
            ),
          ).readAsString(),
        );
        final second = await Process.run('dart', [
          'run',
          p.join(repoRoot, 'bin', 'zfa.dart'),
          'mock',
          'create',
          'Login',
          '--seed=42',
        ], workingDirectory: secondProject);
        expect(second.exitCode, 0);

        for (final rel in [
          'lib/src/data/mock/login_mock_data.dart',
          'lib/src/data/datasources/login/login_datasource.dart',
          'lib/src/data/datasources/login/login_mock_datasource.dart',
        ]) {
          final a = await File(p.join(tempProject.path, rel)).readAsString();
          final b = await File(p.join(secondProject, rel)).readAsString();
          expect(a, b, reason: '$rel must be byte-identical across runs');
        }
        // And the records derive from the seed.
        final mockData = await File(
          p.join(
            tempProject.path,
            'lib',
            'src',
            'data',
            'mock',
            'login_mock_data.dart',
          ),
        ).readAsString();
        expect(mockData, contains("Login(id: 'id 42',"));
      } finally {
        await dirB.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test('interface drift: removing a method turns the certification red '
      '(live) and zfa mock certify registers the green one in the #832 '
      'registry', () async {
    // Establish the green certification first.
    final green = await zfa(['mock', 'create', 'Login', '--certify']);
    expect(green.exitCode, 0, reason: '${green.stdout}\n${green.stderr}');

    // 1. Remove `get` from the repository interface — the committed
    //    contract test must go red.
    final interface = File(
      p.join(
        tempProject.path,
        'lib',
        'src',
        'data',
        'datasources',
        'login',
        'login_datasource.dart',
      ),
    );
    final drifted = (await interface.readAsString()).replaceFirst(
      RegExp(r'\s*Future<Login> get\(QueryParams<Login> params\);'),
      '',
    );
    await interface.writeAsString(drifted);

    final red = await zfa(['mock', 'certify', 'Login']);
    expect(
      red.exitCode,
      3,
      reason:
          'a drifted contract must refuse certification\n'
          '${red.stdout}\n${red.stderr}',
    );
    expect(red.stderr, contains('interface drift'));

    // The on-disk receipt honestly records the red state (the
    // run-engine gate reads it).
    final receiptAfterRed =
        jsonDecode(
              await File(
                p.join(
                  tempProject.path,
                  'test',
                  'mock',
                  'login',
                  'mock-cert.Login.json',
                ),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final methodsAfterRed = (receiptAfterRed['methods'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(methodsAfterRed.any((m) => m['satisfied'] == false), isTrue);

    // 2. Restore the interface, re-certify, and REGISTER in the #832
    //    fixture registry.
    final restored = await zfa([
      'mock',
      'create',
      'Login',
      '--certify',
      '--force',
    ]);
    expect(
      restored.exitCode,
      0,
      reason: '${restored.stdout}\n${restored.stderr}',
    );

    final fixturesDir = p.join(
      tempProject.path,
      'specs',
      '1001-e2e',
      'tdd',
      'fixtures',
    );
    await Directory(fixturesDir).create(recursive: true);
    await File(
      p.join(fixturesDir, 'seed.json'),
    ).writeAsString('{"seed": true}\n');

    final registered = await zfa([
      'mock',
      'certify',
      'Login',
      '--fixtures-dir',
      p.relative(fixturesDir, from: tempProject.path),
    ]);
    expect(
      registered.exitCode,
      0,
      reason: '${registered.stdout}\n${registered.stderr}',
    );
    expect(registered.stdout, contains('registered=true'));

    final manifest =
        jsonDecode(
              await File(p.join(fixturesDir, 'manifest.json')).readAsString(),
            )
            as Map<String, dynamic>;
    expect(manifest['mocks'], ['Login']);
    expect(
      (manifest['files'] as Map<String, dynamic>).containsKey(
        'mock-cert.Login.json',
      ),
      isTrue,
      reason: 'the receipt is hashed into the #832 world digest',
    );

    final cycleLog = await File(
      p.join(tempProject.path, 'specs', '1001-e2e', 'tdd', 'cycle-log.md'),
    ).readAsString();
    expect(cycleLog, contains('kind: mock-cert'));
    expect(cycleLog, contains('behavior: 1001-e2e-mock-cert-login'));
  }, timeout: const Timeout(Duration(minutes: 8)));
}

class ProcessOutput {
  const ProcessOutput(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout;
  final String stderr;
}
