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

      final domainStateContent = _buildDomainState(
        entityName,
        analysis.domainFields,
      );
      final viewStateContent = _buildViewState(entityName, analysis.uiFields);

      final domainStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_domain_state.dart',
      );
      final viewStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_view_state.dart',
      );

      actions.add(
        MigrationAction(
          description:
              'Create ${p.basename(domainStatePath)} with domain data fields',
          filePath: domainStatePath,
          action: 'created',
          newContent: domainStateContent,
        ),
      );

      actions.add(
        MigrationAction(
          description:
              'Create ${p.basename(viewStatePath)} with UI state fields',
          filePath: viewStatePath,
          action: 'created',
          newContent: viewStateContent,
        ),
      );

      actions.add(
        MigrationAction(
          description:
              'Annotate ${finding.filePath} as superseded by dual-layer state',
          filePath: filePath,
          action: 'modified',
          originalContent: content,
          newContent:
              '// NOTE: This file has been migrated to v6 dual-layer state.\n// See: ${p.basename(domainStatePath)} and ${p.basename(viewStatePath)}\n// This file can be removed once all references are updated.\n\n$content',
        ),
      );

      if (!dryRun) {
        File(domainStatePath)
          ..createSync(recursive: true)
          ..writeAsStringSync(domainStateContent);
        File(viewStatePath)
          ..createSync(recursive: true)
          ..writeAsStringSync(viewStateContent);
        file.writeAsStringSync(
          '// NOTE: This file has been migrated to v6 dual-layer state.\n// See: ${p.basename(domainStatePath)} and ${p.basename(viewStatePath)}\n// This file can be removed once all references are updated.\n\n$content',
        );
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
        lines.add('  // TODO: Replace useCase and params');
        lines.add(
          "  // late final ${field.name} = bind<$typeName>('${field.name}', useCase, params);",
        );
        lines.add('');
      }
    }

    lines.add('}');
    return '${lines.join('\n')}\n';
  }

  String _buildViewState(String entityName, List<_FieldInfo> fields) {
    final lines = <String>[
      "// GENERATED by 'zfa migrate state' -- review and adjust as needed.",
      "import 'package:flutter/material.dart';",
      '',
      '/// View (transient UI) state for $entityName.',
      'class ${entityName}ViewState extends ChangeNotifier {',
      '',
    ];

    if (fields.isEmpty) {
      lines.add('  // No transient UI state fields detected.');
    } else {
      // Declare private backing fields
      for (final field in fields) {
        final declaredType = field.type.endsWith('?')
            ? field.type
            : '${field.type}?';
        final initValue = _defaultInitValue(field.type);
        lines.add('  $declaredType _${field.name} = $initValue;');
      }
      lines.add('');

      // Generate getters
      for (final field in fields) {
        lines.add('  /// ${field.doc ?? field.name}');
        lines.add(
          '  ${field.type} get ${field.name} => _${field.name}${field.type.endsWith('?') ? '' : '!'};',
        );
      }
      lines.add('');

      // Generate setters
      for (final field in fields) {
        lines.add('  set ${field.name}(${field.type} value) {');
        lines.add('    _${field.name} = value;');
        lines.add('    notifyListeners();');
        lines.add('  }');
        lines.add('');
      }
    }

    lines.add('}');
    return '${lines.join('\n')}\n';
  }

  String _defaultInitValue(String type) {
    if (type == 'bool' || type == 'bool?') return 'false';
    if (type == 'int' || type == 'int?') return '0';
    if (type == 'double' || type == 'double?') return '0.0';
    if (type == 'String' || type == 'String?') return "''";
    return 'null';
  }

  String _stripNull(String type) => type.replaceAll('?', '');

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
