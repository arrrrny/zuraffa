import 'dart:io';
import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'generator_utils.dart';

/// Generates dual-layer state files:
///
/// - `{Name}DomainState` — **regenerated every build** (read-only, signal slices)
/// - `{Name}ViewState` — **scaffolded once**, preserved across builds
///
/// ## Preservation Logic
///
/// If `{Name}ViewState` already exists at the output path, it is **never**
/// overwritten. The generator skips it and logs a message.
///
/// ```dart
/// final gen = StateGenerator(outputDir: 'lib/presentation');
/// gen.generateDomainState('ProductDetail', useCases: [...]);
/// gen.generateViewState('ProductDetail', fields: [...]); // only if missing
/// ```
class StateGenerator {
  StateGenerator({required this.outputDir});

  final String outputDir;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<String> _generatedFiles = [];
  final List<String> _preservedFiles = [];

  List<String> get generatedFiles => List.unmodifiable(_generatedFiles);
  List<String> get preservedFiles => List.unmodifiable(_preservedFiles);

  // ── DomainState (always regenerated) ──

  /// Generate `{name}DomainState` — a sealed read-only container of slices.
  ///
  /// This file is overwritten on every `zfa build`.
  String generateDomainState(
    String name, {
    required List<UseCaseBinding> useCases,
    String? presenterImport,
    Set<String>? cacheableSliceKeys,
  }) {
    final className = '${name}DomainState';
    final fileName = snakeCase(name);
    final filePath = p.join(outputDir, '${fileName}_domain_state.dart');

    final library = cb.Library((b) {
      // #281: v6 dual-layer state files import 'package:zuraffa_flutter/zuraffa_flutter.dart'
      // (re-exports zuraffa core: DomainState/ViewState/Signal/SignalSlice) so
      // generated Flutter apps compile against the same direct dep setup wires.
      b.directives.add(cb.Directive.import('package:zuraffa_flutter/zuraffa_flutter.dart'));
      if (presenterImport != null) {
        b.directives.add(cb.Directive.import(presenterImport));
      }

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..extend = cb.refer('DomainState')
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor
                  ..name = null
                  ..optionalParameters.add(
                    cb.Parameter((p) {
                      p
                        ..name = 'presenter'
                        ..named = true
                        ..required = true
                        ..toSuper = true;
                    }),
                  );
              }),
            );

          // Generate late final slice bindings. When a slice is cacheable
          // (entity is @Cacheable), append a cascade `..bindCache()` so the
          // field remains a SignalSlice<T> while still subscribing to the
          // CacheObserver for cross-view sync.
          for (final binding in useCases) {
            final isCacheable =
                cacheableSliceKeys?.contains(binding.sliceKey) ?? false;
            final baseCall = cb
                .refer('bind')
                .call(
                  [
                    cb.literalString(binding.sliceKey),
                    cb.refer(binding.useCaseFieldName),
                    cb.refer(binding.paramsConstructor).call([]),
                  ],
                  {},
                  [cb.refer(binding.returnType)],
                );
            // code_builder has no first-class cascade; emit the cascade as a
            // raw code string so the field type stays SignalSlice<T>.
            final assignmentCode = isCacheable
                ? cb.Code('${baseCall.accept(cb.DartEmitter())}..bindCache()')
                : baseCall.code;
            c.fields.add(
              cb.Field((f) {
                f
                  ..name = binding.sliceKey
                  ..modifier = cb.FieldModifier.final$
                  ..late = true
                  ..assignment = assignmentCode;
              }),
            );
          }
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    var formatted = raw;
    try {
      formatted = _formatter.format(raw);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash. Narrow the catch
      // to FormatterException so unrelated generator bugs surface instead of
      // silently writing invalid output.
    }

    writeFile(filePath, formatted);
    _generatedFiles.add(filePath);
    return filePath;
  }

  // ── ViewState (scaffolded once, preserved) ──

  /// Scaffold `{name}ViewState` with default transient UI fields.
  ///
  /// If the file already exists, it is **not overwritten**.
  String generateViewState(
    String name, {
    List<ViewStateField> fields = const [],
  }) {
    final className = '${name}ViewState';
    final fileName = snakeCase(name);
    final filePath = p.join(outputDir, '${fileName}_view_state.dart');

    if (File(filePath).existsSync()) {
      _preservedFiles.add(filePath);
      return filePath;
    }

    final defaultFields = fields.isNotEmpty
        ? fields
        : [
            ViewStateField('isLoading', 'bool', 'false'),
            ViewStateField('activeTabIndex', 'int', '0'),
            ViewStateField('scrollOffset', 'double', '0.0'),
          ];

    final library = cb.Library((b) {
      // #281: ViewState imports 'package:zuraffa_flutter/zuraffa_flutter.dart' (re-exports zuraffa core).
      b.directives.add(cb.Directive.import('package:zuraffa_flutter/zuraffa_flutter.dart'));

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..extend = cb.refer('ViewState')
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor
                  ..name = null
                  ..body = cb.Block((bl) {
                    for (final field in defaultFields) {
                      bl.addExpression(
                        cb.refer('registerSignal').call([cb.refer(field.name)]),
                      );
                    }
                  });
              }),
            );

          for (final field in defaultFields) {
            c.fields.add(
              cb.Field((f) {
                f
                  ..name = field.name
                  ..modifier = cb.FieldModifier.final$
                  ..type = cb.refer('Signal<${field.type}>')
                  ..assignment = cb.refer('Signal<${field.type}>').call([
                    cb.CodeExpression(cb.Code(field.defaultValue)),
                  ]).code;
              }),
            );
          }
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    var formatted = raw;
    try {
      formatted = _formatter.format(raw);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash. Narrow the catch
      // to FormatterException so unrelated generator bugs surface instead of
      // silently writing invalid output.
    }

    writeFile(filePath, formatted);
    _generatedFiles.add(filePath);
    return filePath;
  }

  // ── Helpers ──
}

/// Metadata for a UseCase → slice binding.
class UseCaseBinding {
  UseCaseBinding({
    required this.sliceKey,
    required this.useCaseFieldName,
    required this.paramsConstructor,
    required this.returnType,
    this.cacheable = false,
  });

  final String sliceKey;
  final String useCaseFieldName;
  final String paramsConstructor;
  final String returnType;

  /// Whether this slice should be bound to the [CacheObserver] for
  /// automatic cross-view state synchronization. Set when the underlying
  /// entity is `@Cacheable`.
  final bool cacheable;
}

/// Metadata for a ViewState transient field.
class ViewStateField {
  ViewStateField(this.name, this.type, this.defaultValue);

  final String name;
  final String type;
  final String defaultValue;
}
