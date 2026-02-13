import 'package:zorphy_annotation/zorphy.dart';

part 'locale.zorphy.dart';
part 'locale.g.dart';

@Zorphy(generateJson: true)
abstract class $Locale {
  @JsonKey(defaultValue: 'en')
  String get languageCode;
  String? get countryCode;
}
