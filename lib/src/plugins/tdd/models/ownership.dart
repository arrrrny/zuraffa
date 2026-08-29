/// Ownership status for a `gen` artifact (spec 044-test-tdd-generation,
/// FR-005, FR-006, FR-008, FR-009).
///
/// `gen` returns one [Ownership] value for the test artifact and one for
/// the subject artifact. The two values may differ (e.g. test created,
/// subject reused) when the registry state diverges between the two files.
library;

/// The three ownership states for a `gen` artifact.
///
/// - [created]: the artifact was newly written by this `gen` invocation.
/// - [reused]: the artifact already existed on disk and was already
///   recorded in the registry (idempotent repeat). `gen` wrote zero bytes.
/// - [planned]: `--dry-run` was passed. The artifact's path was computed
///   and reported, but no file was written and no registry entry created.
enum Ownership { created, reused, planned }
