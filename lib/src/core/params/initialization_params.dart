import 'package:zorphy/zorphy.dart';
import 'package:zuraffa/src/core/params/credentials.dart';
import 'package:zuraffa/src/core/params/settings.dart';

import 'params.dart';

part 'initialization_params.zorphy.dart';
part 'initialization_params.g.dart';

/// Parameters for initializing a repository or data source.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $InitializationParams implements $Params {
  const $InitializationParams();

  /// How long to wait for the app to initialize before timing out.

  @JsonKey(
    toJson: DurationConverter.durationToJson,
    fromJson: DurationConverter.durationFromJson,
  )
  Duration get timeout => const Duration(seconds: 5);

  /// Whether to bypass cached state and force a fresh initialization.
  @JsonKey(defaultValue: false)
  bool? get forceRefresh;

  /// Credentials for authentication during initialization.
  $Credentials? get credentials;

  /// Custom settings for the initialization process.
  $Settings? get settings;
}

class DurationConverter {
  static Duration durationFromJson(int seconds) => Duration(seconds: seconds);
  static int durationToJson(Duration duration) => duration.inSeconds;
}
