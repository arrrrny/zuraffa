import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import '../../models/zorphy_context.dart';
import 'middleware_annotation.dart';

/// Generates `lib/src/middleware/zfa_retry.g.dart` from collected
/// `@Retry` annotation metadata.
class RetryGenerator {
  RetryGenerator({this.packageName = 'zuraffa'});

  final String packageName;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_RetryEntry> _entries = [];

  bool get hasEntries => _entries.isNotEmpty;

  void addRetryEntry({
    required String className,
    required String methodName,
    required String importUri,
    required String returnType,
    required List<ParameterInfo> parameters,
    required int attempts,
    required BackoffStrategy backoff,
    required int maxDelayMs,
    required int baseDelayMs,
    int? maxCumulativeMs,
    required List<String> retryOn,
  }) {
    _entries.add(_RetryEntry(
      className: className,
      methodName: methodName,
      importUri: importUri,
      returnType: returnType,
      parameters: parameters,
      attempts: attempts,
      backoff: backoff,
      maxDelayMs: maxDelayMs,
      baseDelayMs: baseDelayMs,
      maxCumulativeMs: maxCumulativeMs,
      retryOn: retryOn,
    ));
  }

  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline — Track 6.3';
      final importUris = <String>{};
      for (final entry in _entries) {
        if (entry.importUri.isNotEmpty) {
          importUris.add(entry.importUri);
        }
      }
      b.directives.add(cb.Directive.import('dart:async'));
      b.directives.add(cb.Directive.import('dart:math'));
      for (final uri in importUris) {
        b.directives.add(cb.Directive.import(uri));
      }
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      b.body.add(_retryPolicyClass());
      final classNames = <String>{};
      for (final entry in _entries) {
        classNames.add(entry.className);
      }
      for (final cn in classNames) {
        final ce = _entries.where((e) => e.className == cn).toList();
        b.body.add(_retryAdapterClass(cn, ce));
      }
    });
    final emitter = cb.DartEmitter();
    return _formatter.format(library.accept(emitter).toString());
  }

  cb.Class _retryPolicyClass() {
    return cb.Class((c) => c
      ..name = 'ZfaRetryPolicy'
      ..fields.addAll([
        cb.Field((f) => f
          ..name = 'attempts'
          ..type = cb.refer('int')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = 'backoff'
          ..type = cb.refer('BackoffStrategy')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = 'maxDelayMs'
          ..type = cb.refer('int')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = 'baseDelayMs'
          ..type = cb.refer('int')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = 'maxCumulativeMs'
          ..type = cb.refer('int?')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = 'retryOnFailureTypes'
          ..type = cb.refer('List<String>')
          ..modifier = cb.FieldModifier.final$),
      ])
      ..constructors.addAll([
        cb.Constructor((ctor) => ctor
          ..requiredParameters.addAll([
            cb.Parameter((p) => p..name = 'attempts'..toThis = true),
            cb.Parameter((p) => p..name = 'backoff'..toThis = true),
          ])
          ..optionalParameters.addAll([
            cb.Parameter((p) => p
              ..name = 'maxDelayMs'
              ..toThis = true
              ..defaultTo = cb.Code('30000')),
            cb.Parameter((p) => p
              ..name = 'baseDelayMs'
              ..toThis = true
              ..defaultTo = cb.Code('1000')),
            cb.Parameter((p) => p..name = 'maxCumulativeMs'..toThis = true),
            cb.Parameter((p) => p
              ..name = 'retryOnFailureTypes'
              ..toThis = true
              ..defaultTo = cb.Code("const ['network', 'server']")),
          ])),
      ])
      ..methods.addAll([
        cb.Method((m) => m
          ..name = 'computeDelay'
          ..returns = cb.refer('Duration')
          ..requiredParameters.add(
            cb.Parameter((p) => p
              ..name = 'attemptIndex'
              ..type = cb.refer('int')))
          ..body = cb.Code(_joinLines([
            'switch (backoff) {',
            '  case BackoffStrategy.fixed:',
            '    return Duration(milliseconds: baseDelayMs);',
            '  case BackoffStrategy.exponential:',
            '    final ms = (baseDelayMs * pow(2, attemptIndex)).toInt();',
            '    return Duration(milliseconds: ms > maxDelayMs ? maxDelayMs : ms);',
            '  case BackoffStrategy.decorrelatedJitter:',
            '    final prevMs = attemptIndex == 0 ? baseDelayMs : baseDelayMs;',
            '    final nextMs = (prevMs + Random().nextDouble() * baseDelayMs).toInt();',
            '    return Duration(milliseconds: nextMs > maxDelayMs ? maxDelayMs : nextMs);',
            '}',
          ]))),
        cb.Method((m) => m
          ..name = 'isRetryable'
          ..returns = cb.refer('bool')
          ..requiredParameters.add(
            cb.Parameter((p) => p
              ..name = 'failure'
              ..type = cb.refer('AppFailure')))
          ..body = cb.Code(_joinLines([
            'final failureStr = failure.toString().toLowerCase();',
            'for (final type in retryOnFailureTypes) {',
            '  if (failureStr.contains(type.toLowerCase())) return true;',
            '}',
            'return false;',
          ]))),
      ]),
    );
  }

  cb.Class _retryAdapterClass(String className, List<_RetryEntry> entries) {
    final methods = <cb.Method>[];
    for (final entry in entries) {
      methods.add(_retryMethod(entry));
    }
    return cb.Class((c) => c
      ..name = '_' + className + 'RetryAdapter'
      ..fields.addAll([
        cb.Field((f) => f
          ..name = '_policy'
          ..type = cb.refer('ZfaRetryPolicy')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = '_source'
          ..type = cb.refer(className)
          ..modifier = cb.FieldModifier.final$),
      ])
      ..constructors.addAll([
        cb.Constructor((ctor) => ctor
          ..requiredParameters.addAll([
            cb.Parameter((p) => p..name = 'policy'..toThis = true),
            cb.Parameter((p) => p..name = 'source'..toThis = true),
          ])),
      ])
      ..methods.addAll(methods),
    );
  }

  cb.Method _retryMethod(_RetryEntry entry) {
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

    final callArgs = entry.parameters.map((p) {
      if (p.isNamed) {
        return '${p.name}: ${p.name}';
      }
      return p.name;
    }).join(', ');

    final originalCall = '_source.${entry.methodName}(${callArgs})';
    final maxRetries = entry.attempts - 1;

    final budgetLines = <String>[];
    if (entry.maxCumulativeMs != null) {
      budgetLines.add('final budgetMs = ${entry.maxCumulativeMs};');
      budgetLines.add('var elapsedMs = 0;');
    }

    final body = _joinLines([
      ...budgetLines,
      'for (var i = 0; i < ${maxRetries}; i++) {',
      '  try {',
      '    return await ${originalCall};',
      '  } catch (e) {',
      '    if (e is AppFailure && !_policy.isRetryable(e)) rethrow;',
      if (entry.maxCumulativeMs != null) ...[
        '    elapsedMs += _policy.computeDelay(i).inMilliseconds;',
        '    if (elapsedMs > budgetMs) rethrow;',
      ],
      '    final delay = _policy.computeDelay(i);',
      '    await Future.delayed(delay);',
      '  }',
      '}',
      'return await ${originalCall};',
    ]);

    return cb.Method((m) => m
      ..name = entry.methodName
      ..returns = cb.refer(entry.returnType)
      ..modifier = cb.MethodModifier.async
      ..requiredParameters.addAll(requiredParams)
      ..optionalParameters.addAll(optionalParams)
      ..optionalParameters.addAll(namedParams)
      ..body = cb.Code(body),
    );
  }

  String _joinLines(List<String> lines) =>
      lines.where((l) => l.isNotEmpty).join('\n');
}

class _RetryEntry {
  _RetryEntry({
    required this.className,
    required this.methodName,
    required this.importUri,
    required this.returnType,
    required this.parameters,
    required this.attempts,
    required this.backoff,
    required this.maxDelayMs,
    required this.baseDelayMs,
    this.maxCumulativeMs,
    required this.retryOn,
  });

  final String className;
  final String methodName;
  final String importUri;
  final String returnType;
  final List<ParameterInfo> parameters;
  final int attempts;
  final BackoffStrategy backoff;
  final int maxDelayMs;
  final int baseDelayMs;
  final int? maxCumulativeMs;
  final List<String> retryOn;
}

