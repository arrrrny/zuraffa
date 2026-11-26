// dart format off
part of '../../../../src/core/params/update_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class UpdateParams<I, P> implements ZorphyValueBase {
  const UpdateParams.fromTrusted({required this.id, required this.data});

  final I id;

  final P data;

  UpdateParams<I, P> copyWith({I? id, P? data}) {
    return UpdateParams<I, P>.fromTrusted(
      id: id ?? this.id,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateParams &&
        this.id == other.id &&
        this.data == other.data;
  }

  @override
  int get hashCode => Object.hashAll([id, data]);

  @override
  String toString() => 'UpdateParams(id: $id, data: $data)';
}

