import 'package:zorphy/zorphy.dart';
import 'package:zuraffa/src/core/params/credentials.dart';
import 'package:zuraffa/src/core/params/settings.dart';

import 'locale.dart';
import 'params.dart';

part 'initialization_params.zorphy.dart';
part 'initialization_params.g.dart';

/// Parameters for initializing a repository or data source.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $InitializationParams implements $Params {
  const $InitializationParams();

  /// How long to wait for the app to initialize before timing out.

  @JsonKey(defaultValue: Duration(seconds: 5))
  Duration get timeout;

  /// Whether to bypass cached state and force a fresh initialization.
  @JsonKey(defaultValue: false)
  bool? get forceRefresh;

  /// Credentials for authentication during initialization.
  $Credentials? get credentials;

  /// Custom settings for the initialization process.
  $Settings? get settings;

  /// The locale to use for the initialization process.
  $Locale? get locale;
}
