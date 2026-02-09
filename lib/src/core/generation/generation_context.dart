import '../../models/generator_config.dart';

class GenerationContext {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  const GenerationContext({
    required this.config,
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });
}
