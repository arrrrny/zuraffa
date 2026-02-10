import 'package:zorphy_annotation/zorphy.dart';

part 'product.zorphy.dart';
part 'product.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Product {
  String get id;
  String get name;
  String get description;
  double get price;
  DateTime get createdAt;
}
