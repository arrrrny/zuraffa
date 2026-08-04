import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import '../../models/zorphy_context.dart';
import 'cache_annotation.dart';

/// Generates `lib/src/cache/zfa_cache.g.dart` from collected
/// `@Cacheable` and `@CacheInvalidate` annotation metadata.
class CacheGenerator {
  CacheGenerator({this.packageName = 'zuraffa'});

  final String packageName;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_CacheableEntry> _entries = [];
  final List<_InvalidatorEntry> _invalidators = [];

  bool get hasEntries => _entries.isNotEmpty || _invalidators.isNotEmpty;

  void addCacheableMethod({
    required String className,
    required String methodName,
    required String importUri,
    required String returnType,
    required List<ParameterInfo> parameters,
    Duration? ttl,
    CacheStrategy strategy = CacheStrategy.offlineFirst,
    String? keyPrefix,
    String? boxName,
  }) {
    _entries.add(
      _CacheableEntry(
        className: className,
        methodName: methodName,
        importUri: importUri,
        returnType: returnType,
        parameters: parameters,
        ttl: ttl,
        strategy: strategy,
        keyPrefix: keyPrefix,
        boxName: boxName,
      ),
    );
  }

  void addInvalidatorMethod({
    required String className,
    required String methodName,
    required String importUri,
    required List<String> methods,
    required List<ParameterInfo> parameters,
    String? keyPrefix,
  }) {
    _invalidators.add(
      _InvalidatorEntry(
        className: className,
        methodName: methodName,
        importUri: importUri,
        methods: methods,
        parameters: parameters,
        keyPrefix: keyPrefix,
      ),
    );
  }

  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline \u2014 Track 6.2';
      final importUris = <String>{};
      for (final entry in _entries) {
        if (entry.importUri.isNotEmpty) {
          importUris.add(entry.importUri);
        }
      }
      for (final inv in _invalidators) {
        if (inv.importUri.isNotEmpty) {
          importUris.add(inv.importUri);
        }
      }
      b.directives.add(cb.Directive.import('dart:convert'));
      for (final uri in importUris) {
        b.directives.add(cb.Directive.import(uri));
      }
      b.body.add(_cacheStoreClass());
      final classNames = <String>{};
      for (final entry in _entries) {
        classNames.add(entry.className);
      }
      for (final inv in _invalidators) {
        classNames.add(inv.className);
      }
      for (final cn in classNames) {
        final ce = _entries.where((e) => e.className == cn).toList();
        final ci = _invalidators.where((e) => e.className == cn).toList();
        if (ce.isNotEmpty || ci.isNotEmpty) {
          b.body.add(_cacheAdapterClass(cn, ce, ci));
        }
      }
    });
    final emitter = cb.DartEmitter();
    return _formatter.format(library.accept(emitter).toString());
  }

  // \u2500\u2500 ZfaCacheStore \u2500\u2500

  cb.Class _cacheStoreClass() {
    return cb.Class(
      (c) => c
        ..name = 'ZfaCacheStore'
        ..abstract = true
        ..fields.addAll([
          cb.Field(
            (f) => f
              ..name = '_defaultTtlMs'
              ..type = cb.refer('int')
              ..modifier = cb.FieldModifier.final$,
          ),
        ])
        ..constructors.addAll([
          cb.Constructor(
            (ctor) => ctor
              ..optionalParameters.add(
                cb.Parameter(
                  (p) => p
                    ..name = 'defaultTtlMs'
                    ..named = true
                    ..defaultTo = cb.Code('86400000')
                    ..toThis = true,
                ),
              ),
          ),
        ])
        ..methods.addAll([
          _getMethod(),
          _putMethod(),
          _invalidateMethod(),
          _invalidateByPrefixMethod(),
          _buildKeyMethod(),
          _openBoxMethod(),
        ]),
    );
  }

  cb.Method _getMethod() {
    final body = _joinLines([
      'final box = await _openBox();',
      'final raw = box.get(key) as String?;',
      'if (raw == null) return null;',
      'final entry = jsonDecode(raw) as Map<String, dynamic>;',
      "final cachedAt = entry['cachedAt'] as int? ?? 0;",
      "final ttlMs = entry['ttlMs'] as int? ?? _defaultTtlMs;",
      'final isExpired = DateTime.now().millisecondsSinceEpoch - cachedAt > ttlMs;',
      'if (isExpired) {',
      '  await box.delete(key);',
      '  return null;',
      '}',
      "return entry['data'] as String?;",
    ]);
    return cb.Method(
      (m) => m
        ..name = 'get'
        ..returns = cb.refer('Future<String?>')
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.add(
          cb.Parameter(
            (p) => p
              ..name = 'key'
              ..type = cb.refer('String'),
          ),
        )
        ..body = cb.Code(body),
    );
  }

  cb.Method _putMethod() {
    final body = _joinLines([
      'final box = await _openBox();',
      'final entry = jsonEncode({',
      "  'data': data,",
      "  'cachedAt': DateTime.now().millisecondsSinceEpoch,",
      "  'ttlMs': ttlMs ?? _defaultTtlMs,",
      '});',
      'await box.put(key, entry);',
    ]);
    return cb.Method(
      (m) => m
        ..name = 'put'
        ..returns = cb.refer('Future<void>')
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.addAll([
          cb.Parameter(
            (p) => p
              ..name = 'key'
              ..type = cb.refer('String'),
          ),
          cb.Parameter(
            (p) => p
              ..name = 'data'
              ..type = cb.refer('String'),
          ),
        ])
        ..optionalParameters.add(
          cb.Parameter(
            (p) => p
              ..name = 'ttlMs'
              ..type = cb.refer('int?'),
          ),
        )
        ..body = cb.Code(body),
    );
  }

  cb.Method _invalidateMethod() {
    final body = _joinLines([
      'final box = await _openBox();',
      'await box.delete(key);',
    ]);
    return cb.Method(
      (m) => m
        ..name = 'invalidate'
        ..returns = cb.refer('Future<void>')
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.add(
          cb.Parameter(
            (p) => p
              ..name = 'key'
              ..type = cb.refer('String'),
          ),
        )
        ..body = cb.Code(body),
    );
  }

  cb.Method _invalidateByPrefixMethod() {
    final body = _joinLines([
      'final box = await _openBox();',
      'final keysToDelete = box.keys',
      '    .whereType<String>()',
      '    .where((k) => k.startsWith(prefix))',
      '    .toList();',
      'for (final key in keysToDelete) {',
      '  await box.delete(key);',
      '}',
    ]);
    return cb.Method(
      (m) => m
        ..name = 'invalidateByPrefix'
        ..returns = cb.refer('Future<void>')
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.add(
          cb.Parameter(
            (p) => p
              ..name = 'prefix'
              ..type = cb.refer('String'),
          ),
        )
        ..body = cb.Code(body),
    );
  }

  cb.Method _buildKeyMethod() {
    final body = _joinLines([
      "if (args.isEmpty) return prefix;",
      "final argsHash = args.join(':');",
      "return '\$prefix:\$argsHash';",
    ]);
    return cb.Method(
      (m) => m
        ..name = 'buildKey'
        ..returns = cb.refer('String')
        ..static = true
        ..requiredParameters.addAll([
          cb.Parameter(
            (p) => p
              ..name = 'prefix'
              ..type = cb.refer('String'),
          ),
          cb.Parameter(
            (p) => p
              ..name = 'args'
              ..type = cb.refer('List<String>'),
          ),
        ])
        ..body = cb.Code(body),
    );
  }

  cb.Method _openBoxMethod() {
    return cb.Method(
      (m) => m
        ..name = '_openBox'
        ..returns = cb.refer('Future<dynamic>')
        ..body = null,
    );
  }

  String _joinLines(List<String> lines) => lines.join('\n');

  // \u2500\u2500 Per-class cache adapter \u2500\u2500

  cb.Class _cacheAdapterClass(
    String className,
    List<_CacheableEntry> entries,
    List<_InvalidatorEntry> invalidators,
  ) {
    final methods = <cb.Method>[];
    for (final entry in entries) {
      methods.add(_cachedMethod(entry));
    }
    for (final inv in invalidators) {
      methods.add(_invalidatorMethod(inv));
    }
    return cb.Class(
      (c) => c
        ..name = "_${className}CacheAdapter"
        ..fields.addAll([
          cb.Field(
            (f) => f
              ..name = '_store'
              ..type = cb.refer('ZfaCacheStore')
              ..modifier = cb.FieldModifier.final$,
          ),
          cb.Field(
            (f) => f
              ..name = '_source'
              ..type = cb.refer(className)
              ..modifier = cb.FieldModifier.final$,
          ),
        ])
        ..constructors.addAll([
          cb.Constructor(
            (ctor) => ctor
              ..requiredParameters.addAll([
                cb.Parameter(
                  (p) => p
                    ..name = 'store'
                    ..toThis = true,
                ),
                cb.Parameter(
                  (p) => p
                    ..name = 'source'
                    ..toThis = true,
                ),
              ]),
          ),
        ])
        ..methods.addAll(methods),
    );
  }

  cb.Method _cachedMethod(_CacheableEntry entry) {
    final kp = entry.keyPrefix ?? entry.methodName;
    final pNames = entry.parameters.map((p) => p.name).toList();
    final ttlMs = entry.ttl?.inMilliseconds;
    final argsListStr = pNames.map((n) => '\${$n.toString()}').join(', ');
    final keyExpr = pNames.isEmpty
        ? "'$kp'"
        : "ZfaCacheStore.buildKey('$kp', [$argsListStr])";

    final requiredParams = <cb.Parameter>[];
    final optionalParams = <cb.Parameter>[];
    final namedParams = <cb.Parameter>[];

    for (final param in entry.parameters) {
      final p = cb.Parameter((b) {
        b
          ..name = param.name
          ..type = cb.refer(param.type)
          ..defaultTo = param.defaultValue != null
              ? cb.Code(param.defaultValue!)
              : null;

        // Set named and required flags for named parameters
        if (param.isNamed) {
          b.named = true;
          if (!param.isOptional) {
            b.required = true;
          }
        }
      });

      if (param.isNamed) {
        namedParams.add(p);
      } else if (param.isOptional) {
        optionalParams.add(p);
      } else {
        requiredParams.add(p);
      }
    }

    // Build call arguments respecting named/positional structure
    final callArgs = entry.parameters
        .map((p) {
          if (p.isNamed) {
            return '${p.name}: ${p.name}';
          }
          return p.name;
        })
        .join(', ');

    final originalCall = '_source.${entry.methodName}($callArgs)';
    final bodyCode = _strategyBody(entry, keyExpr, originalCall, ttlMs);

    return cb.Method(
      (m) => m
        ..name = entry.methodName
        ..returns = cb.refer(entry.returnType)
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.addAll(requiredParams)
        ..optionalParameters.addAll(optionalParams)
        ..optionalParameters.addAll(namedParams)
        ..body = cb.Code(bodyCode),
    );
  }

  String _strategyBody(
    _CacheableEntry entry,
    String keyExpr,
    String originalCall,
    int? ttlMs,
  ) {
    final ttlArg = ttlMs != null ? ', ttlMs: $ttlMs' : '';
    switch (entry.strategy) {
      case CacheStrategy.offlineFirst:
        return _joinLines([
          '// offlineFirst: emit cache immediately, then fetch network',
          '// TODO: Signal support requires additional stream/controller setup',
          'final key = $keyExpr;',
          'final cachedRaw = await _store.get(key);',
          '// Cached data available but signal emission not yet implemented',
          'final freshData = await $originalCall;',
          'final encoded = jsonEncode(freshData);',
          'await _store.put(key, encoded$ttlArg);',
          'return freshData;',
        ]);
      case CacheStrategy.networkFirst:
        return _joinLines([
          '// networkFirst: try network first, fall back to cache',
          '// NOTE: Return type must support toJson/fromJson serialization',
          'final key = $keyExpr;',
          'try {',
          '  final freshData = await $originalCall;',
          '  final encoded = jsonEncode(freshData);',
          '  await _store.put(key, encoded$ttlArg);',
          '  return freshData;',
          '} catch (e) {',
          '  final cachedRaw = await _store.get(key);',
          '  if (cachedRaw != null) {',
          '    return jsonDecode(cachedRaw);',
          '  }',
          '  rethrow;',
          '}',
        ]);
      case CacheStrategy.cacheOnly:
        return _joinLines([
          '// cacheOnly: read from cache only',
          '// NOTE: Return type must be nullable and support fromJson deserialization',
          'final key = $keyExpr;',
          'final cachedRaw = await _store.get(key);',
          'if (cachedRaw != null) {',
          '    return jsonDecode(cachedRaw);',
          '}',
          'return null;',
        ]);
      case CacheStrategy.networkOnly:
        return _joinLines([
          '// networkOnly: pass through to network',
          'return await $originalCall;',
        ]);
    }
  }

  cb.Method _invalidatorMethod(_InvalidatorEntry inv) {
    final requiredParams = <cb.Parameter>[];
    final optionalParams = <cb.Parameter>[];
    final namedParams = <cb.Parameter>[];

    for (final param in inv.parameters) {
      final p = cb.Parameter((b) {
        b
          ..name = param.name
          ..type = cb.refer(param.type)
          ..defaultTo = param.defaultValue != null
              ? cb.Code(param.defaultValue!)
              : null;

        // Set named and required flags for named parameters
        if (param.isNamed) {
          b.named = true;
          if (!param.isOptional) {
            b.required = true;
          }
        }
      });

      if (param.isNamed) {
        namedParams.add(p);
      } else if (param.isOptional) {
        optionalParams.add(p);
      } else {
        requiredParams.add(p);
      }
    }

    // Build call arguments respecting named/positional structure
    final callArgs = inv.parameters
        .map((p) {
          if (p.isNamed) {
            return '${p.name}: ${p.name}';
          }
          return p.name;
        })
        .join(', ');

    final invalidateCalls = <String>[];
    for (final method in inv.methods) {
      final prefix = inv.keyPrefix ?? method;
      invalidateCalls.add("await _store.invalidateByPrefix('$prefix');");
    }
    final body =
        "await _source.${inv.methodName}($callArgs);\n"
        "${invalidateCalls.join('\n')}";
    return cb.Method(
      (m) => m
        ..name = "${inv.methodName}WithInvalidate"
        ..returns = cb.refer('Future<void>')
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.addAll(requiredParams)
        ..optionalParameters.addAll(optionalParams)
        ..optionalParameters.addAll(namedParams)
        ..body = cb.Code(body),
    );
  }
}

class _CacheableEntry {
  _CacheableEntry({
    required this.className,
    required this.methodName,
    required this.importUri,
    required this.returnType,
    required this.parameters,
    this.ttl,
    required this.strategy,
    this.keyPrefix,
    this.boxName,
  });
  final String className;
  final String methodName;
  final String importUri;
  final String returnType;
  final List<ParameterInfo> parameters;
  final Duration? ttl;
  final CacheStrategy strategy;
  final String? keyPrefix;
  final String? boxName;
}

class _InvalidatorEntry {
  _InvalidatorEntry({
    required this.className,
    required this.methodName,
    required this.importUri,
    required this.methods,
    required this.parameters,
    this.keyPrefix,
  });
  final String className;
  final String methodName;
  final String importUri;
  final List<String> methods;
  final List<ParameterInfo> parameters;
  final String? keyPrefix;
}
