import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Issue #767 — the systemic ❌-and-0 contract at the PROCESS boundary.
///
/// `SliceCommand` records its outcome in an instance field
/// (`command.exitCode`, asserted by the INV-1 suite) and its failure paths
/// (`_printMergeResult`, `verify`, `export`) all assign it on capability
/// failure — but the field SHADOWS dart:io's global `exitCode` inside the
/// class, so nothing publishes the failure to the process. `CliRunner.
/// _runDispatched` exits with the GLOBAL, and the real binary was
/// empirically exiting 0 for every failed slice capability:
///
///   zfa slice merge DoesNotExist                  → exit 0  (bug)
///   zfa slice verify DoesNotExist                 → exit 0  (bug)
///   zfa slice export DoesNotExist --format tar.gz → exit 0  (bug)
///   zfa slice teleport (usage error)              → exit 64 (ok)
///
///   FR-1: a failed slice capability (merge/verify/export) must exit 1 at
///         the process boundary — the instance outcome must be published
///         to dart:io's `exitCode` when `run()` completes.
///   FR-2: usage errors keep exiting 64 and successes keep exiting 0
///         (regression pins, driven through the same boundary).
void main() {
  /// Runs the slice invocation through the real runner and returns the
  /// process exit code the boundary would honor (dart:io global).
  Future<(String, int)> runSlice(List<String> args) async {
    exitCode = 0;
    final output = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['slice', ...args]);
    final code = exitCode;
    exitCode = 0; // hermetic: never leak a failure code into the suite
    return (output, code);
  }

  test('FR-1a — merge failure exits 1 at the process boundary', () async {
    final (output, code) = await runSlice(['merge', 'DoesNotExist']);
    expect(output, contains('No slice named "DoesNotExist" found'));
    expect(
      code,
      equals(1),
      reason:
          'the merge failed but the process reported success — the '
          'instance-field outcome is never published to dart:io '
          'exitCode (#767)',
    );
  });

  test('FR-1b — verify failure exits 1 at the process boundary', () async {
    final (output, code) = await runSlice(['verify', 'DoesNotExist']);
    expect(output, contains('No slice named "DoesNotExist" found'));
    expect(code, equals(1));
  });

  test('FR-1c — export failure exits 1 at the process boundary', () async {
    final (_, code) = await runSlice([
      'export',
      'DoesNotExist',
      '--format',
      'tar.gz',
    ]);
    expect(code, equals(1));
  });

  test('FR-2a — unknown subcommand keeps exiting 64 (usage family)', () async {
    final (_, code) = await runSlice(['teleport']);
    expect(code, equals(64));
  });

  test('FR-2b — slice list success keeps exiting 0', () async {
    final (_, code) = await runSlice(['list']);
    expect(code, equals(0));
  });
}
