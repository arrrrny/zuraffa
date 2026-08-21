import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'track_event_generator.dart';

/// DDA plugin that processes `@TrackEvent` annotations on UseCase
/// methods and generates telemetry injection logic.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateTrackEventFile] to emit
/// `lib/src/middleware/zfa_events.g.dart`.
///
/// Supported annotations:
/// - `@TrackEvent(eventName: 'checkout_started', properties: ['userId', 'total'])`
///
/// The generated code calls an analytics service before/after UseCase
/// execution, keeping domain code free of telemetry calls.
class TrackEventDDAPlugin extends ZorphyDecoratorPlugin {
  TrackEventDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs.
  final String packageName;

  late final _generator = TrackEventGenerator();

  @override
  String get targetDecorator => 'TrackEvent';

  @override
  List<String> get targetDecorators => const ['TrackEvent'];

  @override
  int get priority => 15;

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    final className = method.className ?? '';
    final methodName = method.name;
    final importUri = _extractImportUri(method.libraryUri);
    final returnType = method.returnType ?? 'dynamic';
    final params = method.parameters;

    final eventName = decorator.get<String>('eventName') ?? methodName;
    final propertiesRaw = decorator.get<List>('properties');
    final properties = propertiesRaw?.cast<String>().toList() ?? const [];
    final trackDuration = decorator.get<bool>('trackDuration') ?? true;
    final trackResult = decorator.get<bool>('trackResult') ?? true;
    final analyticsService =
        decorator.get<String>('analyticsService') ?? 'AnalyticsService';

    _generator.addTrackEventEntry(
      className: className,
      methodName: methodName,
      importUri: importUri,
      returnType: returnType,
      parameters: params,
      eventName: eventName,
      properties: properties,
      trackDuration: trackDuration,
      trackResult: trackResult,
      analyticsService: analyticsService,
    );
  }

  /// Generate the track event middleware file content.
  String generateTrackEventFile() => _generator.generate();

  /// Whether any track event entries were collected.
  bool get hasTrackEventEntries => _generator.hasEntries;

  // -- Helpers --

  String _extractImportUri(String? libraryUri) {
    if (libraryUri == null) return '';
    if (libraryUri.contains('/lib/')) {
      final parts = libraryUri.split('/lib/');
      if (parts.length == 2) {
        return 'package:$packageName/${parts[1]}';
      }
    }
    return libraryUri;
  }
}
