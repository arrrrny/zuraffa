import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'middleware_annotation.dart';
import 'retry_generator.dart';

/// DDA plugin that processes `@Retry` annotations on UseCase
/// or datasource methods and generates retry wrapper logic.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateRetryFile] to emit
/// `lib/src/middleware/zfa_retry.g.dart`.
///
/// Supported annotations:
/// - `@Retry(attempts: 3, backoff: BackoffStrategy.exponential)`
/// - `@Retry.fixed(attempts: 3)`
///
/// The generated wrapper catches retryable failures (network, server)
/// and retries with configurable backoff strategies.
class RetryDDAPlugin extends ZorphyDecoratorPlugin {
  RetryDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs.
  final String packageName;

  late final _generator = RetryGenerator();

  @override
  String get targetDecorator => 'Retry';

  @override
  List<String> get targetDecorators => const ['Retry'];

  @override
  int get priority => 8;

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

    final attempts = decorator.get<int>('attempts') ?? 3;
    final backoffStr =
        decorator.get<String>('backoff') ?? 'BackoffStrategy.exponential';
    final backoff = _parseBackoff(backoffStr);
    final maxDelayMs =
        _parseDurationMs(decorator.get<String>('maxDelay')) ?? 30000;
    final baseDelayMs =
        _parseDurationMs(decorator.get<String>('baseDelay')) ?? 1000;
    final maxCumulativeMs = _parseDurationMs(
      decorator.get<String>('maxCumulativeTime'),
    );

    final retryOnRaw = decorator.get<List>('retryOn');
    final retryOn =
        retryOnRaw?.cast<String>().toList() ?? const ['network', 'server'];

    _generator.addRetryEntry(
      className: className,
      methodName: methodName,
      importUri: importUri,
      returnType: returnType,
      parameters: params,
      attempts: attempts,
      backoff: backoff,
      maxDelayMs: maxDelayMs,
      baseDelayMs: baseDelayMs,
      maxCumulativeMs: maxCumulativeMs,
      retryOn: retryOn,
    );
  }

  /// Generate the retry middleware file content.
  String generateRetryFile() => _generator.generate();

  /// Whether any retry entries were collected.
  bool get hasRetryEntries => _generator.hasEntries;

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

  BackoffStrategy _parseBackoff(String strategyStr) {
    final normalized = strategyStr.trim().split('.').last;
    switch (normalized) {
      case 'fixed':
        return BackoffStrategy.fixed;
      case 'exponential':
        return BackoffStrategy.exponential;
      case 'decorrelatedJitter':
        return BackoffStrategy.decorrelatedJitter;
      default:
        return BackoffStrategy.exponential;
    }
  }

  int? _parseDurationMs(String? durationStr) {
    if (durationStr == null) return null;
    final days = RegExp(r'days:\s*(\d+)').firstMatch(durationStr);
    final hours = RegExp(r'hours:\s*(\d+)').firstMatch(durationStr);
    final minutes = RegExp(r'minutes:\s*(\d+)').firstMatch(durationStr);
    final seconds = RegExp(r'seconds:\s*(\d+)').firstMatch(durationStr);
    final millis = RegExp(r'milliseconds:\s*(\d+)').firstMatch(durationStr);
    if (days == null &&
        hours == null &&
        minutes == null &&
        seconds == null &&
        millis == null) {
      return null;
    }
    return ((days != null ? int.parse(days.group(1)!) * 86400000 : 0) +
        (hours != null ? int.parse(hours.group(1)!) * 3600000 : 0) +
        (minutes != null ? int.parse(minutes.group(1)!) * 60000 : 0) +
        (seconds != null ? int.parse(seconds.group(1)!) * 1000 : 0) +
        (millis != null ? int.parse(millis.group(1)!) : 0));
  }
}
