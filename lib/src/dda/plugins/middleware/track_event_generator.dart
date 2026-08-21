import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import '../../models/zorphy_context.dart';

/// Generates `lib/src/middleware/zfa_events.g.dart` from collected
/// `@TrackEvent` annotation metadata.
///
/// Produces:
/// - A `ZfaEventTracker` base class with pre/post event logging
/// - Per-class tracker adapter extensions that wrap annotated methods
/// - Configurable property extraction, duration tracking, result tracking
class TrackEventGenerator {
  TrackEventGenerator({this.packageName = 'zuraffa'});

  final String packageName;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_TrackEventEntry> _entries = [];

  bool get hasEntries => _entries.isNotEmpty;

  void addTrackEventEntry({
    required String className,
    required String methodName,
    required String importUri,
    required String returnType,
    required List<ParameterInfo> parameters,
    required String eventName,
    required List<String> properties,
    required bool trackDuration,
    required bool trackResult,
    required String analyticsService,
  }) {
    _entries.add(
      _TrackEventEntry(
        className: className,
        methodName: methodName,
        importUri: importUri,
        returnType: returnType,
        parameters: parameters,
        eventName: eventName,
        properties: properties,
        trackDuration: trackDuration,
        trackResult: trackResult,
        analyticsService: analyticsService,
      ),
    );
  }

  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline \u2014 Track 6.3';

      final importUris = <String>{};
      for (final entry in _entries) {
        if (entry.importUri.isNotEmpty) {
          importUris.add(entry.importUri);
        }
      }
      b.directives.add(cb.Directive.import('dart:io'));
      for (final uri in importUris) {
        b.directives.add(cb.Directive.import(uri));
      }
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));

      b.body.add(_eventTrackerClass());

      // Collect unique analytics service types
      final serviceTypes = <String>{};
      for (final entry in _entries) {
        serviceTypes.add(entry.analyticsService);
      }

      // Group entries by className
      final classNames = <String>{};
      for (final entry in _entries) {
        classNames.add(entry.className);
      }
      for (final cn in classNames) {
        final classEntries = _entries.where((e) => e.className == cn).toList();
        b.body.add(_trackerAdapterClass(cn, classEntries));
      }
    });

    final emitter = cb.DartEmitter();
    return _formatter.format(library.accept(emitter).toString());
  }

  // -- ZfaEventTracker --

  cb.Class _eventTrackerClass() {
    return cb.Class(
      (c) => c
        ..name = 'ZfaEventTracker'
        ..abstract = true
        ..fields.addAll([
          cb.Field(
            (f) => f
              ..name = 'logEvent'
              ..type = cb.refer('void Function(String, Map<String, dynamic>)')
              ..modifier = cb.FieldModifier.final$,
          ),
        ])
        ..constructors.addAll([
          cb.Constructor(
            (ctor) => ctor
              ..requiredParameters.add(
                cb.Parameter(
                  (p) => p
                    ..name = 'logEvent'
                    ..toThis = true,
                ),
              ),
          ),
        ])
        ..methods.addAll([
          cb.Method(
            (m) => m
              ..name = 'trackStart'
              ..returns = cb.refer('void')
              ..requiredParameters.addAll([
                cb.Parameter(
                  (p) => p
                    ..name = 'eventName'
                    ..type = cb.refer('String'),
                ),
                cb.Parameter(
                  (p) => p
                    ..name = 'properties'
                    ..type = cb.refer('Map<String, dynamic>'),
                ),
              ])
              ..body = cb.Code(
                _joinLines([
                  'final enriched = Map<String, dynamic>.from(properties);',
                  "enriched['event_phase'] = 'start';",
                  'logEvent(eventName, enriched);',
                ]),
              ),
          ),
          cb.Method(
            (m) => m
              ..name = 'trackEnd'
              ..returns = cb.refer('void')
              ..requiredParameters.addAll([
                cb.Parameter(
                  (p) => p
                    ..name = 'eventName'
                    ..type = cb.refer('String'),
                ),
                cb.Parameter(
                  (p) => p
                    ..name = 'properties'
                    ..type = cb.refer('Map<String, dynamic>'),
                ),
              ])
              ..optionalParameters.addAll([
                cb.Parameter(
                  (p) => p
                    ..name = 'durationMs'
                    ..type = cb.refer('int?'),
                ),
                cb.Parameter(
                  (p) => p
                    ..name = 'success'
                    ..type = cb.refer('bool?'),
                ),
              ])
              ..body = cb.Code(
                _joinLines([
                  'final enriched = Map<String, dynamic>.from(properties);',
                  "enriched['event_phase'] = 'end';",
                  'if (durationMs != null) {',
                  "  enriched['durationMs'] = durationMs;",
                  '}',
                  'if (success != null) {',
                  "  enriched['success'] = success;",
                  '}',
                  'logEvent(eventName, enriched);',
                ]),
              ),
          ),
        ]),
    );
  }

  // -- Per-class tracker adapter --

  cb.Class _trackerAdapterClass(
    String className,
    List<_TrackEventEntry> entries,
  ) {
    final methods = <cb.Method>[];
    for (final entry in entries) {
      methods.add(_trackedMethod(entry));
    }
    return cb.Class(
      (c) => c
        ..name = '_${className}EventAdapter'
        ..fields.addAll([
          cb.Field(
            (f) => f
              ..name = '_tracker'
              ..type = cb.refer('ZfaEventTracker')
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
                    ..name = 'tracker'
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

  cb.Method _trackedMethod(_TrackEventEntry entry) {
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
          if (!param.isOptional) b.required = true;
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

    final callArgs = entry.parameters
        .map((p) {
          return p.isNamed ? '${p.name}: ${p.name}' : p.name;
        })
        .join(', ');

    // Build properties map from declared property names
    final propAssignments = <String>[];
    for (final prop in entry.properties) {
      propAssignments.add("'$prop': $prop");
    }
    final propsMap = propAssignments.isEmpty
        ? 'const <String, dynamic>{}'
        : '<String, dynamic>{${propAssignments.join(', ')}}';

    final bodyLines = <String>[];

    // Pre-event
    bodyLines.add("final props = $propsMap;");
    bodyLines.add("_tracker.trackStart('${entry.eventName}', props);");

    // Duration tracking
    if (entry.trackDuration) {
      bodyLines.add('final sw = Stopwatch()..start();');
    }

    // Execute with result tracking
    if (entry.trackResult) {
      bodyLines.addAll([
        'try {',
        '  final result = await _source.${entry.methodName}($callArgs);',
      ]);
      if (entry.trackDuration) {
        bodyLines.add('  sw.stop();');
        bodyLines.add(
          "  _tracker.trackEnd('${entry.eventName}', props, durationMs: sw.elapsedMilliseconds, success: true);",
        );
      } else {
        bodyLines.add(
          "  _tracker.trackEnd('${entry.eventName}', props, success: true);",
        );
      }
      bodyLines.addAll(['  return result;', '} catch (e) {']);
      if (entry.trackDuration) {
        bodyLines.add('  sw.stop();');
        bodyLines.add(
          "  _tracker.trackEnd('${entry.eventName}', props, durationMs: sw.elapsedMilliseconds, success: false);",
        );
      } else {
        bodyLines.add(
          "  _tracker.trackEnd('${entry.eventName}', props, success: false);",
        );
      }
      bodyLines.add('  rethrow;');
      bodyLines.add('}');
    } else {
      // No result tracking — just execute and track end
      bodyLines.add(
        'final result = await _source.${entry.methodName}($callArgs);',
      );
      if (entry.trackDuration) {
        bodyLines.add('sw.stop();');
        bodyLines.add(
          "_tracker.trackEnd('${entry.eventName}', props, durationMs: sw.elapsedMilliseconds);",
        );
      }
      bodyLines.add('return result;');
    }

    return cb.Method(
      (m) => m
        ..name = entry.methodName
        ..returns = cb.refer(entry.returnType)
        ..modifier = cb.MethodModifier.async
        ..requiredParameters.addAll(requiredParams)
        ..optionalParameters.addAll(optionalParams)
        ..optionalParameters.addAll(namedParams)
        ..body = cb.Code(_joinLines(bodyLines)),
    );
  }

  String _joinLines(List<String> lines) => lines.join('\n');
}

class _TrackEventEntry {
  _TrackEventEntry({
    required this.className,
    required this.methodName,
    required this.importUri,
    required this.returnType,
    required this.parameters,
    required this.eventName,
    required this.properties,
    required this.trackDuration,
    required this.trackResult,
    required this.analyticsService,
  });
  final String className;
  final String methodName;
  final String importUri;
  final String returnType;
  final List<ParameterInfo> parameters;
  final String eventName;
  final List<String> properties;
  final bool trackDuration;
  final bool trackResult;
  final String analyticsService;
}
