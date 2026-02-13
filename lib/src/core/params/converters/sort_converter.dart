import 'package:zorphy_annotation/zorphy_annotation.dart';

class SortConverter {
  SortConverter._();

  static Map<String, dynamic>? toJson(Sort<dynamic>? sort) {
    if (sort == null) return null;
    return sort.toJson();
  }

  static Sort<dynamic>? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final fieldName = json['field'] as String?;
    if (fieldName == null) return null;
    final field = Field<dynamic, dynamic>(fieldName, null);
    final descending = json['descending'] as bool? ?? false;
    return Sort(field, descending: descending);
  }
}
