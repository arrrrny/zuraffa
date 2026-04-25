part of 'cache_builder.dart';

extension CacheBuilderPolicy on CacheBuilder {
  Future<GeneratedFile> _generateCachePolicyFile(GeneratorConfig config) async {
    final policyType = config.cachePolicy;
    final ttlMinutes = config.ttlMinutes ?? 1440;

    String fileName;
    String policyName;
    String policyClass;
    Expression? ttlExpression;

    if (policyType == 'daily') {
      fileName = 'daily_cache_policy.dart';
      policyName = 'createDailyCachePolicy';
      policyClass = 'DailyCachePolicy';
    } else if (policyType == 'restart') {
      fileName = 'app_restart_cache_policy.dart';
      policyName = 'createAppRestartCachePolicy';
      policyClass = 'AppRestartCachePolicy';
    } else {
      fileName = 'ttl_${ttlMinutes}_minutes_cache_policy.dart';
      policyName = 'createTtl${ttlMinutes}MinutesCachePolicy';
      policyClass = 'TtlCachePolicy';
      ttlExpression = refer(
        'Duration',
      ).constInstance([], {'minutes': literalNum(ttlMinutes)});
    }

    final cachePath = path.join(outputDir, 'cache', fileName);

    final directives = [Directive.import('package:zuraffa/zuraffa.dart')];

    final timestampBoxDecl = declareFinal('timestampBox').assign(
      refer('Hive')
          .property('box')
          .call([literalString('cache_timestamps')], const {}, [refer('int')]),
    );

    final getTimestamps = _asyncLambda(
      [],
      TypeReference(
        (b) => b
          ..symbol = 'Map'
          ..types.addAll([refer('String'), refer('int')]),
      ).newInstanceNamed('from', [
        refer('timestampBox').property('toMap').call([]),
      ]),
    );

    final setTimestamp = _asyncLambda(
      [
        Parameter((p) => p..name = 'key'),
        Parameter((p) => p..name = 'timestamp'),
      ],
      refer(
        'timestampBox',
      ).property('put').call([refer('key'), refer('timestamp')]).awaited,
    );

    final removeTimestamp = _asyncLambda([
      Parameter((p) => p..name = 'key'),
    ], refer('timestampBox').property('delete').call([refer('key')]).awaited);

    final clearAll = _asyncLambda(
      [],
      refer('timestampBox').property('clear').call([]).awaited,
    );

    final policyArguments = {
      'getTimestamps': getTimestamps,
      'setTimestamp': setTimestamp,
      'removeTimestamp': removeTimestamp,
      'clearAll': clearAll,
      'ttl': ?ttlExpression,
    };

    final policyCall = refer(policyClass).call([], policyArguments);

    final method = Method(
      (m) => m
        ..name = policyName
        ..returns = refer('CachePolicy')
        ..docs.add('/// Auto-generated cache policy')
        ..body = Block(
          (b) => b
            ..statements.add(
              _earlyReturnIf(
                refer('Zuraffa').property('disableCache'),
                refer('DisabledCachePolicy').call([]),
              ),
            )
            ..statements.add(timestampBoxDecl.statement)
            ..statements.add(policyCall.returned.statement),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_policy',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  Expression _asyncLambda(List<Parameter> params, Expression body) {
    final method = Method(
      (m) => m
        ..requiredParameters.addAll(params)
        ..modifier = MethodModifier.async
        ..lambda = true
        ..body = body.code,
    );
    return method.closure;
  }

  /// Builds an early-return if-statement using code_builder expressions.
  ///
  /// Generates: `if (condition) { return returnValue; }`
  Code _earlyReturnIf(Expression condition, Expression returnValue) {
    return Block(
      (b) => b
        ..statements.add(Code('if ('))
        ..statements.add(condition.code)
        ..statements.add(Code(') {\n    return '))
        ..statements.add(returnValue.code)
        ..statements.add(Code(';\n  }\n')),
    );
  }

  Reference _futureVoidType() {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(refer('void')),
    );
  }
}
