/// Behavior entity for the `zfa tdd` plugin.
library;

<<<<<<< HEAD
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
enum BehaviorKind { acceptance, unit, widget, theme }
=======
/// The loop kind of a behavior.
///
/// `acceptance` / `unit` are the two spec-derived kinds (SpecParser).
/// `ffi` (bug #835) marks a NATIVE-BOUNDARY behavior: its subject is an
/// FFI binding contract (symbols resolved, marshalling round-trip) and
/// its golden fixture assertion runs in the marked integration lane —
/// declared by hand in the test list (the kind cell or a `## Native
/// loop` section), never derived from spec prose.
enum BehaviorKind { acceptance, unit, ffi }
>>>>>>> be1e86d5 (fix(835): TDD loop TDD-ables native boundaries — ffi-kind behaviors get a binding-contract lane in the loop and a golden fixture lane wired to CI)

enum BehaviorState { pending, red, green, done }

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

  Behavior({
    required this.id,
    required this.feature,
    required this.kind,
    required this.description,
    required this.sourceCriterion,
    required this.target,
    this.persistence = false,
    this.state = BehaviorState.pending,
  });

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
