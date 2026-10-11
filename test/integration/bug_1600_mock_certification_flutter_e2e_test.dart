@Tags(['slow', 'integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';

/// Spec 1600 (issue #1600) — the mock certification loop honors a FLUTTER
/// host end to end, through the REAL CLI (`dart run bin/zfa.dart`) in a
/// throwaway Flutter-declaring project:
///
/// 1. `zfa mock create Login --certify` detects the Flutter host from the
///    pubspec, commits the contract test importing
///    `package:flutter_test/flutter_test.dart` (never plain package:test —
///    the #1600 load error), proves it in the sandbox with the FLUTTER
///    toolchain, and writes an all-satisfied receipt.
/// 2. The committed contract test passes under `flutter test` IN the host
///    project — the permanently-red test from the issue is gone.
/// 3. Interface drift still turns the certification honestly red (exit 3,
///    receipt records the failure) — the degradation path never masks a
///    real red.
/// 4. The create path without the Flutter SDK on PATH degrades honestly:
///    warning, no receipt, generation-governed exit (the spec-1110
///    precedent).
///
/// Skips honestly when no Flutter SDK is on PATH (CI dart lane). The
/// entity is hand-shaped like a zorphy-generated one (see the spec-1001
/// e2e) so no build_runner run is needed.
bool get _flutterAvailable => MockCertificationSandbox.flutterExecutableOnPath(
  Platform.environment['PATH'] ?? '',
);

void main() {
  late Directory tempProject;
  late String repoRoot;

  Future<ProcessResult> zfa(
    List<String> args, {
    Map<String, String>? environment,
    String? executable,
  }) {
    return Process.run(
      executable ??
          (environment == null ? 'dart' : Platform.resolvedExecutable),
      ['run', p.join(repoRoot, 'bin', 'zfa.dart'), ...args],
      workingDirectory: tempProject.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      environment: environment,
    );
  }

  setUp(() async {
    repoRoot = Directory.current.path;
    tempProject = await Directory.systemTemp.createTemp('zfa_1600_e2e_');
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
    // The HOST shape under test (#1600): a Flutter project. zuraffa rides
    // as a path dependency so the committed contract test resolves in the
    // host's own test runner.
    await File(p.join(tempProject.path, 'pubspec.yaml')).writeAsString('''
name: zfa_1600_flutter_host
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: $repoRoot
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
  });

  tearDown(() async {
    if (tempProject.existsSync()) {
      await tempProject.delete(recursive: true);
    }
  });

  test(
    'B9: a Flutter host gets a Flutter-shaped contract test, certified '
    'green through the flutter toolchain, and it passes under flutter '
    'test in the host',
    () async {
      // Materialize the host's package config (the sandbox resolves the
      // framework root through it).
      final pubGet = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: tempProject.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(
        pubGet.exitCode,
        0,
        reason: 'flutter pub get in the fixture\n${pubGet.stderr}',
      );

      final result = await zfa(['mock', 'create', 'Login', '--certify']);
      expect(
        result.exitCode,
        0,
        reason:
            'certification must succeed on a conforming mock\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('mock-cert: entity=Login'));

      final contractTest = File(
        p.join(
          tempProject.path,
          'test',
          'mock',
          'login',
          'login_mock_contract_test.dart',
        ),
      );
      expect(contractTest.existsSync(), isTrue);
      final source = await contractTest.readAsString();
      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the #1600 defect: the committed test must compile on the '
            'Flutter host',
      );
      expect(source, isNot(contains("import 'package:test/test.dart';")));

      final receipt =
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

      // And the host's own Flutter runner passes it — the permanently-red
      // suite from the issue is green.
      final host = await Process.run(
        'flutter',
        ['test', 'test/mock/login/login_mock_contract_test.dart'],
        workingDirectory: tempProject.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(
        host.exitCode,
        0,
        reason:
            'the committed contract test passes under the host '
            'runner\n${host.stdout}\n${host.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: _flutterAvailable ? false : 'Flutter SDK not available on PATH',
  );

  test(
    'B10: interface drift on a Flutter host stays honestly red',
    () async {
      final pubGet = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: tempProject.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(pubGet.exitCode, 0, reason: 'flutter pub get\n${pubGet.stderr}');

      final green = await zfa(['mock', 'create', 'Login', '--certify']);
      expect(green.exitCode, 0, reason: '${green.stdout}\n${green.stderr}');

      // Remove `get` from the generated interface — the committed Flutter-
      // shaped contract test must go red.
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
      final methods = (receiptAfterRed['methods'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        methods.any((m) => m['satisfied'] == false),
        isTrue,
        reason: 'the on-disk receipt honestly records the red state',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: _flutterAvailable ? false : 'Flutter SDK not available on PATH',
  );

  test('create --certify without the Flutter SDK degrades honestly: warning, '
      'no receipt, generation-governed exit', () async {
    // The stripped environment mirrors the real PATH minus every
    // `flutter*` executable: directories without flutter pass through,
    // a directory holding flutter is mirrored into the shim without
    // its flutter* files. The generation phase still finds dart; the
    // Flutter probe answers false for exactly the right reason.
    final shim = await Directory.systemTemp.createTemp('zfa_1600_shim_');
    final passthrough = <String>[];
    for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty || !Directory(dir).existsSync()) continue;
      final children = Directory(dir).listSync();
      final hasFlutter = children.any(
        (f) => p.basename(f.path).startsWith('flutter'),
      );
      if (!hasFlutter) {
        passthrough.add(dir);
        continue;
      }
      for (final f in children) {
        final name = p.basename(f.path);
        if (name.startsWith('flutter')) continue;
        final link = Link(p.join(shim.path, name));
        if (!link.existsSync()) {
          await link.create(f.path);
        }
      }
    }
    try {
      // A host without the Flutter SDK cannot have run `flutter pub
      // get` — but the degradation contract promises an exit governed
      // by the GENERATION gate, so resolve the package config as a
      // pure-Dart project first, then swap in the Flutter pubspec (the
      // generated mock subjects import only package:zuraffa + relatives,
      // so the structural gate analyzes cleanly).
      final pubspec = File(p.join(tempProject.path, 'pubspec.yaml'));
      final flutterPubspec = await pubspec.readAsString();
      await pubspec.writeAsString('''
name: zfa_1600_flutter_host
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');
      final resolve = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: tempProject.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(
        resolve.exitCode,
        0,
        reason: 'pure-Dart resolution\n${resolve.stderr}',
      );
      await pubspec.writeAsString(flutterPubspec);

      final result = await zfa(
        ['mock', 'create', 'Login', '--certify'],
        environment: {
          'PATH': '${shim.path}:${passthrough.join(':')}',
          'HOME': Platform.environment['HOME'] ?? '',
        },
        executable: p.join(shim.path, 'dart'),
      );
      expect(
        result.exitCode,
        0,
        reason:
            'an unrunnable environment proof is not a red contract\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('no flutter executable on PATH'));
      expect(
        result.stdout,
        contains('mock-cert.Login.json'),
        reason: 'the warning names the receipt that was NOT written',
      );
      expect(
        File(
          p.join(
            tempProject.path,
            'test',
            'mock',
            'login',
            'mock-cert.Login.json',
          ),
        ).existsSync(),
        isFalse,
        reason: 'no receipt lies about an unrun certification',
      );
    } finally {
      await shim.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
