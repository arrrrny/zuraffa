/// The ratified zfa exit-code protocol (SPEC 917, issue #917 absorbing
/// #839/#778; VISION §3 + §4 made mechanical).
///
/// VISION §4: "Exit codes become a protocol: 0 success, 1 test RED,
/// 2 invalid grammar, 3 manifest drift, 4 state conflict. Every error
/// message ends with a machine-actionable line: `--> fix: ...`. The agent
/// never parses prose. It parses verdicts."
///
/// ## The golden table
///
/// | code | name    | meaning                                                                 |
/// |------|---------|-------------------------------------------------------------------------|
/// | 0    | success | GREEN / complete — the operation ran and everything passed               |
/// | 1    | failure | RED (honest, expected in-loop) / stopped / audit failure / runtime       |
/// |      |         | failure — the operation ran and gave an honest negative verdict; the     |
/// |      |         | JSON verdict's `exit_class` distinguishes the sub-flavor                 |
/// | 2    | usage   | the operation could NOT run as invoked — grammar/usage error, unknown    |
/// |      |         | flag or subcommand, missing required arguments, invalid invocation       |
/// |      |         | target, or runner-infrastructure error (legacy 64 maps here)             |
/// | 3    | drift   | contract/spec drift — manifest ↔ CLI flag drift, template-version        |
/// |      |         | drift, traceability drift, corrupt state evidence                        |
/// | 4    | conflict| state conflict — concurrent run ownership, evidence lock inconsistency   |
///
/// ## Legacy codes
///
/// * `64` (EX_USAGE) — the pre-protocol usage error. Mapped onto canonical
///   `2` by [canonicalize]; new code must use [usage] directly.
/// * `255`, `-9`, `137` — external termination signals (OOM killer, shell
///   limits). Never emitted by zfa itself; not part of the protocol.
///
/// The table is asserted by `test/commands/exit_protocol_golden_test.dart`
/// (constants + live CLI behavior) and printed by `zfa --help` and
/// `zfa schema` — asserted in CI by `.github/workflows/conformance.yml`.
library;

/// The ratified exit-code protocol: canonical codes, legacy mapping, and
/// the machine-actionable `fix:` line convention (errors are an API).
abstract final class ExitProtocol {
  /// `0` — success / GREEN / complete.
  static const int success = 0;

  /// `1` — RED (honest, expected in-loop) / stopped / audit failure /
  /// runtime failure. Distinguished by the JSON verdict's `exit_class`.
  static const int failure = 1;

  /// `2` — usage/grammar error: the operation could not run as invoked.
  /// Canonical home of the legacy `64`.
  static const int usage = 2;

  /// `3` — contract/spec drift (manifest ↔ CLI, template-version,
  /// traceability, corrupt state evidence).
  static const int drift = 3;

  /// `4` — state conflict (concurrent run ownership, evidence locks).
  static const int conflict = 4;

  /// The legacy EX_USAGE code every pre-protocol usage path exited with.
  /// Recognized only as an input to [canonicalize]; never emit it.
  static const int legacyUsage = 64;

  /// Maps a legacy exit code onto its canonical protocol code.
  ///
  /// `64` (EX_USAGE) → [usage]. Unknown codes pass through unchanged.
  static int canonicalize(int legacy) => switch (legacy) {
    legacyUsage => usage,
    _ => legacy,
  };

  /// The machine-actionable fix line every non-zero exit ends with
  /// (VISION §4: errors are an API, not an apology).
  static String fixLine(String fix) => '--> fix: $fix';

  /// The golden table, printed verbatim by `zfa --help` (EXIT CODES
  /// section) and embedded in `zfa schema`. The golden test greps these
  /// exact row prefixes.
  static const String tableDoc = '''
0  success   GREEN / complete - the operation ran and passed
1  failure   RED (honest, in-loop) / stopped / audit failure
             (distinguished by the JSON verdict's exit_class)
2  usage     the operation could not run as invoked - grammar error,
             unknown flag/subcommand, missing args, invalid target,
             runner-infrastructure error (legacy 64 maps here)
3  drift     contract/spec drift - manifest <-> CLI flag drift,
             template-version drift, traceability drift, corrupt state
4  conflict  state conflict - concurrent run ownership, evidence lock
             inconsistency''';
}
