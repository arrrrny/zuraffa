// GENERATED subject — implemented (issue #960 U7 / FR-007).
//
// Priority ordering: P1 → P2 → P3 → none, stable within a tier by
// declaration order.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/models/mock_priority.dart';

Object? subject_u7() {
  final order = [
    MockPriority.tryParse('P2')!,
    MockPriority.tryParse('P1')!,
    MockPriority.tryParse('')!,
    MockPriority.tryParse('P3')!,
    MockPriority.tryParse('')!,
  ];
  final indexed = order.indexed.toList();
  indexed.sort((a, b) {
    final byTier = a.$2.tier.compareTo(b.$2.tier);
    return byTier != 0 ? byTier : a.$1.compareTo(b.$1);
  });
  expect(
    indexed.map((e) => e.$2).map((p) => p.label).toList(),
    equals(['p1', 'p2', 'p3', 'none', 'none']),
    reason: 'P1 → P2 → P3 → none',
  );
  // Stability: equal priorities keep declaration order.
  expect(indexed[3].$1, lessThan(indexed[4].$1));
  // Unknown tokens refuse (null), never a silent default.
  expect(MockPriority.tryParse('P9'), isNull);
  return null;
}
