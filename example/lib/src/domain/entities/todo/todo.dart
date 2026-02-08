import 'package:zorphy_annotation/zorphy.dart';

part 'todo.zorphy.dart';
part 'todo.g.dart';

@Zorphy(generateJson: true, generateFilter: true)
abstract class $Todo {
  int get id;
  String get title;
  bool get isCompleted;
  DateTime get createdAt;
}
