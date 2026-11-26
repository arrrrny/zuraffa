// dart format off
part of '../../../../src/core/params/create_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class CreateParams<T> implements ZorphyValueBase {
  const CreateParams.fromTrusted({required this.data});

  final T data;

  CreateParams<T> copyWith({T? data}) {
    return CreateParams<T>.fromTrusted(data: data ?? this.data);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateParams && this.data == other.data;
  }

  @override
  int get hashCode => Object.hashAll([data]);

  @override
  String toString() => 'CreateParams(data: $data)';
}

