import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';
part 'settings.zorphy.dart';
part 'settings.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Settings implements $Params {
  const $Settings();
}
