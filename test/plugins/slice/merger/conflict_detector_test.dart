/// Tests for ConflictDetector (U37, U38, U39, U40).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U37: `sandbox_hash == cut_hash` yields skip (file not copied)
///   U38: `sandbox_hash != cut_hash` and `main_hash == cut_hash` yields
///        safe_copy
///   U39: `sandbox_hash != cut_hash` and `main_hash != cut_hash` yields
///        conflict
///   U40: A manifest branch differing from the current branch yields a
///        recorded warning
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/merger/conflict_detector.dart';

void main() {
  late ConflictDetector detector;

  setUp(() {
    detector = ConflictDetector();
  });

  group('ConflictDetector 3-way decisions (FR-008)', () {
    test('U37: unchanged sandbox file yields skip', () {
      expect(
        detector.decide(cutHash: 'abc', sandboxHash: 'abc', mainHash: 'abc'),
        equals(MergeDecision.skip),
      );
    });

    test('U37: an agent-deleted file is reported as deleted, not skip', () {
      expect(
        detector.decide(cutHash: 'abc', sandboxHash: null, mainHash: 'abc'),
        equals(MergeDecision.sandboxDeleted),
      );
    });

    test('U38: agent-modified only yields safeCopy', () {
      expect(
        detector.decide(
          cutHash: 'abc',
          sandboxHash: 'changed-by-agent',
          mainHash: 'abc',
        ),
        equals(MergeDecision.safeCopy),
      );
    });

    test('U39: both sides modified yields conflict', () {
      expect(
        detector.decide(
          cutHash: 'abc',
          sandboxHash: 'changed-by-agent',
          mainHash: 'changed-in-main',
        ),
        equals(MergeDecision.conflict),
      );
    });

    test('U39: sandbox modified after main deleted yields conflict', () {
      expect(
        detector.decide(
          cutHash: 'abc',
          sandboxHash: 'changed-by-agent',
          mainHash: null,
        ),
        equals(MergeDecision.conflict),
      );
    });

    test('U40: a branch mismatch yields a recorded warning', () {
      final warning = detector.branchWarning(
        manifestBranch: 'feature/slice-work',
        currentBranch: 'master',
      );

      expect(warning, isNotNull);
      expect(warning, contains('feature/slice-work'));
      expect(warning, contains('master'));
    });

    test('U40: matching branches yield no warning', () {
      expect(
        detector.branchWarning(
          manifestBranch: 'master',
          currentBranch: 'master',
        ),
        isNull,
      );
    });
  });
}
