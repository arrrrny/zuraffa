/// ArtifactRecord — durable row in `specs/<feature>/tdd/artifacts.json`
/// linking a behavior id to its paired test + subject (spec
/// 044-test-tdd-generation, FR-005, FR-007).
///
/// One [ArtifactRecord] per behavior id. The registry is append-only by
/// `gen`: a second `gen` for the same behavior is a no-op that returns
/// [Ownership.reused] for both artifacts without modifying the registry
/// (FR-006).
library;

import 'dart:convert';

import 'ownership.dart';

/// The persisted link between a behavior id and its paired test+subject
/// artifacts.
class ArtifactRecord {
  /// The behavior id, e.g. `B-003`. Unique within a feature.
  final String behaviorId;

  /// The feature this record belongs to (e.g. `044-test-tdd-generation`).
  final String feature;

  /// The criterion this behavior traces to (e.g. `FR-007`, `AC-1`).
  final String sourceCriterion;

  /// Absolute or repo-relative path to the test file.
  final String testPath;

  /// Absolute or repo-relative path to the subject file.
  final String subjectPath;

  /// The runnable test name in `file::group::test` form, suitable for
  /// `dart test --plain-name "<test-name>"`.
  final String runnableTestName;

  /// Ownership status of the test file when this record was created/updated.
  final Ownership testOwnership;

  /// Ownership status of the subject file when this record was created/updated.
  final Ownership subjectOwnership;

  /// ISO-8601 UTC timestamp when this record was first created.
  final String createdAt;

  const ArtifactRecord({
    required this.behaviorId,
    required this.feature,
    required this.sourceCriterion,
    required this.testPath,
    required this.subjectPath,
    required this.runnableTestName,
    required this.testOwnership,
    required this.subjectOwnership,
    required this.createdAt,
  });

  /// Copy with new ownership values (used for idempotent repeat).
  ArtifactRecord copyWithOwnership({
    required Ownership testOwnership,
    required Ownership subjectOwnership,
  }) => ArtifactRecord(
    behaviorId: behaviorId,
    feature: feature,
    sourceCriterion: sourceCriterion,
    testPath: testPath,
    subjectPath: subjectPath,
    runnableTestName: runnableTestName,
    testOwnership: testOwnership,
    subjectOwnership: subjectOwnership,
    createdAt: createdAt,
  );

  /// Equality is by behavior id within a feature (FR-007).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtifactRecord &&
          other.behaviorId == behaviorId &&
          other.feature == feature);

  @override
  int get hashCode => Object.hash(behaviorId, feature);

  @override
  String toString() =>
      'ArtifactRecord(behaviorId: $behaviorId, feature: $feature, '
      'sourceCriterion: $sourceCriterion, test: $testPath, '
      'subject: $subjectPath, ownership: $testOwnership/$subjectOwnership)';

  /// Serializes to a JSON map (for `artifacts.json`).
  Map<String, dynamic> toJson() => {
    'behavior_id': behaviorId,
    'feature': feature,
    'source_criterion': sourceCriterion,
    'test_path': testPath,
    'subject_path': subjectPath,
    'runnable_test_name': runnableTestName,
    'test_ownership': testOwnership.name,
    'subject_ownership': subjectOwnership.name,
    'created_at': createdAt,
  };

  /// Deserializes from a JSON map.
  factory ArtifactRecord.fromJson(Map<String, dynamic> json) => ArtifactRecord(
    behaviorId: json['behavior_id'] as String,
    feature: json['feature'] as String,
    sourceCriterion: json['source_criterion'] as String,
    testPath: json['test_path'] as String,
    subjectPath: json['subject_path'] as String,
    runnableTestName: json['runnable_test_name'] as String,
    testOwnership: Ownership.values.byName(json['test_ownership'] as String),
    subjectOwnership: Ownership.values.byName(
      json['subject_ownership'] as String,
    ),
    createdAt: json['created_at'] as String,
  );

  /// Serializes to a JSON string (for `artifacts.json`).
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from a JSON string.
  static ArtifactRecord fromJsonString(String json) =>
      ArtifactRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
