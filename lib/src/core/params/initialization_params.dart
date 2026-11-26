import 'package:zorphy_annotation/zorphy_annotation.dart';
import 'package:zuraffa/src/core/params/credentials.dart';
import 'package:zuraffa/src/core/params/settings.dart';

import 'params.dart';

part '../../../_br_/src/core/params/initialization_params.part.dart';

/// Parameters for initializing a repository or data source.
@ZorphyValue()
abstract class $InitializationParams implements Params {
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

  /// v3 codegen does not merge base fields; declare [params] explicitly so
  /// the v2 public API (and wire round trip) is preserved (review #2179).
  @override
  Map<String, dynamic>? get params;
}

class DurationConverter {
  static Duration durationFromJson(int seconds) => Duration(seconds: seconds);
  static int durationToJson(Duration duration) => duration.inSeconds;
}
