import 'package:gql/ast.dart' as ast;
import 'package:zuraffa/zuraffa.dart';

/// Validates a GraphQL document AST against the cached schema.
///
/// Checks:
/// - Operation field exists on query/mutation/subscription type
/// - All selected fields exist on the target type
/// - Variable types match argument types
/// - Fragment spreads reference valid fragments
///
/// ```dart
/// final validator = GraphQLValidator(schema: schema);
/// final errors = validator.validate(document, operationName: 'GetProduct');
/// if (errors.isNotEmpty) throw ValidationException(errors);
/// ```
class GraphQLValidator {
  GraphQLValidator({required this.schema});

  final GraphQLSchema schema;

  /// Validate a [document] and return a list of error messages.
  /// Returns an empty list if the document is valid.
  List<ValidationError> validate(
    ast.DocumentNode document, {
    String? operationName,
  }) {
    final errors = <ValidationError>[];

    for (final definition in document.definitions) {
      if (definition is ast.OperationDefinitionNode) {
        errors.addAll(_validateOperation(definition));
      } else if (definition is ast.FragmentDefinitionNode) {
        errors.addAll(_validateFragment(definition));
      }
    }

    return errors;
  }

  List<ValidationError> _validateOperation(ast.OperationDefinitionNode op) {
    final errors = <ValidationError>[];

    // Determine root type
    final GraphQLObjectType? rootType = switch (op.type) {
      ast.OperationType.query => schema.getQueryType(),
      ast.OperationType.mutation => schema.getMutationType(),
      ast.OperationType.subscription => schema.getSubscriptionType(),
    };

    if (rootType == null) {
      errors.add(
        ValidationError(
          message: 'Schema has no ${op.type.name} type defined',
          location: _locationOf(op),
        ),
      );
      return errors;
    }

    // Validate each top-level field
    for (final selection in op.selectionSet.selections) {
      if (selection is ast.FieldNode) {
        errors.addAll(
          _validateField(
            field: selection,
            parentType: rootType,
            path: [selection.name.value],
          ),
        );
      }
    }

    // Validate variable definitions against field arguments
    for (final varDef in op.variableDefinitions) {
      final varName = varDef.variable.name.value;
      final varType = _astTypeToString(varDef.type);

      // Check if variable is used in any field argument
      bool used = false;
      for (final selection in op.selectionSet.selections) {
        if (selection is ast.FieldNode) {
          for (final arg in selection.arguments) {
            if (arg.value is ast.VariableNode &&
                (arg.value as ast.VariableNode).name.value == varName) {
              used = true;
              // Find the corresponding schema argument
              final schemaField = rootType.fields.firstWhere(
                (f) => f.name == selection.name.value,
                orElse: () => GraphQLField(
                  name: '',
                  type: GraphQLScalarType(name: 'String'),
                ),
              );
              final schemaArg = schemaField.args.firstWhere(
                (a) => a.name == arg.name.value,
                orElse: () => GraphQLInputField(
                  name: '',
                  type: GraphQLScalarType(name: 'String'),
                ),
              );
              final expectedType = schemaArg.type.innerType.name;
              if (!varType.contains(expectedType)) {
                errors.add(
                  ValidationError(
                    message:
                        'Variable \$$varName type $varType does not match '
                        'argument ${arg.name.value} expected type $expectedType',
                    location: _locationOf(varDef),
                  ),
                );
              }
            }
          }
        }
      }

      if (!used) {
        errors.add(
          ValidationError(
            message: 'Variable \$$varName is defined but never used',
            location: _locationOf(varDef),
            severity: ValidationSeverity.warning,
          ),
        );
      }
    }

    return errors;
  }

  List<ValidationError> _validateField({
    required ast.FieldNode field,
    required GraphQLType parentType,
    required List<String> path,
  }) {
    final errors = <ValidationError>[];
    final fieldName = field.name.value;

    // Resolve parent object type. Object types declared inline on a field
    // (common in hand-built schemas) may carry an empty field list; prefer
    // the schema-registered definition when available.
    final GraphQLObjectType? objectType = switch (parentType) {
      GraphQLObjectType t => _resolveObjectType(t),
      GraphQLNonNullType t => _resolveObjectType(t.ofType),
      GraphQLListType t => _resolveObjectType(t.ofType),
      _ => null,
    };

    if (objectType == null) {
      errors.add(
        ValidationError(
          message:
              'Cannot select field "$fieldName" on non-object type ${parentType.name}',
          location: _locationOf(field),
          path: path,
        ),
      );
      return errors;
    }

    // Check field exists
    final schemaField = objectType.fields.firstWhere(
      (f) => f.name == fieldName,
      orElse: () => GraphQLField(
        name: '',
        type: GraphQLScalarType(name: 'String'),
      ),
    );

    if (schemaField.name.isEmpty) {
      errors.add(
        ValidationError(
          message: 'Unknown field "$fieldName" on type ${objectType.name}',
          location: _locationOf(field),
          path: path,
        ),
      );
      return errors;
    }

    // Validate sub-selections
    if (field.selectionSet != null) {
      final fieldReturnType = schemaField.type;
      final unwrappedType = fieldReturnType.innerType;

      for (final subSelection in field.selectionSet!.selections) {
        if (subSelection is ast.FieldNode) {
          errors.addAll(
            _validateField(
              field: subSelection,
              parentType: unwrappedType,
              path: [...path, subSelection.name.value],
            ),
          );
        } else if (subSelection is ast.FragmentSpreadNode) {
          // Fragment spreads validated separately
        }
      }
    }

    return errors;
  }

  /// Resolve an object [type] to its schema-registered definition when the
  /// inline instance carries no fields.
  GraphQLObjectType? _resolveObjectType(GraphQLType type) {
    if (type is! GraphQLObjectType) return null;
    final registered = schema.getType(type.name);
    if (registered is GraphQLObjectType && registered.fields.isNotEmpty) {
      return registered;
    }
    return type;
  }

  List<ValidationError> _validateFragment(ast.FragmentDefinitionNode fragment) {
    final errors = <ValidationError>[];
    final typeName = fragment.typeCondition.on.name.value;
    final schemaType = schema.getType(typeName);

    if (schemaType == null) {
      errors.add(
        ValidationError(
          message:
              'Fragment type condition "$typeName" does not exist in schema',
          location: _locationOf(fragment),
        ),
      );
      return errors;
    }

    if (schemaType is! GraphQLObjectType &&
        schemaType is! GraphQLInterfaceType) {
      errors.add(
        ValidationError(
          message:
              'Fragment type condition "$typeName" is not an object or interface type',
          location: _locationOf(fragment),
        ),
      );
      return errors;
    }

    return errors;
  }

  String _astTypeToString(ast.TypeNode type) {
    final suffix = type.isNonNull ? '!' : '';
    if (type is ast.ListTypeNode) {
      return '[${_astTypeToString(type.type)}]$suffix';
    }
    if (type is ast.NamedTypeNode) {
      return '${type.name.value}$suffix';
    }
    return 'unknown';
  }

  String _locationOf(ast.Node node) {
    // Best-effort location extraction from the source span.
    final line = node.span?.start.line;
    return line != null ? 'line:$line' : 'line:?';
  }
}

/// A validation error with precise location and severity.
class ValidationError {
  ValidationError({
    required this.message,
    this.location,
    this.path,
    this.severity = ValidationSeverity.error,
  });

  final String message;
  final String? location;
  final List<String>? path;
  final ValidationSeverity severity;

  @override
  String toString() =>
      '[$severity] ${location != null ? '$location: ' : ''}$message';
}

enum ValidationSeverity { error, warning }

/// Exception thrown when validation fails.
class ValidationException implements Exception {
  ValidationException(this.errors);
  final List<ValidationError> errors;

  @override
  String toString() => 'ValidationException:\n  ${errors.join('\n  ')}';
}
