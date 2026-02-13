import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'params.zorphy.dart';
part 'params.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Params {
  Map<String, dynamic>? get params;
}
