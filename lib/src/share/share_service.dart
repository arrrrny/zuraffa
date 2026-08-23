import 'package:get_it/get_it.dart';

import 'share.dart';

export 'share.dart';

/// App-facing share facade with empty-payload validation.
///
/// ```dart
/// final share = ShareService();
/// await share.shareText('Look at this!', subject: 'Check it out');
/// await share.shareFiles(['/tmp/report.pdf'], text: 'Monthly report');
/// ```
class ShareService {
  /// The platform adapter (or the in-memory default in tests).
  final SharePort port;

  ShareService({SharePort? port}) : port = port ?? InMemoryShareAdapter();

  /// Shares [text] (optionally with a [subject]).
  Future<void> shareText(String text, {String? subject}) =>
      port.share(ShareRequest(text: text, subject: subject));

  /// Shares [files] (optionally with [text]/[subject]).
  Future<void> shareFiles(
    List<String> files, {
    String? text,
    String? subject,
  }) => port.share(ShareRequest(text: text, subject: subject, files: files));

  /// Shares an arbitrary combination; throws
  /// [ShareException.nothingToShare] when both text and files are empty
  /// (a caller bug, surfaced early).
  Future<void> share({String? text, String? subject, List<String>? files}) {
    if ((text == null || text.isEmpty) && (files == null || files.isEmpty)) {
      throw ShareException.nothingToShare();
    }
    return port.share(
      ShareRequest(text: text, subject: subject, files: files ?? const []),
    );
  }
}

/// Registers the share stack onto [getIt].
void registerShareDependencies(GetIt getIt, {SharePort? port}) {
  getIt
    ..registerLazySingleton<SharePort>(() => port ?? InMemoryShareAdapter())
    ..registerLazySingleton<ShareService>(
      () => ShareService(port: getIt<SharePort>()),
    );
}
