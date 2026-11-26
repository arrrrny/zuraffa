import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/credentials.part.dart';

@ZorphyValue()
abstract class $Credentials implements $$Params {
  const $Credentials();

  /// v3 codegen does not merge base fields; declare [params] explicitly so
  /// the v2 public API (and wire round trip) is preserved (review #2179).
  @override
  Map<String, dynamic>? get params;
}
