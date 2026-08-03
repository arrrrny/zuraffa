import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'cache_annotation.dart';
import 'cache_generator.dart';

/// DDA plugin that processes `@Cacheable` and `@CacheInvalidate`
/// annotations on repository/datasource methods and generates
/// caching wrapper logic.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateCacheFile] to emit
/// `lib/src/cache/zfa_cache.g.dart`.
///
/// Supported annotations:
/// - `@Cacheable(ttl: Duration(hours: 1))` — cache-wrapped method
/// - `@CacheInvalidate(methods: ['getProduct'])` — cache invalidator
///
/// The plugin collects metadata about annotated methods and their
/// containing classes, then the [CacheGenerator] produces:
/// - A `CacheStore` adapter that wraps Hive read/write/TTL logic
/// - Wrapper extensions for each `@Cacheable` method
/// - Invalidation hooks for each `@CacheInvalidate` method
/// - DI registration for the generated cache store
class CacheDDAPlugin extends ZorphyDecoratorPlugin {
  CacheDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs.
  final String packageName;

  late final _generator = CacheGenerator();

  @override
  String get targetDecorator => 'Cacheable';

  @override
  List<String> get targetDecorators =>
      const ['Cacheable', 'CacheInvalidate'];

  @override
  int get priority => 5;

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    // @Cacheable and @CacheInvalidate are METHOD-level annotations.
    // Skip class-level decorators.
    if (method.isClass) return;

    final className = method.className ?? '';
    final methodName = method.name;
    final importUri = _extractImportUri(method.libraryUri);
    final returnType = method.returnType ?? 'dynamic';
    final params = method.parameters;

    if (decorator.name == 'Cacheable') {
      final ttlStr = decorator.get<String>('ttl');
      final strategyStr = decorator.get<String>('strategy') ?? 'offlineFirst';
      final keyPrefix = decorator.get<String>('keyPrefix');
      final boxName = decorator.get<String>('boxName');

      final ttl = _parseTtl(ttlStr);
      final strategy = _parseStrategy(strategyStr);

      _generator.addCacheableMethod(
        className: className,
        methodName: methodName,
        importUri: importUri,
        returnType: returnType,
        parameters: params,
        ttl: ttl,
        strategy: strategy,
        keyPrefix: keyPrefix,
        boxName: boxName,
      );
    } else if (decorator.name == 'CacheInvalidate') {
      final methodsRaw = decorator.get<List>('methods');
      final methods = methodsRaw?.cast<String>().toList() ?? [];
      final keyPrefix = decorator.get<String>('keyPrefix');

      _generator.addInvalidatorMethod(
        className: className,
        methodName: methodName,
        importUri: importUri,
        methods: methods,
        parameters: params,
        keyPrefix: keyPrefix,
      );
    }
  }

  /// Generate the cache layer file content.
  String generateCacheFile() => _generator.generate();

  /// Whether any cacheable or invalidator methods were collected.
  bool get hasCacheEntries => _generator.hasEntries;

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

  Duration? _parseTtl(String? ttlStr) {
    if (ttlStr == null) return null;

    // Extract all Duration parameter values
    final days = RegExp(r'days:\s*(\d+)').firstMatch(ttlStr);
    final hours = RegExp(r'hours:\s*(\d+)').firstMatch(ttlStr);
    final minutes = RegExp(r'minutes:\s*(\d+)').firstMatch(ttlStr);
    final seconds = RegExp(r'seconds:\s*(\d+)').firstMatch(ttlStr);
    final milliseconds = RegExp(r'milliseconds:\s*(\d+)').firstMatch(ttlStr);

    // If no valid units found, return null
    if (days == null && hours == null && minutes == null && seconds == null && milliseconds == null) {
      return null;
    }

    // Sum all provided units
    return Duration(
      days: days != null ? int.parse(days.group(1)!) : 0,
      hours: hours != null ? int.parse(hours.group(1)!) : 0,
      minutes: minutes != null ? int.parse(minutes.group(1)!) : 0,
      seconds: seconds != null ? int.parse(seconds.group(1)!) : 0,
      milliseconds: milliseconds != null ? int.parse(milliseconds.group(1)!) : 0,
    );
  }

  CacheStrategy _parseStrategy(String strategyStr) {
    // Normalize: trim and extract enum value after last dot
    final normalized = strategyStr.trim().split('.').last;

    switch (normalized) {
      case 'offlineFirst':
        return CacheStrategy.offlineFirst;
      case 'networkFirst':
        return CacheStrategy.networkFirst;
      case 'cacheOnly':
        return CacheStrategy.cacheOnly;
      case 'networkOnly':
        return CacheStrategy.networkOnly;
      default:
        // Invalid strategy - log and default to offlineFirst
        print('Warning: Invalid cache strategy "$strategyStr", defaulting to offlineFirst');
        return CacheStrategy.offlineFirst;
    }
  }
}
