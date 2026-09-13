/// The TDD profile's machine-readable keys — the ONE reader for every
/// command that resolves a setting from `.specify/memory/tdd-profile.md`.
///
/// The profile carries its keys in the `## Keys (machine-readable)` yaml
/// block `zfa setup` writes (`lib/src/cli/writers/tdd/tdd_profile_writer.dart`);
/// the legacy frontmatter block is the fallback, in the same order
/// [SingleTestRunner.loadSingleTemplate] resolves `single:`.
///
/// Issue #1472: the `analyze-gate:` key became load-bearing for TWO
/// commands — the make's #1407 errors-only gate and the refactor pass
/// registry's #1472 arm — so the lookup lives here instead of being copied
/// per command (two copies of the three-group scalar regex are exactly how
/// the readers drift apart).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'runner.dart';

abstract final class TddProfileKeys {
  /// The `analyze-gate:` strictness key: absent / `errors-only` (the
  /// default this codebase ships) tolerates a warnings-only analyze-gate
  /// refusal; `warnings-blocking` restores the legacy refusal (issues
  /// #1407, #1472).
  static const String analyzeGate = 'analyze-gate';

  /// The value of [key] in the profile at [workingDirectory], or null when
  /// the profile, its Keys block, or the key is absent — also null when the
  /// profile cannot be read. Quoted scalars are unwrapped; an unquoted
  /// scalar stops at whitespace or a `#` comment.
  static Future<String?> value(String workingDirectory, String key) async {
    final file = File(
      p.join(workingDirectory, SingleTestRunner.defaultProfilePath),
    );
    if (!await file.exists()) return null;
    final String raw;
    try {
      raw = await file.readAsString();
    } catch (_) {
      return null;
    }
    final keysBlock = RegExp(
      r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(raw);
    if (keysBlock != null) {
      final inKeys = _scalar(keysBlock.group(1)!, key);
      if (inKeys != null) return inKeys;
    }
    final frontmatter = RegExp(
      r'^---\n([\s\S]*?)\n---',
      dotAll: true,
    ).firstMatch(raw);
    return frontmatter == null ? null : _scalar(frontmatter.group(1)!, key);
  }

  /// Whether the project opted into the LEGACY warnings-blocking analyze
  /// gate (`analyze-gate: warnings-blocking`). The default — an absent key,
  /// an explicit `errors-only`, an unrecognized value, or a
  /// missing/unreadable profile — is errors-only (fail-open to the fix,
  /// never to the legacy refusal).
  static Future<bool> warningsBlocking(String workingDirectory) async =>
      (await value(workingDirectory, analyzeGate))?.trim().toLowerCase() ==
      'warnings-blocking';

  /// The [key] scalar in one profile yaml block, or null when the block
  /// does not carry the key. Quoted scalars are unwrapped — the same
  /// three-group shape [SingleTestRunner] uses for every profile value
  /// (the profile canonically quotes its keys).
  static String? _scalar(String block, String key) {
    final match = RegExp(
      "^\\s*${RegExp.escape(key)}:\\s*(?:\"(.+?)\"|'(.+?)'|([^\\s#]+))",
      multiLine: true,
    ).firstMatch(block);
    if (match == null) return null;
    for (var i = 1; i <= match.groupCount; i++) {
      final g = match.group(i);
      if (g != null && g.isNotEmpty) return g;
    }
    return null;
  }
}
