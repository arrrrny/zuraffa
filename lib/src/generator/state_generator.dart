import 'package:path/path.dart' as path;
import '../core/generation/generation_context.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';

class StateGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  StateGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  StateGenerator.fromContext(GenerationContext context)
    : this(
        config: context.config,
        outputDir: context.outputDir,
        dryRun: context.dryRun,
        force: context.force,
        verbose: context.verbose,
      );

  Future<GeneratedFile> generate() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final stateName = '${entityName}State';
    final fileName = '${entitySnake}_state.dart';
    final statePathParts = <String>[outputDir, 'presentation', 'pages'];
    statePathParts.add(entitySnake);
    final stateDirPath = path.joinAll(statePathParts);
    final filePath = path.join(stateDirPath, fileName);

    final needsEntityListField = config.methods.any(
      (m) => ['getList', 'watchList'].contains(m),
    );

    final needsEntityField = config.methods.any(
      (m) => ['get', 'watch', 'create', 'update', 'delete'].contains(m),
    );

    final imports = <String>["import 'package:zuraffa/zuraffa.dart';"];

    if (needsEntityListField || needsEntityField) {
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      imports.add("import '$entityPath';");
    }

    final stateFields = <String>[];
    final stateConstructorParams = <String>[];
    final stateCopyWithParams = <String>[];

    stateFields.add('  /// The current error, if any');
    stateFields.add('  final AppFailure? error;');
    stateConstructorParams.add('this.error');
    stateCopyWithParams.add('AppFailure? error');
    stateCopyWithParams.add('bool clearError = false');

    if (needsEntityListField) {
      stateFields.add('  /// The list of $entityName entities');
      stateFields.add('  final List<$entityName> ${entityCamel}List;');
      stateConstructorParams.add('this.${entityCamel}List = const []');
      stateCopyWithParams.add('List<$entityName>? ${entityCamel}List');
    }

    if (needsEntityField) {
      stateFields.add('  /// The single $entityName entity');
      stateFields.add('  final $entityName? $entityCamel;');
      stateConstructorParams.add('this.$entityCamel');
      stateCopyWithParams.add('$entityName? $entityCamel');
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          stateFields.add('  /// Whether get operation is in progress');
          stateFields.add('  final bool isGetting;');
          stateConstructorParams.add('this.isGetting = false');
          stateCopyWithParams.add('bool? isGetting');
          break;
        case 'getList':
          stateFields.add('  /// Whether getList operation is in progress');
          stateFields.add('  final bool isGettingList;');
          stateConstructorParams.add('this.isGettingList = false');
          stateCopyWithParams.add('bool? isGettingList');
          break;
        case 'create':
          stateFields.add('  /// Whether create operation is in progress');
          stateFields.add('  final bool isCreating;');
          stateConstructorParams.add('this.isCreating = false');
          stateCopyWithParams.add('bool? isCreating');
          break;
        case 'update':
          stateFields.add('  /// Whether update operation is in progress');
          stateFields.add('  final bool isUpdating;');
          stateConstructorParams.add('this.isUpdating = false');
          stateCopyWithParams.add('bool? isUpdating');
          break;
        case 'delete':
          stateFields.add('  /// Whether delete operation is in progress');
          stateFields.add('  final bool isDeleting;');
          stateConstructorParams.add('this.isDeleting = false');
          stateCopyWithParams.add('bool? isDeleting');
          break;
        case 'watch':
          stateFields.add('  /// Whether watch operation is in progress');
          stateFields.add('  final bool isWatching;');
          stateConstructorParams.add('this.isWatching = false');
          stateCopyWithParams.add('bool? isWatching');
          break;
        case 'watchList':
          stateFields.add('  /// Whether watchList operation is in progress');
          stateFields.add('  final bool isWatchingList;');
          stateConstructorParams.add('this.isWatchingList = false');
          stateCopyWithParams.add('bool? isWatchingList');
          break;
      }
    }

    final copyWithAssignments = <String>[];
    for (final param in stateCopyWithParams) {
      if (param.contains('clear')) {
        final fieldName = param
            .replaceAll('clear', '')
            .replaceAll(' = false', '')
            .trim();
        copyWithAssignments.add(
          '$fieldName: clear$fieldName ? null : ($fieldName ?? this.$fieldName),',
        );
      } else {
        final fieldName = param.replaceAll('?', '').trim();
        copyWithAssignments.add('$fieldName: $param ?? this.$fieldName,');
      }
    }

    final loadingFields = <String>[];
    for (final method in config.methods) {
      switch (method) {
        case 'get':
          loadingFields.add('isGetting');
          break;
        case 'getList':
          loadingFields.add('isGettingList');
          break;
        case 'create':
          loadingFields.add('isCreating');
          break;
        case 'update':
          loadingFields.add('isUpdating');
          break;
        case 'delete':
          loadingFields.add('isDeleting');
          break;
        case 'watch':
          loadingFields.add('isWatching');
          break;
        case 'watchList':
          loadingFields.add('isWatchingList');
          break;
      }
    }

    final equalityChecks = <String>[];
    for (final field in stateFields) {
      if (field.contains('final bool') &&
          !field.contains('isLoading') &&
          !field.contains('error')) {
        final fieldName = field.trim().split(' ').last.replaceAll(';', '');
        equalityChecks.add(' && $fieldName == other.$fieldName');
      }
    }

    final hashCodeParts = <String>[];
    if (needsEntityListField) {
      hashCodeParts.add('${entityCamel}List.hashCode');
    }
    if (needsEntityField) {
      hashCodeParts.add('$entityCamel.hashCode');
    }
    hashCodeParts.add('error.hashCode');
    for (final method in config.methods) {
      switch (method) {
        case 'get':
          hashCodeParts.add('isGetting.hashCode');
          break;
        case 'getList':
          hashCodeParts.add('isGettingList.hashCode');
          break;
        case 'create':
          hashCodeParts.add('isCreating.hashCode');
          break;
        case 'update':
          hashCodeParts.add('isUpdating.hashCode');
          break;
        case 'delete':
          hashCodeParts.add('isDeleting.hashCode');
          break;
        case 'watch':
          hashCodeParts.add('isWatching.hashCode');
          break;
        case 'watchList':
          hashCodeParts.add('isWatchingList.hashCode');
          break;
      }
    }

    String toStringBody = '$stateName(isLoading: \$isLoading, error: \$error)';
    if (needsEntityListField && needsEntityField) {
      toStringBody =
          '$stateName(${entityCamel}List: \${${entityCamel}List.length}, $entityCamel: \$$entityCamel, isLoading: \$isLoading, error: \$error)';
    } else if (needsEntityListField) {
      toStringBody =
          '$stateName(${entityCamel}List: \${${entityCamel}List.length}, isLoading: \$isLoading, error: \$error)';
    } else if (needsEntityField) {
      toStringBody =
          '$stateName($entityCamel: \$$entityCamel, isLoading: \$isLoading, error: \$error)';
    }

    final equalityBody = <String>[];
    if (needsEntityListField) {
      equalityBody.add(
        ' &&\n          ${entityCamel}List == other.${entityCamel}List',
      );
    }
    if (needsEntityField) {
      equalityBody.add(' &&\n          $entityCamel == other.$entityCamel');
    }
    equalityBody.add(' &&\n          error == other.error');

    final content =
        '''// Generated by zfa
// zfa generate $entityName --methods=${config.methods.join(',')} --state

${imports.join('\n')}

/// Immutable state for $entityName
class $stateName {
${stateFields.join('\n')}

  const $stateName({
    ${stateConstructorParams.join(',\n    ')},
  });

  /// Create a copy of this state with the given fields replaced.
  $stateName copyWith({
    ${stateCopyWithParams.join(',\n    ')},
  }) {
    return $stateName(${_generateCopyWithBody(needsEntityListField: needsEntityListField, needsEntityField: needsEntityField, entityCamel: entityCamel)});
  }

  /// Whether any operation is currently loading
  bool get isLoading => ${loadingFields.isNotEmpty ? loadingFields.join(' || ') : 'false'};

  /// Whether there is an error to display
  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is $stateName &&
          runtimeType == other.runtimeType${equalityBody.join()}${equalityChecks.join()});

  @override
  int get hashCode =>
      ${hashCodeParts.join(' ^\n      ')};

  @override
  String toString() => '$toStringBody';
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'state',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _generateCopyWithBody({
    required bool needsEntityListField,
    required bool needsEntityField,
    required String entityCamel,
  }) {
    final parts = <String>[];

    if (needsEntityListField) {
      parts.add(
        '${entityCamel}List: ${entityCamel}List ?? this.${entityCamel}List,',
      );
    }

    if (needsEntityField) {
      parts.add('$entityCamel: $entityCamel ?? this.$entityCamel,');
    }

    parts.add('error: clearError ? null : (error ?? this.error),');

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          parts.add('isGetting: isGetting ?? this.isGetting,');
          break;
        case 'getList':
          parts.add('isGettingList: isGettingList ?? this.isGettingList,');
          break;
        case 'create':
          parts.add('isCreating: isCreating ?? this.isCreating,');
          break;
        case 'update':
          parts.add('isUpdating: isUpdating ?? this.isUpdating,');
          break;
        case 'delete':
          parts.add('isDeleting: isDeleting ?? this.isDeleting,');
          break;
        case 'watch':
          parts.add('isWatching: isWatching ?? this.isWatching,');
          break;
        case 'watchList':
          parts.add('isWatchingList: isWatchingList ?? this.isWatchingList,');
          break;
      }
    }

    return '\n    ${parts.join('\n    ')}\n    ';
  }
}
