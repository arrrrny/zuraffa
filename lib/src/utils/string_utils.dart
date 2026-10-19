class StringUtils {
  /// Normalizes a raw `--usecases` token to the canonical UseCase class name
  /// (issue #1720).
  ///
  /// Accepts any documented token form — `login`, `Login`, `loginUseCase`,
  /// `LoginUseCase`, `sign_in_with_google` — and always returns a PascalCase
  /// class name with exactly one `UseCase` suffix (`LoginUseCase`,
  /// `SignInWithGoogleUseCase`), matching the class declared in the
  /// `<snake>_usecase.dart` file the same generator resolves for imports.
  ///
  /// The suffix is stripped only once and only from the end, so passing a
  /// full class name never doubles it (`LoginUseCase` → `LoginUseCase`, not
  /// `LoginUseCaseUseCase`). The degenerate bare token `UseCase` strips to an
  /// empty base and comes back as `UseCase` — no input form doubles the
  /// suffix.
  static String normalizeUseCaseClassName(String token) {
    var base = token.trim();
    const suffix = 'UseCase';
    if (base.endsWith(suffix) && base.length >= suffix.length) {
      base = base.substring(0, base.length - suffix.length);
    }
    return '${convertToPascalCase(base)}$suffix';
  }

  static String camelToSnake(String input) {
    if (input.isEmpty) return '';
    final result = <String>[];
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == ' ') {
        if (result.isNotEmpty && result.last != '_') {
          result.add('_');
        }
        continue;
      }
      // Only add underscore before actual uppercase letters
      if (i > 0 &&
          char.toLowerCase() != char &&
          char.toUpperCase() == char &&
          char != '_' &&
          input[i - 1] != '_' &&
          input[i - 1] != ' ') {
        result.add('_');
      }
      result.add(char.toLowerCase());
    }
    return result.join();
  }

  static String pascalToCamel(String input) {
    if (input.isEmpty) return '';
    return input[0].toLowerCase() + input.substring(1);
  }

  static String convertToPascalCase(String text) {
    var finalText = '';
    var words = text.split('_');

    for (var word in words) {
      if (word.isEmpty) continue;
      finalText += word[0].toUpperCase() + word.substring(1);
    }

    return finalText;
  }

  static String capitalize(String input) {
    if (input.isEmpty) return '';
    return input[0].toUpperCase() + input.substring(1);
  }

  static String toContinuous(String name) {
    if (name.isEmpty) return '';

    // Sanitize input: remove common non-identifier characters that might come
    // from typos in flags (e.g., '-methods=get' -> 'ethods=get').
    // We only keep alphanumeric characters for the continuous name.
    final sanitizedName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (sanitizedName.isEmpty) return 'Operation';

    final lower = sanitizedName.toLowerCase();

    // Handle PascalCase/camelCase by checking for common verbs at the start
    final verbs = [
      'Check',
      'Request',
      'Get',
      'Create',
      'Update',
      'Delete',
      'Watch',
      'Send',
      'Open',
      'Verify',
      'Fetch',
      'Load',
    ];

    for (final verb in verbs) {
      if ((sanitizedName.startsWith(verb) ||
              sanitizedName.startsWith(pascalToCamel(verb))) &&
          sanitizedName.length > verb.length) {
        final rest = sanitizedName.substring(verb.length);
        return '${toContinuous(verb)}$rest';
      }
    }

    // Exact matches for standard methods
    if (lower == 'get') return 'Getting';
    if (lower == 'list' || lower == 'getlist') return 'GettingList';
    if (lower == 'create') return 'Creating';
    if (lower == 'update') return 'Updating';
    if (lower == 'delete') return 'Deleting';
    if (lower == 'watch') return 'Watching';
    if (lower == 'watchlist') return 'WatchingList';

    // If it already ends with 'ing', capitalize and return
    if (lower.endsWith('ing')) return capitalize(sanitizedName);

    // Heuristics for others
    if (lower.endsWith('e')) {
      return '${capitalize(sanitizedName.substring(0, sanitizedName.length - 1))}ing';
    }

    return '${capitalize(sanitizedName)}ing';
  }

  static String snakeToPath(String input) {
    if (input.isEmpty) return '';
    return input.replaceAll('_', '/');
  }

  /// Pluralizes an identifier preserving its casing.
  ///
  /// Handles the common English cases used by entity names so generated
  /// mock data exposes its collection under a conventional plural
  /// (`SearchQuery` -> `searchQueries`, `Address` -> `addresses`) instead of a
  /// naive `+ 's'` (`searchQuerys`). Applies the consonant + `y` -> `ies`
  /// rule and the `s`/`x`/`z`/`ch`/`sh` -> `es` rule. One helper produces the
  /// name everywhere so the mock data class and every reference to it agree.
  static String pluralize(String input) {
    if (input.isEmpty) return input;
    final lower = input.toLowerCase();
    if (lower.endsWith('y') && input.length >= 2) {
      final prev = lower[input.length - 2];
      if (!'aeiou'.contains(prev)) {
        return '${input.substring(0, input.length - 1)}ies';
      }
    }
    if (lower.endsWith('s') ||
        lower.endsWith('x') ||
        lower.endsWith('z') ||
        lower.endsWith('ch') ||
        lower.endsWith('sh')) {
      return '${input}es';
    }
    return '${input}s';
  }
}
