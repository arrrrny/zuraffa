import 'dart:ui';
import 'package:zorphy/zorphy.dart';

import 'converters/locale_converter.dart';
import 'params.dart';

part 'initialization_params.zorphy.dart';
part 'initialization_params.g.dart';

/// Parameters for initializing a repository or data source.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $InitializationParams {
  const $InitializationParams();

  /// How long to wait for the app to initialize before timing out.
  Duration get timeout => Duration(seconds: 5);

  /// Whether to bypass cached state and force a fresh initialization.
  bool get forceRefresh => true;

  /// Optional parameters to pass during startup.
  $Params? get params;

  /// Credentials for authentication during initialization.
  $Params? get credentials;

  /// Custom settings for the initialization process.
  $Params? get settings;

  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: LocaleConverter.toJson,
    fromJson: LocaleConverter.fromJson,
  )
  Locale? get locale;
}
