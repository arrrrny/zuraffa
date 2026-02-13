import '../../models/generator_config.dart';

class SuggestionEngine {
  List<String> suggestionsFor({
    required List<String> errors,
    GeneratorConfig? config,
  }) {
    final suggestions = <String>[];
    final lower = errors.join(' ').toLowerCase();

    if (lower.contains('invalid --id-field-type')) {
      suggestions.add('Use --id-field-type=String,int,NoParams');
    }

    if (lower.contains('missing --domain')) {
      suggestions.add('Add --domain=<domain> for custom usecases');
    }

    if (lower.contains('missing --repo or --service')) {
      suggestions.add('Add --repo=<Repository> or --service=<Service>');
    }

    if (lower.contains('entity-based') &&
        (lower.contains('--repo') ||
            lower.contains('--service') ||
            lower.contains('--domain'))) {
      suggestions.add('Remove --repo/--service/--domain for entity-based');
    }

    if (lower.contains('nparams') &&
        (lower.contains('getlist') || lower.contains('watchlist'))) {
      suggestions.add(
        'Remove getList/watchList or use id-field-type String/int',
      );
    }

    if (lower.contains('json file not found')) {
      suggestions.add('Check --from-json path or run from correct directory');
    }

    if (config != null && config.methods.isEmpty && config.usecases.isEmpty) {
      suggestions.add('Add --methods or --usecases to select what to generate');
    }

    return suggestions.toSet().toList();
  }
}
