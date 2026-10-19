import 'share_content.dart';
import 'share_handler_repository.dart';
import 'share_result.dart';

/// A datasource used when no platform implementation is available.
///
/// Platform implementations (Android/iOS/web/...) are provided by the
/// umbrella `zikzak_inappwebview` package and injected through DI.
class UnsupportedShareHandlerDatasource implements ShareHandlerDatasource {
  const UnsupportedShareHandlerDatasource();

  @override
  Future<ShareResult> share(ShareContent content) async =>
      const ShareResult.error('Sharing is not supported on this platform.');

  @override
  Future<bool> canShare() async => false;
}

/// Convenience factory for wiring the repository in a DI container when
/// no platform implementation is supplied.
ShareHandlerRepository createDefaultShareHandlerRepository() =>
    ShareHandlerRepository(const UnsupportedShareHandlerDatasource());
