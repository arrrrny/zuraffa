@Tags(['slow', 'integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec 1009 (issue #1009) — the end-to-end differential gate proof,
/// driven through the REAL CLI (`dart run bin/zfa.dart`) in a throwaway
/// project:
///
/// 1. `zfa mock create Login --certify` establishes the Tier-1 side (the
///    committed contract test + receipt).
/// 2. `zfa tdd realize-mock Login --against=firestore` runs the same
///    contract against the Tier-1 mock AND a generated Firestore-shaped
///    Tier-2 provider (fake FirebaseFirestore), compares per-method
///    outcomes, writes realize.Login.firestore.receipt.json, and exits 0
///    with a clean receipt.
/// 3. `--diverge get` (the chaos hook: the Tier-2 adapter returns a
///    wrong-typed value) exits 1 with the mismatched method named.
/// 4. The receipt is machine-readable and verified by `zfa proof check`.
void main() {
  late Directory tempProject;
  late String repoRoot;

  setUp(() async {
    tempProject = await Directory.systemTemp.createTemp('zfa_1009_e2e_');
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

  Future<({int exitCode, String stdout, String stderr})> zfa(
    List<String> args,
  ) async {
    final proc = await Process.run(
      'dart',
      [p.join(repoRoot, 'bin', 'zfa.dart'), ...args],
      workingDirectory: tempProject.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return (
      exitCode: proc.exitCode,
      stdout: '${proc.stdout}',
      stderr: '${proc.stderr}',
    );
  }

  test(
    'clean differential: exit 0, per-method receipt, proof check verifies',
    () async {
      final certified = await zfa(['mock', 'create', 'Login', '--certify']);
      expect(
        certified.exitCode,
        0,
        reason: '${certified.stdout}\n${certified.stderr}',
      );

      final result = await zfa([
        'tdd',
        'realize-mock',
        'Login',
        '--against=firestore',
      ]);

      expect(
        result.exitCode,
        0,
        reason:
            'the clean differential must certify\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('differential gate pass'));
      expect(result.stdout, contains('result=certified'));

      final receiptFile = File(
        p.join(
          tempProject.path,
          'test',
          'mock',
          'login',
          'realize.Login.firestore.receipt.json',
        ),
      );
      expect(receiptFile.existsSync(), isTrue);
      final receipt =
          jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;
      expect(receipt['spec'], 1009);
      expect(receipt['entity'], 'Login');
      expect(receipt['against'], 'firestore');
      expect(receipt['result'], 'certified');
      final methods = (receipt['methods'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(methods, isNotEmpty);
      for (final method in methods) {
        expect(method['tier1_result'], 'pass');
        expect(method['tier2_result'], 'pass');
        expect(method['diff'], 'none');
      }
      expect((receipt['divergence'] as List<dynamic>), isEmpty);

      // Machine-readable + parseable by zfa proof check: the #807
      // generation receipt covers the differential receipt's bytes.
      final proof = await zfa(['proof', 'check']);
      expect(proof.exitCode, 0, reason: proof.stdout);
      expect(proof.stdout, contains('OK'));
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test('divergent tier-2 method: exit 1 with the method named', () async {
    final certified = await zfa(['mock', 'create', 'Login', '--certify']);
    expect(
      certified.exitCode,
      0,
      reason: '${certified.stdout}\n${certified.stderr}',
    );

    final result = await zfa([
      'tdd',
      'realize-mock',
      'Login',
      '--against=firestore',
      '--diverge=get',
    ]);

    expect(
      result.exitCode,
      1,
      reason:
          'a divergent method must fail the gate\n'
          '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('MISMATCH'));
    expect(result.stdout, contains('get'));
    expect(result.stdout, contains('result=mismatch'));

    final receiptFile = File(
      p.join(
        tempProject.path,
        'test',
        'mock',
        'login',
        'realize.Login.firestore.receipt.json',
      ),
    );
    final receipt =
        jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;
    expect(receipt['result'], 'mismatch');
    expect(receipt['divergence'], ['get']);
    final get = (receipt['methods'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((m) => m['method'] == 'get');
    expect(get['tier1_result'], 'pass');
    expect(get['tier2_result'], 'fail');
    expect(get['diff'], 'mismatch');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
