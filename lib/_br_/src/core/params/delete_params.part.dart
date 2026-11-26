// dart format off
part of '../../../../src/core/params/delete_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class DeleteParams<I> implements ZorphyValueBase {
  const DeleteParams.fromTrusted({required this.id});

  final I id;

  DeleteParams<I> copyWith({I? id}) {
    return DeleteParams<I>.fromTrusted(id: id ?? this.id);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteParams && this.id == other.id;
  }

  @override
  int get hashCode => Object.hashAll([id]);

  @override
  String toString() => 'DeleteParams(id: $id)';
}

