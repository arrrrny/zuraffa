import 'dart:io';

import 'package:path/path.dart' as p;

import '../migration_models.dart';
import 'base_fixer.dart';

class StateMigrator extends MigrationFixer {
  @override
  String get migratorId => 'v5_mixed_state';

  @override
  String get displayName => 'State: v5 to v6 DomainState + ViewState';

  @override
  Future<MigrationResult> migrate({
    required List<MigrationFinding> findings,
    required String projectDir,
    bool dryRun = false,
  }) async {
    // The generated paths below are built by joining onto [projectDir], so
    // anchor it first: a relative projectDir (not `.`) would otherwise be
    // prepended a second time at the file operations and land the generated
    // files in a mirrored directory.
    projectDir = p.normalize(p.absolute(projectDir));
    final actions = <MigrationAction>[];
    final remaining = <MigrationFinding>[];

    for (final finding in findings) {
      if (finding.ruleId != 'v5_mixed_state') {
        remaining.add(finding);
        continue;
      }

      final filePath = p.join(projectDir, finding.filePath);
      final file = File(filePath);
      if (!file.existsSync()) {
        remaining.add(finding);
        continue;
      }

      final content = file.readAsStringSync();
      final analysis = _analyzeStateFile(content);
      if (!analysis.needsMigration) {
        remaining.add(finding);
        continue;
      }

      final fileDir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      final entityName = _extractEntityName(baseName);

      final domainStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_domain_state.dart',
      );
      final viewStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_view_state.dart',
      );

      // Idempotency (#2076): a file that already carries both generated
      // halves and the migration note is done — re-running must not stack a
      // second set of fields (or a second note) on top of what a developer
      // may already have reviewed and adjusted.
      // domainStatePath/viewStatePath are already rooted at projectDir
      // (through filePath/fileDir) — use them directly, never re-join
      // projectDir onto them.
      final alreadyMigrated =
          _hasMigrationNote(content) &&
          File(domainStatePath).existsSync() &&
          File(viewStatePath).existsSync();
      if (alreadyMigrated) {
        remaining.add(finding);
        continue;
      }

      // The generated files are the migration's own output and are preserved
      // once written: a developer who adjusted one keeps it (the "review and
      // adjust as needed" contract).
      final domainStateExists = File(domainStatePath).existsSync();
      final viewStateExists = File(viewStatePath).existsSync();

      final domainStateContent = _buildDomainState(
        entityName,
        analysis.domainFields,
      );
      final viewStateContent = _buildViewState(entityName, analysis.uiFields);

      if (!domainStateExists) {
        actions.add(
          MigrationAction(
            description:
                'Create ${p.basename(domainStatePath)} with domain data fields',
            filePath: domainStatePath,
            action: 'created',
            newContent: domainStateContent,
          ),
        );
      }

      if (!viewStateExists) {
        actions.add(
          MigrationAction(
            description:
                'Create ${p.basename(viewStatePath)} with UI state fields',
            filePath: viewStatePath,
            action: 'created',
            newContent: viewStateContent,
          ),
        );
      }

      final annotatedContent = _annotate(
        content,
        domainStatePath,
        viewStatePath,
      );
      if (annotatedContent != null) {
        actions.add(
          MigrationAction(
            description:
                'Annotate ${finding.filePath} as superseded by dual-layer state',
            filePath: filePath,
            action: 'modified',
            originalContent: content,
            newContent: annotatedContent,
          ),
        );
      }

      if (!dryRun) {
        if (!domainStateExists) {
          File(domainStatePath)
            ..createSync(recursive: true)
            ..writeAsStringSync(domainStateContent);
        }
        if (!viewStateExists) {
          File(viewStatePath)
            ..createSync(recursive: true)
            ..writeAsStringSync(viewStateContent);
        }
        if (annotatedContent != null) {
          file.writeAsStringSync(annotatedContent);
        }
      }
    }

    return MigrationResult(
      migratorId: migratorId,
      actions: actions,
      remaining: remaining,
    );
  }

  _StateAnalysis _analyzeStateFile(String content) {
    String? className;
    int classLine = 0;
    final domainFields = <_FieldInfo>[];
    final uiFields = <_FieldInfo>[];

    final classMatch = RegExp(r'class\s+(\w+State)\b').firstMatch(content);
    if (classMatch != null) {
      className = classMatch.group(1);
      classLine = _lineNumber(content, classMatch.start);
    }

    if (className == null) {
      return _StateAnalysis(
        className: '<unknown>',
        classLine: 0,
        domainFields: [],
        uiFields: [],
        needsMigration: false,
      );
    }

    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      final fieldMatch = RegExp(
        r'^(?:final\s+)?([\w<>?]+)\s+(\w+)\s*[;=]',
      ).firstMatch(trimmed);
      if (fieldMatch == null) continue;

      final type = fieldMatch.group(1)!;
      final name = fieldMatch.group(2)!;
      if (name.startsWith('_')) continue;

      String? doc;
      if (i > 0 && lines[i - 1].trim().startsWith('///')) {
        doc = lines[i - 1].trim().substring(3).trim();
      }

      final info = _FieldInfo(name: name, type: type, doc: doc);

      if (_isUiField(type, name)) {
        uiFields.add(info);
      } else {
        domainFields.add(info);
      }
    }

    return _StateAnalysis(
      className: className,
      classLine: classLine,
      domainFields: domainFields,
      uiFields: uiFields,
      needsMigration: domainFields.isNotEmpty && uiFields.isNotEmpty,
    );
  }

  bool _isUiField(String type, String name) {
    if ((type == 'bool' || type == 'bool?') &&
        (name.startsWith('is') || name.startsWith('has'))) {
      return true;
    }
    if (name == 'error' || type == 'AppFailure?' || type == 'AppFailure') {
      return true;
    }
    if (name == 'isLoading' || name == 'isRefreshing') return true;
    if (name == 'offset' || name == 'limit' || name == 'hasMore') return true;
    return false;
  }

  String _buildDomainState(String entityName, List<_FieldInfo> fields) {
    final entityCamel = entityName[0].toLowerCase() + entityName.substring(1);
    final lines = <String>[
      "// GENERATED by 'zfa migrate state' -- review and adjust as needed.",
      "import 'package:zuraffa/zuraffa.dart';",
      '',
      '/// Domain state for $entityName.',
      'class ${entityName}DomainState extends DomainState {',
      '  ${entityName}DomainState({required super.presenter});',
      '',
    ];

    if (fields.isEmpty) {
      lines.add('  // No domain data fields detected in original state.');
      lines.add('  // Add slice bindings here manually, e.g.:');
      lines.add(
        "  // late final $entityCamel = bind<$entityName>('$entityCamel', get${entityName}UseCase, params);",
      );
    } else {
      for (final field in fields) {
        final typeName = _stripNull(field.type);
        lines.add('  /// ${field.doc ?? "Bound $typeName slice"}');
        lines.addAll(_sliceBindingHint(field.name, typeName));
        lines.add('');
      }
    }

    lines.add('}');
    return '${lines.join('\n')}\n';
  }

  /// Guidance for one slice binding: loading, success and failure live in ONE
  /// value, so the view state no longer mirrors them as error/loading fields.
  ///
  /// Both forms are comments on purpose — the migration cannot name the use
  /// case or its params, and emitting a call to a symbol it invented would not
  /// compile.
  List<String> _sliceBindingHint(String fieldName, String typeName) {
    return <String>[
      '  // TODO: Replace useCase and params.',
      '  //',
      '  // A v6 use case returns a SignalResult<$typeName>, so bind it directly',
      '  // and drop the error/loading booleans the v5 state mirrored:',
      "  //   late final $fieldName = bind<$typeName>('$fieldName', useCase, params);",
      '  //',
      '  // A plain Future<$typeName> source bridges through',
      '  // SignalResult.fromFuture (loading -> success/failure):',
      '  //   late final $fieldName = SignalResult.fromFuture<$typeName>(fetch$typeName());',
      '  //',
      '  // Lifecycle: the fromFuture bridge writes its signal when the Future',
      '  // completes, without checking disposal — disposing the result before',
      '  // completion makes that write throw, and a standalone field like this',
      '  // is NOT released by DomainState.dispose (it disposes only its',
      '  // presenter). Own it through a SignalScope, or dispose it yourself.',
      '  //',
      '  // Compose with flatMap instead of threading a CancelToken through the',
      '  // presenter — each route composes on its own receiver:',
      '  //   late final related = $fieldName.flatMap((value) => useCaseFor(value));  // Future route: SignalResult',
      '  //   late final related = $fieldName.result.flatMap((value) => useCaseFor(value));  // bind route: SignalSlice',
    ];
  }

  String _buildViewState(String entityName, List<_FieldInfo> fields) {
    final viewDataName = '${entityName}ViewData';
    final lines = <String>[
      "// GENERATED by 'zfa migrate state' -- review and adjust as needed.",
      "import 'package:zuraffa/zuraffa.dart';",
      '',
      '/// View (transient UI) state for $entityName.',
      '///',
      '/// Signal-backed: every transient field lives in one [Signal] snapshot,',
      '/// so a multi-field transition inside a single `batch(...)` notifies its',
      '/// listeners exactly once, carrying the final values. The getters and',
      '/// setters keep their v5 names and types, so this file is a drop-in for',
      '/// the presenters that read those fields directly.',
      'class ${entityName}ViewState extends ViewState {',
      '  ${entityName}ViewState() {',
      '    // Constructed inside the scope boundary: the scope owns the signal,',
      '    // so disposing this state releases it (see [dispose]).',
      '    _state = _scope.run(',
      '      () => Signal<$viewDataName>(const $viewDataName()),',
      '    );',
      '    registerSignal(_state);',
      '  }',
      '',
      '  /// Owns every signal this state constructs.',
      '  final SignalScope _scope = SignalScope();',
      '',
      '  /// The whole transient state as one signal — subscribe to it (or use',
      '  /// `SignalBuilder`) to rebuild.',
      '  late final Signal<$viewDataName> _state;',
      '',
      '  /// The transient state as one signal.',
      '  Signal<$viewDataName> get state => _state;',
      '',
    ];

    if (fields.isEmpty) {
      lines.add('  // No transient UI state fields detected.');
    } else {
      for (final field in fields) {
        lines.add('  /// ${field.doc ?? field.name}');
        lines.add(
          '  ${field.type} get ${field.name} => '
          '_state.value.${field.name}'
          '${_needsBang(field) ? '!' : ''};',
        );
        lines.add('');
        lines.add('  set ${field.name}(${field.type} value) {');
        lines.add('    _state.value = $viewDataName(');
        for (final other in fields) {
          final value = other.name == field.name
              ? 'value'
              : '_state.value.${other.name}';
          lines.add('      ${other.name}: $value,');
        }
        lines.add('    );');
        lines.add('  }');
        lines.add('');
      }
    }

    lines.add('  @override');
    lines.add('  void dispose() {');
    lines.add('    _scope.dispose();');
    lines.add('    super.dispose();');
    lines.add('  }');
    lines.add('}');

    if (fields.isNotEmpty) {
      lines.add('');
      lines.addAll(_buildViewDataClass(entityName, viewDataName, fields));
    } else {
      // The constructor above already references the snapshot type, so an
      // empty snapshot class must be emitted too — without it this branch
      // would produce a file that does not compile. Unreachable today
      // (`migrate` bails unless needsMigration holds, which requires both
      // halves non-empty), kept as insurance for a future loosening of the
      // gate.
      lines.add('');
      lines.add(
        "/// Immutable snapshot of [${entityName}ViewState]'s transient fields.",
      );
      lines.add('class $viewDataName {');
      lines.add('  const $viewDataName();');
      lines.add('}');
    }

    return '${lines.join('\n')}\n';
  }

  /// The immutable snapshot behind the view state's single signal.
  ///
  /// Its `==`/`hashCode` are what let [Signal] drop a write that changes
  /// nothing, so a setter that repeats the current value stays silent.
  List<String> _buildViewDataClass(
    String entityName,
    String viewDataName,
    List<_FieldInfo> fields,
  ) {
    final params = fields
        .map((f) {
          final defaultValue = _defaultInitValue(f.type);
          final assignment = defaultValue == 'null'
              ? 'this.${f.name}'
              : 'this.${f.name} = $defaultValue';
          return assignment;
        })
        .join(', ');
    final lines = <String>[
      '/// Immutable snapshot of [${entityName}ViewState]\'s transient fields.',
      'class $viewDataName {',
      '  const $viewDataName({$params});',
      '',
    ];

    for (final field in fields) {
      lines.add('  /// ${field.doc ?? field.name}');
      lines.add('  final ${_storageType(field)} ${field.name};');
      lines.add('');
    }

    final comparisons = fields
        .map((f) => 'other.${f.name} == ${f.name}')
        .join(' &&\n      ');
    lines.add('  @override');
    lines.add('  bool operator ==(Object other) =>');
    lines.add('      other is $viewDataName &&');
    lines.add('      $comparisons;');
    lines.add('');
    lines.add('  @override');
    lines.add(
      '  int get hashCode => Object.hashAll([${fields.map((f) => f.name).join(', ')}]);',
    );
    lines.add('');
    lines.add('  @override');
    lines.add(
      "  String toString() => '$viewDataName(${fields.map((f) => '${f.name}: \$${f.name}').join(', ')})';",
    );
    lines.add('}');
    return lines;
  }

  String _defaultInitValue(String type) {
    if (type == 'bool' || type == 'bool?') return 'false';
    if (type == 'int' || type == 'int?') return '0';
    if (type == 'double' || type == 'double?') return '0.0';
    if (type == 'String' || type == 'String?') return "''";
    return 'null';
  }

  /// How a field is stored in the snapshot.
  ///
  /// A field whose declared type is non-nullable AND has a real default keeps
  /// that type, so `state.isLoading` reads as a `bool`. A field whose default
  /// can only be `null` (an entity reference the migration cannot construct)
  /// is stored nullable, exactly like the v5 backing field it replaces.
  String _storageType(_FieldInfo field) {
    if (field.type.endsWith('?')) return field.type;
    if (_defaultInitValue(field.type) == 'null') return '${field.type}?';
    return field.type;
  }

  /// Whether reading the snapshot field needs a null assertion to satisfy the
  /// getter's declared type — only the nullable-stored non-nullable fields do.
  bool _needsBang(_FieldInfo field) => _storageType(field) != field.type;

  String _stripNull(String type) => type.replaceAll('?', '');

  static const _migrationNotePrefix =
      '// NOTE: This file has been migrated to v6 dual-layer state.';

  bool _hasMigrationNote(String content) =>
      content.startsWith(_migrationNotePrefix);

  /// Prepend the supersession note once, naming the generated files.
  ///
  /// Returns `null` when [content] already carries the note — the caller then
  /// leaves the file alone instead of stacking a second header (idempotency).
  String? _annotate(
    String content,
    String domainStatePath,
    String viewStatePath,
  ) {
    if (_hasMigrationNote(content)) return null;
    return '$_migrationNotePrefix\n'
        '// See: ${p.basename(domainStatePath)} and ${p.basename(viewStatePath)}\n'
        '// This file can be removed once all references are updated.\n'
        '\n'
        '$content';
  }

  String _extractEntityName(String baseName) {
    final parts = baseName.replaceAll('_state', '').split('_');
    return parts
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join();
  }

  String _toSnake(String name) {
    final result = <String>[];
    for (int i = 0; i < name.length; i++) {
      if (i > 0 && name[i].toUpperCase() == name[i] && name[i - 1] != '_') {
        result.add('_');
      }
      result.add(name[i].toLowerCase());
    }
    return result.join();
  }

  int _lineNumber(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
  }
}

class _StateAnalysis {
  final String className;
  final int classLine;
  final List<_FieldInfo> domainFields;
  final List<_FieldInfo> uiFields;
  final bool needsMigration;

  const _StateAnalysis({
    required this.className,
    required this.classLine,
    required this.domainFields,
    required this.uiFields,
    required this.needsMigration,
  });
}

class _FieldInfo {
  final String name;
  final String type;
  final String? doc;
  const _FieldInfo({required this.name, required this.type, this.doc});
}
