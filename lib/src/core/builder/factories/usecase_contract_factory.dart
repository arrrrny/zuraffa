import 'package:code_builder/code_builder.dart';

import '../patterns/common_patterns.dart';
import '../patterns/usecase_patterns.dart';
import '../shared/spec_library.dart';

/// Configuration for generating an abstract UseCase contract.
///
/// This mirrors the repository interface/impl split: the contract
/// defines the abstract signature, and the default implementation
/// provides the concrete logic. Plugin modules can override the
/// binding at runtime via the DI container's `override: true`.
class UseCaseContractSpecConfig {
  /// Name of the abstract contract class (e.g. `'GetUserUseCase'`).
  final String contractClassName;

  /// Name of the default implementation class
  /// (e.g. `'DefaultGetUserUseCase'`).
  final String implClassName;

  /// The base class for the contract (e.g.
  /// `'ZuraffaUseCase<String, User>'` or
  /// `'InterceptableUseCase<String, User>'`).
  final String baseClass;

  /// The repository (or service) type the implementation depends on.
  final String repositoryType;

  /// Field name for the repository in the implementation.
  final String repositoryField;

  /// Return type (the `Out` type parameter of the base class).
  final String returnType;

  /// Input parameters type (the `In` type parameter).
  final String paramsType;

  /// Body of the `executeCall` method in the implementation.
  final String executeBody;

  /// Whether the use case has input parameters.
  final bool hasParams;

  /// Whether the use case is async.
  final bool isAsync;

  /// Import directives for both contract and impl files.
  final List<String> imports;

  const UseCaseContractSpecConfig({
    required this.contractClassName,
    required this.implClassName,
    required this.baseClass,
    required this.repositoryType,
    required this.repositoryField,
    required this.returnType,
    required this.paramsType,
    required this.executeBody,
    this.hasParams = true,
    this.isAsync = true,
    this.imports = const [],
  });
}

/// Generates an abstract UseCase contract and its default
/// implementation from a [UseCaseContractSpecConfig].
///
/// The contract is an abstract class extending the base UseCase.
/// The implementation is a concrete class that extends the contract
/// and provides the actual business logic.
///
/// ## DI binding pattern
///
/// ```dart
/// // Contract registration (core)
/// di.registerLazySingleton<GetUserUseCase>(
///   () => DefaultGetUserUseCase(di.get()),
/// );
///
/// // Plugin override
/// di.registerLazySingleton<GetUserUseCase>(
///   () => CustomGetUserUseCase(di.get()),
///   override: true,
/// );
/// ```
class UseCaseContractFactory {
  final SpecLibrary specLibrary;

  const UseCaseContractFactory({this.specLibrary = const SpecLibrary()});

  /// Generates the abstract contract class.
  Library buildContract(UseCaseContractSpecConfig config) {
    final clazz = Class(
      (b) => b
        ..name = config.contractClassName
        ..abstract = true
        ..extend = refer(config.baseClass),
    );

    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }

  /// Generates the default implementation class.
  Library buildImpl(UseCaseContractSpecConfig config) {
    final executeMethod = UseCasePatterns.executeMethod(
      returnType: config.returnType,
      paramsType: config.paramsType,
      body: config.executeBody,
      isAsync: config.isAsync,
      overrideMethod: true,
      hasParams: config.hasParams,
    );

    // If the base class is InterceptableUseCase, rename to executeCall.
    final isInterceptable = config.baseClass.contains('Interceptable');
    final Method method;
    if (isInterceptable) {
      final eb = executeMethod.toBuilder();
      eb.name = 'executeCall';
      eb.optionalParameters.add(
        Parameter(
          (p) => p
            ..name = 'context'
            ..type = refer('ZuraffaContext?'),
        ),
      );
      method = eb.build();
    } else {
      method = executeMethod;
    }

    final clazz = Class(
      (b) => b
        ..name = config.implClassName
        ..extend = refer(config.contractClassName)
        ..fields.add(CommonPatterns.finalField(
          config.repositoryField,
          config.repositoryType,
        ))
        ..constructors.add(
          CommonPatterns.constructor(
            parameters: [
              Parameter(
                (p) => p
                  ..name = config.repositoryField
                  ..toThis = true,
              ),
            ],
          ),
        )
        ..methods.add(method),
    );

    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }
}
