/// Share-sheet seam: hand text/subject/files to the platform share UI.
library;

/// Recoverable, typed share error.
class ShareException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const ShareException(this.code, this.message);

  /// A share payload was empty.
  factory ShareException.nothingToShare() => const ShareException(
    'nothing_to_share',
    'Nothing to share: provide text or at least one file.',
  );

  /// The platform share sheet could not be presented.
  factory ShareException.unavailable(String detail) =>
      ShareException('unavailable', 'Share sheet unavailable: $detail');

  @override
  String toString() => 'ShareException($code): $message';
}

/// One share request as the platform received it.
class ShareRequest {
  /// The text to share (optional when files are present).
  final String? text;

  /// Optional subject (email clients, etc.).
  final String? subject;

  /// File paths to share (optional when text is present).
  final List<String> files;

  const ShareRequest({this.text, this.subject, this.files = const []});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareRequest &&
          other.text == text &&
          other.subject == subject &&
          _sameFiles(other.files);

  @override
  int get hashCode => Object.hash(text, subject, files.length);

  bool _sameFiles(List<String> other) {
    if (files.length != other.length) return false;
    for (var i = 0; i < files.length; i++) {
      if (files[i] != other[i]) return false;
    }
    return true;
  }
}

/// The share contract.
abstract class SharePort {
  /// Presents the platform share sheet with [request]; resolves when the
  /// sheet is dismissed.
  Future<void> share(ShareRequest request);
}

/// Pure-Dart default adapter: records every share for assertions.
class InMemoryShareAdapter implements SharePort {
  /// Every share received, in order.
  final List<ShareRequest> requests = [];

  @override
  Future<void> share(ShareRequest request) async {
    if ((request.text == null || request.text!.isEmpty) &&
        request.files.isEmpty) {
      throw ShareException.nothingToShare();
    }
    requests.add(request);
  }
}
