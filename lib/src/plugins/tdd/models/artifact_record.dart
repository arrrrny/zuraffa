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

  /// Deserializes from a JSON map. Throws [FormatException] if the JSON
  /// is malformed (missing fields, non-string values, unknown ownership).
  factory ArtifactRecord.fromJson(Map<String, dynamic> json) {
    String _requireString(dynamic value, String field) {
      if (value is! String || value.isEmpty) {
        throw FormatException(
          'ArtifactRecord: expected non-empty string for "$field", '
          'got ${value.runtimeType}',
        );
      }
      return value;
    }

    Ownership _requireOwnership(dynamic value, String field) {
      final str = _requireString(value, field);
      try {
        return Ownership.values.byName(str);
      } on ArgumentError {
        throw FormatException(
          'ArtifactRecord: unknown ownership "$str" for "$field". '
          'Expected one of: ${Ownership.values.map((e) => e.name).join(', ')}',
        );
      }
    }

    return ArtifactRecord(
      behaviorId: _requireString(json['behavior_id'], 'behavior_id'),
      feature: _requireString(json['feature'], 'feature'),
      sourceCriterion: _requireString(
        json['source_criterion'],
        'source_criterion',
      ),
      testPath: _requireString(json['test_path'], 'test_path'),
      subjectPath: _requireString(json['subject_path'], 'subject_path'),
      runnableTestName: _requireString(
        json['runnable_test_name'],
        'runnable_test_name',
      ),
      testOwnership: _requireOwnership(
        json['test_ownership'],
        'test_ownership',
      ),
      subjectOwnership: _requireOwnership(
        json['subject_ownership'],
        'subject_ownership',
      ),
      createdAt: _requireString(json['created_at'], 'created_at'),
    );
  }

  /// Serializes to a JSON string (for `artifacts.json`).
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from a JSON string.
  static ArtifactRecord fromJsonString(String json) =>
      ArtifactRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
