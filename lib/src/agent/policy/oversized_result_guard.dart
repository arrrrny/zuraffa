import 'artifact_reference.dart';
import 'policy_hook.dart';

/// Intercepts tool results exceeding [threshold] bytes and replaces them
/// with an [ArtifactReference] before they enter model context (FR-010).
///
/// If [artifactStorage] is unavailable (returns false), the result is
/// truncated with a marker (degraded but not broken — per spec edge case).
class OversizedResultGuard extends PolicyHook {
  OversizedResultGuard({
    required this.threshold,
    required this.artifactStorage,
    this.truncationMarker = '<truncated>',
  });

  @override
  String get id => 'oversized_result_guard';

  /// Maximum payload size before the guard swaps in an [ArtifactReference].
  final int threshold;

  /// Callback that stores [payload] externally and returns the artifact URI
  /// (or null if storage is unavailable — triggers truncation).
  final Future<String?> Function(Object? payload) artifactStorage;

  final String truncationMarker;

  @override
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    final size = result.effectiveSize;
    if (size <= threshold) return result;

    // FR-010: oversized result — swap with an artifact reference before
    // model context.
    final uri = await artifactStorage(result.payload);
    if (uri == null) {
      // Spec edge case: storage unavailable → truncate.
      return ToolResult(
        payload: truncationMarker,
        size: truncationMarker.length,
        tokenUsage: result.tokenUsage,
      );
    }
    final artifact = ArtifactReference(
      uri: uri,
      size: size,
      sha256: ArtifactReference.hashOf(result.payload),
      truncated: false,
    );
    return ToolResult(
      payload: artifact,
      size: artifact.toJson().toString().length,
      tokenUsage: result.tokenUsage,
    );
  }
}
