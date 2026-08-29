// X-Ray state summary — a small value object summarising the
// `SignalSlice<T>` state attached to an `XRayNode` so the overlay can
// render an at-a-glance indicator (data✓ / error✗ / loading…).
//
// Pure-Dart, no Flutter dependency. The Flutter side constructs this
// from the live `SignalSlice` instance via [XRayStateSummary.fromPreviews].
//
// Track 4.2 — Spec 036 (issue #181, FR-003, FR-008).
library;

/// Truncation length for data/error previews rendered inline on the box.
const int kXrayStateSummaryPreviewMaxLen = 80;

/// Summary of a [SignalSlice]'s state for at-a-glance overlay rendering.
///
/// Immutable.  Reconstructable via [toJson] / [fromJson].
class XRayStateSummary {
  /// `true` when the slice currently holds successful data.
  final bool hasData;

  /// `true` when the slice currently holds a failure (error).
  final bool hasError;

  /// `true` when the slice is currently loading.
  final bool isLoading;

  /// Short human-readable preview of the data (e.g. `"Product(id=42)"`).
  /// Truncated to [kXrayStateSummaryPreviewMaxLen] characters.
  final String? dataPreview;

  /// Short human-readable preview of the error (e.g.
  /// `"NetworkException(503)"`). Truncated to
  /// [kXrayStateSummaryPreviewMaxLen] characters.
  final String? errorPreview;

  /// All-false empty summary. Used when a slice has not yet been executed
  /// or has no state.
  const XRayStateSummary({
    required this.hasData,
    required this.hasError,
    required this.isLoading,
    this.dataPreview,
    this.errorPreview,
  });

  /// Canonical "no state yet" summary.
  const XRayStateSummary.empty()
    : hasData = false,
      hasError = false,
      isLoading = false,
      dataPreview = null,
      errorPreview = null;

  /// Construct from raw preview strings — truncates each preview to the
  /// max length.
  ///
  /// The Flutter overlay typically calls this after pulling
  /// `hasData`/`hasError`/`isLoading`/`data`/`error` off a live
  /// `SignalSlice` instance.
  factory XRayStateSummary.fromPreviews({
    bool hasData = false,
    bool hasError = false,
    bool isLoading = false,
    String? dataPreview,
    String? errorPreview,
  }) {
    return XRayStateSummary(
      hasData: hasData,
      hasError: hasError,
      isLoading: isLoading,
      dataPreview: _truncate(dataPreview),
      errorPreview: _truncate(errorPreview),
    );
  }

  /// Serialize to JSON for the MCP bridge / detail panel.
  Map<String, dynamic> toJson() => {
    'hasData': hasData,
    'hasError': hasError,
    'isLoading': isLoading,
    if (dataPreview != null) 'dataPreview': dataPreview,
    if (errorPreview != null) 'errorPreview': errorPreview,
  };

  /// Deserialize from JSON.
  factory XRayStateSummary.fromJson(Map<String, dynamic> json) {
    return XRayStateSummary(
      hasData: json['hasData'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      dataPreview: json['dataPreview'] as String?,
      errorPreview: json['errorPreview'] as String?,
    );
  }

  /// Short status word used by the inline label formatter.
  ///
  /// Priority: loading > error > data > idle. Only the highest-priority
  /// indicator is returned so the label stays compact.
  String get statusWord {
    if (isLoading) return 'loading';
    if (hasError) return 'error';
    if (hasData) return 'data';
    return 'idle';
  }

  @override
  String toString() => 'XRayStateSummary($statusWord)';
}

String? _truncate(String? s) {
  if (s == null) return null;
  if (s.length <= kXrayStateSummaryPreviewMaxLen) return s;
  return '${s.substring(0, kXrayStateSummaryPreviewMaxLen - 1)}…';
}
