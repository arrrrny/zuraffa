import 'platform_context.dart';

/// Resolves adaptive layouts using the fallback order:
/// platform+device -> platform -> device -> generic/default.
class PlatformLayoutResolver<T> {
  final String genericKey;

  const PlatformLayoutResolver({this.genericKey = 'default'});

  T? resolve(
    Map<String, T> layouts,
    PlatformContext context, {
    Iterable<String> extraFallbackKeys = const <String>[],
  }) {
    for (final key in candidateKeys(
      context,
      extraFallbackKeys: extraFallbackKeys,
    )) {
      final value = layouts[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  List<String> candidateKeys(
    PlatformContext context, {
    Iterable<String> extraFallbackKeys = const <String>[],
  }) {
    return buildCandidateKeys(
      context,
      genericKey: genericKey,
      extraFallbackKeys: extraFallbackKeys,
    );
  }

  static List<String> buildCandidateKeys(
    PlatformContext context, {
    String genericKey = 'default',
    Iterable<String> extraFallbackKeys = const <String>[],
  }) {
    final candidates = <String>[
      context.compoundKey,
      context.platformKey,
      context.deviceKey,
      ...extraFallbackKeys,
      genericKey,
    ];

    final deduped = <String>[];
    final seen = <String>{};
    for (final key in candidates) {
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      deduped.add(key);
    }
    return deduped;
  }

  static T? resolveLayout<T>(
    Map<String, T> layouts,
    PlatformContext context, {
    String genericKey = 'default',
    Iterable<String> extraFallbackKeys = const <String>[],
  }) {
    return PlatformLayoutResolver<T>(
      genericKey: genericKey,
    ).resolve(layouts, context, extraFallbackKeys: extraFallbackKeys);
  }
}
