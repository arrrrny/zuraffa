// Tests for the Ownership model (spec 044-test-tdd-generation, T001/T004).
//
// `Ownership` is the result field `gen` returns for both the test and the
// subject artifact, telling the caller whether each was newly created,
// reused from a prior idempotent run, or only planned (`--dry-run`).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';

void main() {
  group('Ownership', () {
    test('created is the default for new artifacts (FR-005)', () {
      // The GenCommand produces `Ownership.created` when it writes a
      // brand-new test/subject pair for a behavior that has no prior
      // artifact record.
      expect(Ownership.created, isNotNull);
      expect(Ownership.values, contains(Ownership.created));
    });

    test('reused is returned for matching idempotent repeat (FR-006)', () {
      // A second `gen` invocation for the same behavior, when both
      // artifacts are already on disk and the registry has an entry,
      // returns `Ownership.reused` for both — the command wrote zero
      // bytes.
      expect(Ownership.reused, isNotNull);
      expect(Ownership.values, contains(Ownership.reused));
      expect(Ownership.reused == Ownership.created, isFalse);
    });

    test('planned is returned for --dry-run (FR-009)', () {
      // `--dry-run` plans the artifact pair without writing anything;
      // the result reports `Ownership.planned` for both artifacts.
      expect(Ownership.planned, isNotNull);
      expect(Ownership.values, contains(Ownership.planned));
      expect(Ownership.planned == Ownership.created, isFalse);
      expect(Ownership.planned == Ownership.reused, isFalse);
    });

    test('has exactly three values', () {
      expect(Ownership.values, hasLength(3));
      expect(
        Ownership.values.toSet(),
        equals({Ownership.created, Ownership.reused, Ownership.planned}),
      );
    });

    test('serializes to a stable lowercase name', () {
      // The registry JSON stores the name; the report file uses the
      // name. Both rely on the snake-case-ish lowercase name.
      expect(Ownership.created.name, 'created');
      expect(Ownership.reused.name, 'reused');
      expect(Ownership.planned.name, 'planned');
    });
  });
}
