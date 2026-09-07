/// Behavior entity for the `zfa tdd` plugin.
library;

import '../services/finder_taxonomy.dart';

/// The subject kind a behavior's paired test + subject express.
///
/// `widget` (bug #830): the behavior's acceptance scenario is UI-observable
/// ("renders the brand theme", "sidebar on macOS") and cannot be expressed
/// by a plain-function subject. Its pair is a view-builder subject stub +
/// a `testWidgets` test that pumps the view and asserts the scenario —
/// the only shape whose green measures the UI.
///
/// `theme` (bug #841): a behavior declared in a `## Theme harness` section
/// (or with a `theme` kind cell) whose gen pair is the theme-harness widget
/// test + subject contract — see `ThemeHarnessTestWriter` /
/// `ThemeHarnessSubjectWriter`.
///
/// `ffi` (bug #835): marks a NATIVE-BOUNDARY behavior: its subject is an
/// FFI binding contract (symbols resolved, marshalling round-trip) and
/// its golden fixture assertion runs in the marked integration lane —
/// declared by hand in the test list, never derived from spec prose.
///
/// `platform` (issue #831): a behavior declared in a `## Platform harness`
/// section (or with a `platform` kind cell) whose subject sits on a
/// platform channel (camera, barcode, permissions, notifications,
/// location). Its gen pair is a channel test that installs the certified
/// fake (`zfa tdd fake`) and asserts on the OBSERVED calls — arguments
/// recorded, ordering preserved — plus a channel-calling subject stub.
///
/// `contract` (issue #1007): a CONTRACT behavior — one declared entity
/// method, controller method or usecase of the spec's Layer Contracts
/// section, planned by `zfa tdd plan` as a `contract:<id>` row under the
/// `## Contract loop:` section. Unlike every other kind its pair proves
/// the implementation satisfies a DECLARED contract, not that a piece of
/// code does what its author said: `zfa tdd gen` emits a contract test
/// scaffold that enumerates the contract's cases plus a contract seam
/// subject, and a failing contract test is graded BLOCKED (never RED) by
/// `zfa tdd verify-red` — the substrate for `zfa dream`, where generated
/// and hand-written code are graded by the same rules.
enum BehaviorKind { acceptance, unit, widget, theme, ffi, platform, contract }

/// The per-behavior cycle state the run driver advances through.
///
/// `blocked` (issue #1007): a CONTRACT behavior whose contract test
/// failed — the declared contract is NOT satisfied by the implementation.
/// Distinct from RED on purpose: RED is the honest first state of a unit
/// or widget behavior (the TDD loop EXPECTS the failing test and proceeds
/// to make/GREEN); BLOCKED refuses to proceed — the cycle cannot reach
/// GREEN until the implementation satisfies the declared contract. The
/// verdict carries its own receipt (`contract-blocked.<id>.json`) and the
/// corpus-economics gap ledger records the stop at the highest severity.
enum BehaviorState { pending, blocked, red, green, mocked, done }

class Behavior {
  final String id;
  final String feature;
  final BehaviorKind kind;
  final String description;
  final String sourceCriterion;
  final String target;
  BehaviorState state;

  /// Whether the behavior touches Hive-backed persistence (bug #833). The
  /// plan marks the behavior with the ` [persistence]` tag in the test
  /// list; `zfa tdd gen` turns the mark into a harness-backed test (fresh
  /// temp-directory box set per test, injected test clock, corruption
  /// drill + registrar gate surfaces).
  final bool persistence;

  /// The test-list row's declared finder kinds (issue #1140) — the plan
  /// table's `kind` cell for widget rows, carried through gen so the
  /// emitted assertion templates are the DECLARED ones and a drifted
  /// column is refused. Null = the row carries no kind column (legacy
  /// 4-column lists); empty = the plan declared `none`; non-empty = a
  /// declared contract. `zfa tdd gen` reconciles it against the
  /// description-derived prediction for widget rows.
  final List<ScenarioAssertionClass>? finderKinds;

  Behavior({
    required this.id,
    required this.feature,
    required this.kind,
    required this.description,
    required this.sourceCriterion,
    required this.target,
    this.persistence = false,
    this.golden = false,
    this.state = BehaviorState.pending,
    this.finderKinds,
  });

  /// Whether the test-list row declared the behavior golden-gated (bug
  /// #1261): the ` [golden]` tag a SKIN lane plan writes from the spec's
  /// `golden:` declaration. gen appends the `matchesGoldenFile` baseline
  /// hook for widget-kind rows carrying it — no `--golden` flag needed.
  final bool golden;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Behavior && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Behavior(id: $id, kind: $kind, state: $state, persistence: '
      '$persistence, traces: $sourceCriterion)';
}
