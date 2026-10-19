import 'share_content.dart';
import 'share_result.dart';

/// Primary interface exposed to consumers for sharing content.
abstract interface class ShareHandler {
  /// Triggers the platform share sheet with [content].
  Future<ShareResult> share(ShareContent content);

  /// Whether sharing is available on the current platform.
  Future<bool> canShare();
}
