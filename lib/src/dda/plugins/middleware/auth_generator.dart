import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import '../../models/zorphy_context.dart';
import 'middleware_annotation.dart';

/// Generates `lib/src/middleware/zfa_auth.g.dart` from collected
/// `@RequiresAuth` annotation metadata.
///
/// Produces:
/// - A `ZfaAuthGuard` base class with role-checking logic
/// - Per-class interceptor extensions that wrap annotated methods
/// - Role hierarchy resolution via built-in `Role.satisfies()`
class AuthGenerator {
  AuthGenerator({this.packageName = 'zuraffa'});

  final String packageName;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_AuthEntry> _entries = [];

  bool get hasEntries => _entries.isNotEmpty;

  void addAuthEntry({
    required String className,
    required String methodName,
    required String importUri,
    required String returnType,
    required List<ParameterInfo> parameters,
    required List<String> roles,
    required AuthorizationMode mode,
    required bool isClassLevel,
  }) {
    _entries.add(_AuthEntry(
      className: className,
      methodName: methodName,
      importUri: importUri,
      returnType: returnType,
      parameters: parameters,
      roles: roles,
      mode: mode,
      isClassLevel: isClassLevel,
    ));
  }

  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline \u2014 Track 6.3';

      // Collect unique import URIs
      final importUris = <String>{};
      for (final entry in _entries) {
        if (entry.importUri.isNotEmpty) {
          importUris.add(entry.importUri);
        }
      }
      for (final uri in importUris) {
        b.directives.add(cb.Directive.import(uri));
      }
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));

      b.body.add(_authGuardClass());

      // Group entries by className
      final classNames = <String>{};
      for (final entry in _entries) {
        classNames.add(entry.className);
      }
      for (final cn in classNames) {
        final classEntries = _entries.where((e) => e.className == cn).toList();
        b.body.add(_authAdapterClass(cn, classEntries));
      }
    });

    final emitter = cb.DartEmitter();
    return _formatter.format(library.accept(emitter).toString());
  }

  // ── ZfaAuthGuard ──

  cb.Class _authGuardClass() {
    return cb.Class((c) => c
      ..name = 'ZfaAuthGuard'
      ..abstract = true
      ..fields.addAll([
        cb.Field((f) => f
          ..name = '_roleProvider'
          ..type = cb.refer('Future<Role> Function()')
          ..modifier = cb.FieldModifier.final$),
      ])
      ..constructors.addAll([
        cb.Constructor((ctor) => ctor
          ..requiredParameters.add(cb.Parameter((p) => p
            ..name = 'roleProvider'
            ..toThis = true)),
        ),
      ])
      ..methods.addAll([
        cb.Method((m) => m
          ..name = 'requireRole'
          ..returns = cb.refer('Future<void>')
          ..modifier = cb.MethodModifier.async
          ..requiredParameters.addAll([
            cb.Parameter((p) => p
              ..name = 'requiredRole'
              ..type = cb.refer('Role')),
            cb.Parameter((p) => p
              ..name = 'mode'
              ..type = cb.refer('AuthorizationMode')),
          ])
          ..body = cb.Code(_joinLines([
            'final userRole = await _roleProvider();',
            'final required = Role.satisfies(userRole, requiredRole);',
            'if (required) return;',
            'throw AppFailure.session("Unauthorized: requires \${requiredRole.name} role");',
          ])),
        ),
        cb.Method((m) => m
          ..name = 'requireAnyRole'
          ..returns = cb.refer('Future<void>')
          ..modifier = cb.MethodModifier.async
          ..requiredParameters.add(cb.Parameter((p) => p
            ..name = 'roles'
            ..type = cb.refer('List<Role>')))
          ..body = cb.Code(_joinLines([
            'final userRole = await _roleProvider();',
            'for (final role in roles) {',
            '  if (Role.satisfies(userRole, role)) return;',
            '}',
            'throw AppFailure.session("Unauthorized: requires one of \${roles.map((r) => r.name)}");',
          ])),
        ),
      ]),
    );
  }

  // ── Per-class auth adapter ──

  cb.Class _authAdapterClass(String className, List<_AuthEntry> entries) {
    final methods = <cb.Method>[];
    for (final entry in entries) {
      methods.add(_authMethod(entry));
    }
    return cb.Class((c) => c
      ..name = '_${className}AuthAdapter'
      ..fields.addAll([
        cb.Field((f) => f
          ..name = '_guard'
          ..type = cb.refer('ZfaAuthGuard')
          ..modifier = cb.FieldModifier.final$),
        cb.Field((f) => f
          ..name = '_source'
          ..type = cb.refer(className)
          ..modifier = cb.FieldModifier.final$),
      ])
      ..constructors.addAll([
        cb.Constructor((ctor) => ctor
          ..requiredParameters.addAll([
            cb.Parameter((p) => p..name = 'guard'..toThis = true),
            cb.Parameter((p) => p..name = 'source'..toThis = true),
          ])),
      ])
      ..methods.addAll(methods),
    );
  }

  cb.Method _authMethod(_AuthEntry entry) {
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

    final callArgs = entry.parameters.map((p) {
      return p.isNamed ? '${p.name}: ${p.name}' : p.name;
    }).join(', ');

    final bodyLines = <String>[];

    if (entry.mode == AuthorizationMode.any && entry.roles.length > 1) {
      // Any mode: check if user satisfies at least one role
      final roleChecks = entry.roles.map((r) {
        return "Role.satisfies(userRole, Role.$r)";
      }).join(' || ');
      bodyLines.addAll([
        'final userRole = await _guard._roleProvider();',
        'if (!($roleChecks)) {',
        "  throw AppFailure.session('Unauthorized: requires one of [${entry.roles.join(', ')}]');",
        '}',
      ]);
    } else {
      // All mode (or single role): check highest required role
      final highestRole = entry.roles.first; // First role is the required level
      bodyLines.addAll([
        'await _guard.requireRole(Role.$highestRole, AuthorizationMode.${entry.mode.name});',
      ]);
    }

    bodyLines.add('return await _source.${entry.methodName}($callArgs);');

    return cb.Method((m) => m
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

class _AuthEntry {
  _AuthEntry({
    required this.className,
    required this.methodName,
    required this.importUri,
    required this.returnType,
    required this.parameters,
    required this.roles,
    required this.mode,
    required this.isClassLevel,
  });
  final String className;
  final String methodName;
  final String importUri;
  final String returnType;
  final List<ParameterInfo> parameters;
  final List<String> roles;
  final AuthorizationMode mode;
  final bool isClassLevel;
}

