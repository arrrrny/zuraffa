import 'share_content.dart';
import 'share_handler.dart';
import 'share_result.dart';

/// Datasource contract for platform-specific share operations.
abstract interface class ShareHandlerDatasource {
  Future<ShareResult> share(ShareContent content);
  Future<bool> canShare();
}

/// Repository wrapping the platform datasource, participating in zuraffa DI.
class ShareHandlerRepository implements ShareHandler {
  ShareHandlerRepository(this._datasource);

  final ShareHandlerDatasource _datasource;

  @override
  Future<ShareResult> share(ShareContent content) => _datasource.share(content);

  @override
  Future<bool> canShare() => _datasource.canShare();
}
