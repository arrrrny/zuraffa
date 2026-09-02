/// Generated-artifact shape verification for the TDD recovery commands
/// (bug #840).
///
/// `zfa tdd gen` writes a provenance header into every artifact it emits
/// (`BehaviorTestWriter` / `SubjectWriter`):
///
/// ```
/// // GENERATED TEST — `zfa tdd gen <id>` (spec 044-test-tdd-generation).
/// // behavior_id: <id>
/// ```
/// (subjects carry the same fields behind a `// GENERATED STUB` marker).
///
/// That header is the content-shape contract `--adopt` verifies before it
/// registers ownership: a file that does not carry the marker for its role
/// plus the matching `behavior_id` is NOT provably a generated artifact and
/// is never adopted (the assessment's open question resolves to this
/// structural check — deterministic, dependency-free, and it cannot be
/// satisfied by arbitrary hand-written code that merely compiles).
library;

/// The provenance marker a generated TEST file carries.
const String generatedTestMarker = '// GENERATED TEST';

/// The provenance marker a generated SUBJECT file carries.
const String generatedSubjectMarker = '// GENERATED STUB';

/// Extracts the `// behavior_id:` value from a generated artifact's
/// provenance header, or `null` when the file carries none.
String? behaviorIdFromContent(String content) {
  final match = RegExp(
    r'^// behavior_id: (\S+)',
    multiLine: true,
  ).firstMatch(content);
  return match?.group(1);
}

/// Whether [content] is provably a generated TEST artifact for
/// [behaviorId]: the test marker plus a matching behavior id.
bool matchesGeneratedTestShape(String content, String behaviorId) {
  if (!content.contains(generatedTestMarker)) return false;
  return behaviorIdFromContent(content) == behaviorId;
}

/// Whether [content] is provably a generated SUBJECT artifact for
/// [behaviorId]: the stub marker plus a matching behavior id.
bool matchesGeneratedSubjectShape(String content, String behaviorId) {
  if (!content.contains(generatedSubjectMarker)) return false;
  return behaviorIdFromContent(content) == behaviorId;
}
