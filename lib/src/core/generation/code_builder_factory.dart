import '../../plugins/cache/builders/cache_builder.dart';
import '../../plugins/graphql/builders/graphql_builder.dart';
import '../../plugins/method_append/builders/method_append_builder.dart';
import '../../plugins/observer/builders/observer_builder.dart';
import '../../plugins/provider/builders/provider_builder.dart';
import '../../plugins/route/builders/route_builder.dart';
import '../../plugins/state/builders/state_builder.dart';
import '../../plugins/test/builders/test_builder.dart';
import 'generation_context.dart';

class CodeBuilderFactory {
  final GenerationContext context;

  const CodeBuilderFactory(this.context);

  ProviderBuilder provider() => ProviderBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  StateBuilder state() => StateBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  ObserverBuilder observer() => ObserverBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  TestBuilder test() => TestBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  CacheBuilder cache() => CacheBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  GraphqlBuilder graphql() => GraphqlBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  RouteBuilder route() => RouteBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );

  MethodAppendBuilder methodAppender() => MethodAppendBuilder(
    outputDir: context.outputDir,
    dryRun: context.dryRun,
    force: context.force,
    verbose: context.verbose,
  );
}
