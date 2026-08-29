/// ConflictDetector (spec 043): 3-way hash decisions (FR-008).
///
/// The three hashes are the file's content hash at cut time (recorded in
/// slice.yaml), its current hash in the sandbox, and its current hash in
/// the main project:
///
///   sandbox == cut              -> skip      (agent never touched it)
///   sandbox != cut, main == cut -> safeCopy  (only the agent changed it)
///   sandbox != cut, main != cut -> conflict  (both sides changed it)
///   sandbox missing             -> sandboxDeleted (agent removed it)
library;

/// The merge decision for one manifest file.
enum MergeDecision {
  /// Unchanged in the sandbox: do nothing.
  skip,

  /// Agent-modified, main unchanged: safe to copy back.
  safeCopy,

  /// Modified on both sides: report, never overwrite.
  conflict,

  /// Deleted by the agent from the sandbox.
  sandboxDeleted,

  /// Created by the agent inside the sandbox.
  agentCreated,
}

/// Computes per-file merge decisions from the 3-way hash comparison.
class ConflictDetector {
  /// Decides the fate of one file.
  MergeDecision decide({
    required String cutHash,
    required String? sandboxHash,
    required String? mainHash,
  }) {
    if (sandboxHash == null) {
      return MergeDecision.sandboxDeleted;
    }
    if (sandboxHash == cutHash) {
      return MergeDecision.skip;
    }
    // The agent modified the file; the question is whether the main project
    // moved underneath the slice too.
    if (mainHash == cutHash) {
      return MergeDecision.safeCopy;
    }
    return MergeDecision.conflict;
  }

  /// Warning for a manifest branch differing from [currentBranch], or null
  /// when they match (U40, spec edge case: merging across branches).
  String? branchWarning({
    required String manifestBranch,
    required String currentBranch,
  }) {
    if (manifestBranch == currentBranch) return null;
    return (
      'This slice was cut from branch "$manifestBranch" but the project is '
      'now on "$currentBranch" — merged changes may not apply cleanly.'
    );
  }
}
