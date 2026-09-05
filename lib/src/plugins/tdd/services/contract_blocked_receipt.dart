/// `ContractBlockedReceipt` — the distinct BLOCKED receipt for a failing
/// contract test (issue #1007): `contract-blocked.<id>.json`.
///
/// A failing contract test is BLOCKED, not RED: it proves a declared
/// contract is unsatisfied, so it writes NO red evidence into the cycle
/// log (there is nothing to certify — the implementation, not the test,
/// is incomplete) and instead persists this receipt through the existing
/// [ReceiptStore] machinery, keyed by the stable per-behavior name
/// `contract-blocked.<id>` so a re-run supersedes the previous proof
/// (latest-wins, the same contract as the #970 mock-certification
/// receipts).
///
/// The id's `:` sanitizes per the portable receipt naming rules
/// (`contract:A1` -> `contract-blocked.contract_A1.json`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../../../core/project/receipt_store.dart';

class ContractBlockedReceipt {
  const ContractBlockedReceipt({required this.projectRoot});

  final String projectRoot;

  /// The sanitized receipt file name for [behaviorId]
  /// (`contract-blocked.<id>.json` with the `:` folded to `_`).
  static String fileNameFor(String behaviorId) =>
      'contract-blocked.${behaviorId.replaceAll(':', '_')}.json';

  /// The absolute receipt path for [behaviorId].
  String pathFor(String behaviorId) {
    final store = ReceiptStore(projectRoot: projectRoot);
    return store.directory.path.isNotEmpty
        ? '${store.directory.path}/${fileNameFor(behaviorId)}'
        : fileNameFor(behaviorId);
  }

  /// Write the blocked receipt for [behaviorId]: a `proof.v1`
  /// [GenerationReceipt] carrying the blocked classification, the
  /// failing cases, and the run transcript digest, plus the
  /// #1007-specific extra fields (behavior, feature, classification,
  /// cases) merged on top of the proof payload.
  Future<File> write({
    required String behaviorId,
    required String feature,
    required String testPath,
    required String command,
    required int exitCode,
    required String output,
    List<String> cases = const [],
  }) async {
    final transcriptDigest = crypto.sha256
        .convert(utf8.encode(output))
        .toString();
    final receipt = GenerationReceipt(
      command: 'tdd verify-red',
      target: behaviorId,
      repro: 'zfa tdd verify-red $behaviorId --feature $feature',
      at: DateTime.now().toUtc(),
      generatorVersion: '6.1.0',
      input: {
        'behavior': behaviorId,
        'feature': feature,
        'classification': 'blocked',
        if (cases.isNotEmpty) 'cases': cases,
        'exit': exitCode,
        'transcript_sha256': transcriptDigest,
      },
      files: [
        GenerationReceiptFile(
          path: _relativePosix(testPath),
          action: 'read',
          sha256: await _digestOf(testPath),
          bytes: await _bytesOf(testPath),
        ),
      ],
    );
    return ReceiptStore(projectRoot: projectRoot).saveNamed(
      fileNameFor(behaviorId),
      receipt,
      extra: {
        'behavior': behaviorId,
        'feature': feature,
        'classification': 'blocked',
        if (cases.isNotEmpty) 'cases': cases,
      },
    );
  }

  /// The unsatisfied cases named by the blocked transcript (issue #1007):
  /// the generated contract test's failure reason enumerates the
  /// unsatisfied claims (`contract case(s) unsatisfied: X; Y`); when the
  /// reason is unparseable, the `[E]`-marked test descriptions stand in.
  /// Empty when the transcript carries no parseable case identity.
  static List<String> casesOf(String output) {
    final claims = RegExp(
      r'contract case\(s\) unsatisfied: (.+?)(?:\s*—|$)',
    ).allMatches(output);
    final parsed = <String>[];
    for (final match in claims) {
      for (final claim in (match.group(1) ?? '').split(';')) {
        final trimmed = claim.trim();
        if (trimmed.isNotEmpty && trimmed != '(none enumerated)') {
          parsed.add(trimmed);
        }
      }
    }
    if (parsed.isNotEmpty) return parsed;
    final cases = <String>[];
    for (final match in RegExp(
      r'^\d\d:\d\d \+\d+(?: -\d+)?: (.+) \[E\]$',
      multiLine: true,
    ).allMatches(output)) {
      final name = match.group(1)?.trim() ?? '';
      if (name.isEmpty || name.startsWith('loading ')) continue;
      cases.add(name);
    }
    return cases;
  }

  Future<String> _digestOf(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return crypto.sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  Future<int> _bytesOf(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  String _relativePosix(String filePath) => filePath.replaceAll('\\', '/');
}
