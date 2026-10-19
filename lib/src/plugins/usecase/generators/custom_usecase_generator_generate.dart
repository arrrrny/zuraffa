part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorGenerate on CustomUseCaseGenerator {
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    // Resolve the service method name from the on-disk service interface
    // instead of inventing it from the use-case name (#1799). When the
    // service declares a single method, that method is used; when it
    // declares several, the one whose params/returns match this request is
    // used. If the surface cannot be resolved, refuse with a named fix
    // rather than writing a use case that cannot compile.
    var resolvedConfig = config;
    if (config.hasService && config.serviceMethod == null) {
      final serviceName = config.effectiveService;
      final serviceSnake = config.serviceSnake;
      if (serviceName != null && serviceSnake != null) {
        final filePath = config.isEntityBased
            ? path.join(
                config.outputDir,
                'domain',
                'services',
                config.effectiveDomain,
                '$serviceSnake.dart',
              )
            : path.join(
                config.outputDir,
                'domain',
                'services',
                '$serviceSnake.dart',
              );
        final declared = await MethodExtractor.extractMethodsFromInterface(
          filePath,
          serviceName,
          fileSystem: fileSystem,
        );

        String? resolved;
        if (declared.isEmpty) {
          throw ArgumentError(
            'service interface not found or declares no methods: '
            '$serviceName ($filePath). Create it first with: '
            'zfa service create ${config.name} --service=$serviceName '
            '--methods=<method>  (see zuraffa issue #1799)',
          );
        }

        final paramsType = config.paramsType ?? 'NoParams';
        final returnsType = config.returnsType ?? 'void';

        final matches = declared.where((m) {
          final pOk = m.paramsType == paramsType;
          final rOk = m.returnsType == returnsType;
          return pOk && rOk;
        }).toList();

        if (matches.length == 1) {
          resolved = matches.first.fieldName;
        } else if (matches.isEmpty &&
            declared.length == 1 &&
            (config.paramsType == null || config.hasMultipleParams)) {
          // Single declared method: trust it when params/returns were not
          // supplied (or use multiple params) — the interface is the
          // authority on the method name (issue #1799).
          resolved = declared.first.fieldName;
        } else if (matches.length > 1) {
          throw ArgumentError(
            'ambiguous service method: $serviceName declares '
            '${matches.map((m) => m.fieldName).join(', ')} matching '
            '$paramsType -> $returnsType. Refine --params/--returns. '
            '(zuraffa issue #1799)',
          );
        } else {
          throw ArgumentError(
            'no service method on $serviceName matches '
            '$paramsType -> $returnsType. Declared: '
            '${declared.map((m) => '${m.fieldName}(${m.paramsType}) -> ${m.returnsType}').join(', ')}. '
            'Adjust --params/--returns or create the method with: '
            'zfa service create ${config.name} --service=$serviceName '
            '--methods=<method>  (zuraffa issue #1799)',
          );
        }

        resolvedConfig = config.copyWith(serviceMethod: resolved);
      }
    }

    config = resolvedConfig;

    // 1. Check for required Domain for non-entity usecases
    if (config.useCaseType != 'entity' && config.domain == null) {
      throw ArgumentError(
        'For non-entity usecases (like ${config.useCaseType}), you must specify a domain using --domain.',
      );
    }

    // 2. Check for required dependencies for specific types
    if (!config.revert &&
        config.useCaseType != 'sync' &&
        !config.hasRepo &&
        !config.hasService) {
      throw ArgumentError(
        'For ${config.useCaseType} usecases, you must specify a repository or service using --repo or --service. Only --type=sync allows no dependencies.',
      );
    }

    // Issue #1723 review: normalize config.name before deriving class and
    // file names (see generateOrchestrator above).
    final className = StringUtils.normalizeUseCaseClassName(config.name);
    final baseName = className.substring(
      0,
      className.length - 'UseCase'.length,
    );
    final classSnake = StringUtils.camelToSnake(baseName);
    final fileName = '${classSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.hasMultipleParams
        ? '${baseName}Params'
        : (config.paramsType ?? 'NoParams');
    final returnsType = config.returnsType ?? 'void';
    // Users may pass an already-Future return type (e.g. `--returns Future<void>`).
    // The usecase type already wraps the inner type in a Future, so strip a leading
    // `Future<...>` to avoid `Future<Future<void>>` and bogus entity imports (#419).
    final innerReturnsType = _stripFutureReturns(returnsType);

    final baseClass = _baseClass(config, paramsType, innerReturnsType);
    final imports = await _buildImports(config, paramsType, innerReturnsType);
    final fields = _buildDependencyFields(config);
    final constructorParams = _buildDependencyParams(fields);
    final methods = _buildMethods(config, paramsType, innerReturnsType, fields);

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: fields,
      constructors: constructorParams.isEmpty
          ? const []
          : [
              Constructor(
                (b) => b..requiredParameters.addAll(constructorParams),
              ),
            ],
      methods: methods,
      imports: imports,
    );

    var content = classBuilder.build(
      spec,
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    if (config.hasMultipleParams) {
      final paramsClass = Class(
        (b) => b
          ..name = paramsType
          ..fields.addAll(
            config.multipleParams.map(
              (p) => Field(
                (f) => f
                  ..name = p.name
                  ..type = refer(p.type)
                  ..modifier = FieldModifier.final$,
              ),
            ),
          )
          ..constructors.add(
            Constructor(
              (c) => c
                ..constant = true
                ..optionalParameters.addAll(
                  config.multipleParams.map(
                    (p) => Parameter(
                      (pp) => pp
                        ..name = p.name
                        ..toThis = true
                        ..named = true
                        ..required = true,
                    ),
                  ),
                ),
            ),
          ),
      );
      final emitter = DartEmitter(
        allocator: Allocator.simplePrefixing(),
        orderDirectives: true,
      );
      content += '\n\n${paramsClass.accept(emitter)}';
    }

    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      methodSources: _methodSourcesForAppend(
        config,
        paramsType,
        innerReturnsType,
        fields,
      ),
      content: content,
    );
  }
}

/// Strips a leading `Future<...>` (or bare `Future`) wrapper from a return type
/// so it can be used as the inner type when the usecase type already wraps it.
///
/// Examples: `Future<void>` -> `void`, `Future<List<Item>>` -> `List<Item>`,
/// `Future` -> `void`, `List<Item>` -> `List<Item>` (unchanged).
String _stripFutureReturns(String type) {
  final trimmed = type.trim();
  if (trimmed.startsWith('Future<') && trimmed.endsWith('>')) {
    return trimmed.substring('Future<'.length, trimmed.length - 1);
  }
  if (trimmed == 'Future' || trimmed == 'Future?') {
    return 'void';
  }
  return trimmed;
}
