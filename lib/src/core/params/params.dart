import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'params.zorphy.dart';
part 'params.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Params {
  const $Params();

  /// Optional additional parameters.
  Map<String, dynamic>? get params;
}
