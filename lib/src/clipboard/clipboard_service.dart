import 'package:get_it/get_it.dart';

import 'clipboard.dart';

export 'clipboard.dart';

/// App-facing clipboard facade.
///
/// ```dart
/// final clipboard = ClipboardService();
/// await clipboard.copy('tok-1');
/// final token = await clipboard.paste();   // 'tok-1'
/// await clipboard.copySensitive('tok-1');  // same as copy, semantic marker
/// await clipboard.clear();
/// ```
class ClipboardService {
  /// The platform adapter (or the in-memory default in tests).
  final ClipboardPort port;

  ClipboardService({ClipboardPort? port})
    : port = port ?? InMemoryClipboardAdapter();

  /// Copies [text] to the clipboard.
  Future<void> copy(String text) => port.setText(text);

  /// Copies [text] flagged as sensitive — same storage behavior as
  /// [copy]; the marker documents intent for adapters that can, e.g.,
  /// expire the entry early.
  Future<void> copySensitive(String text) => port.setText(text);

  /// Reads the clipboard, or `null` when empty.
  Future<String?> paste() => port.getText();

  /// Whether the clipboard holds any text.
  Future<bool> get hasText async => (await port.getText()) != null;

  /// Clears the clipboard.
  Future<void> clear() => port.clear();
}

/// Registers the clipboard stack onto [getIt].
void registerClipboardDependencies(GetIt getIt, {ClipboardPort? port}) {
  getIt
    ..registerLazySingleton<ClipboardPort>(
      () => port ?? InMemoryClipboardAdapter(),
    )
    ..registerLazySingleton<ClipboardService>(
      () => ClipboardService(port: getIt<ClipboardPort>()),
    );
}
