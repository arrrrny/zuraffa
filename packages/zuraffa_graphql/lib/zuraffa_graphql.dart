/// GraphQL capability for Zuraffa (optional companion package).
///
/// Spec 1653-trim-heavy-deps (issue #1661): the graphql/gql-backed
/// surface moved out of the core package so core-only consumers stop
/// carrying the GraphQL stack. See the core CHANGELOG for the migration
/// map (old core export -> this package).
library;

export 'src/client/graphql_client_factory.dart';
export 'src/client/graphql_client_provider.dart';
export 'src/client/subscription_stream.dart';
export 'src/datasource_generator.dart';
export 'src/di_generator.dart';
export 'src/gql/documents_dart_generator.dart';
export 'src/gql/graphql_document_builder.dart';
export 'src/gql/naming_utils.dart';
export 'src/graphql_generate_command.dart';
export 'src/preservers/gql_file_preserver.dart';
export 'src/slice_orchestrator.dart';
export 'src/validators/graphql_validator.dart';
