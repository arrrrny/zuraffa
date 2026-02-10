import '../../generator/cache_generator.dart';
import '../../generator/graphql_generator.dart';
import '../../generator/method_appender.dart';
import '../../generator/observer_generator.dart';
import '../../generator/provider_generator.dart';
import '../../generator/route_generator.dart';
import '../../generator/state_generator.dart';
import '../../generator/test_generator.dart';
import 'generation_context.dart';

class CodeBuilderFactory {
  final GenerationContext context;

  const CodeBuilderFactory(this.context);

  ProviderGenerator provider() => ProviderGenerator.fromContext(context);

  StateGenerator state() => StateGenerator.fromContext(context);

  ObserverGenerator observer() => ObserverGenerator.fromContext(context);

  TestGenerator test() => TestGenerator.fromContext(context);

  CacheGenerator cache() => CacheGenerator.fromContext(context);

  GraphQLGenerator graphql() => GraphQLGenerator.fromContext(context);

  RouteGenerator route() => RouteGenerator.fromContext(context);

  MethodAppender methodAppender() => MethodAppender.fromContext(context);
}
