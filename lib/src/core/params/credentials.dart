import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';
part 'credentials.zorphy.dart';
part 'credentials.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Credentials implements $Params {
  const $Credentials();
}
