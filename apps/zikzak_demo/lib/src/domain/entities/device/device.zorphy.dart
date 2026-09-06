// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'device.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Device {
  Device({String? this.id, String? this.deviceToken, DeviceInfo? this.info});

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  final String? id;

  final String? deviceToken;

  final DeviceInfo? info;

  Device copyWith({String? id, String? deviceToken, DeviceInfo? info}) {
    return Device(
      id: id ?? this.id,
      deviceToken: deviceToken ?? this.deviceToken,
      info: info ?? this.info,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Device copyWithField<T>(Field<Device, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'deviceToken':
        return copyWith(deviceToken: value as String?);
      case 'info':
        return copyWith(info: value as DeviceInfo?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Device has no settable field with this name',
        );
    }
  }

  Device copyWithDevice({String? id, String? deviceToken, DeviceInfo? info}) {
    return copyWith(id: id, deviceToken: deviceToken, info: info);
  }

  Device patchWithDevice([DevicePatch? patchInput]) {
    final _patcher = patchInput ?? DevicePatch();
    final _patchMap = _patcher.patchMap;
    return Device(
      id: _patchMap.containsKey(Device$.id)
          ? ((_patchMap[Device$.id] is Function)
                    ? _patchMap[Device$.id](this.id)
                    : (_patchMap[Device$.id] is Patch)
                    ? _patchMap[Device$.id].applyTo(this.id)
                    : _patchMap[Device$.id])
                as String?
          : this.id,
      deviceToken: _patchMap.containsKey(Device$.deviceToken)
          ? ((_patchMap[Device$.deviceToken] is Function)
                    ? _patchMap[Device$.deviceToken](this.deviceToken)
                    : (_patchMap[Device$.deviceToken] is Patch)
                    ? _patchMap[Device$.deviceToken].applyTo(this.deviceToken)
                    : _patchMap[Device$.deviceToken])
                as String?
          : this.deviceToken,
      info: _patchMap.containsKey(Device$.info)
          ? ((_patchMap[Device$.info] is Function)
                    ? _patchMap[Device$.info](this.info)
                    : (_patchMap[Device$.info] is Patch)
                    ? _patchMap[Device$.info].applyTo(this.info)
                    : _patchMap[Device$.info])
                as DeviceInfo?
          : this.info,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device &&
        id == other.id &&
        deviceToken == other.deviceToken &&
        info == other.info;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.deviceToken, this.info);
  }

  @override
  String toString() {
    return 'Device(' +
        'id: ${id}' +
        ', ' +
        'deviceToken: ${deviceToken}' +
        ', ' +
        'info: ${info})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$DeviceToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension DevicePropertyHelpers on Device {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasDeviceToken {
    return this.deviceToken?.isNotEmpty == true;
  }

  bool get noDeviceToken {
    return this.deviceToken?.isEmpty ?? true;
  }

  String get deviceTokenRequired {
    return this.deviceToken ??
        (throw StateError('deviceToken is required but was null'));
  }

  bool get hasInfo {
    return this.info != null;
  }

  bool get noInfo {
    return this.info == null;
  }

  DeviceInfo get infoRequired {
    return this.info ?? (throw StateError('info is required but was null'));
  }
}

extension DeviceSerialization on Device {
  Map<String, dynamic> toJson() {
    return _$DeviceToJson(this);
  }
}

enum Device$ { id, deviceToken, info }

class DevicePatch extends PatchBase<Device, Device$> {
  Device applyTo(Device entity) {
    return entity.patchWithDevice(this);
  }

  DevicePatch withId(String? value) {
    patchMap[Device$.id] = value;
    return this;
  }

  DevicePatch withDeviceToken(String? value) {
    patchMap[Device$.deviceToken] = value;
    return this;
  }

  DevicePatch withInfo(DeviceInfo? value) {
    patchMap[Device$.info] = value;
    return this;
  }

  DevicePatch withInfoPatch(DeviceInfoPatch patch) {
    patchMap[Device$.info] = patch;
    return this;
  }

  DevicePatch withInfoPatchFunc(
    DeviceInfoPatch Function(DeviceInfoPatch) patch,
  ) {
    patchMap[Device$.info] = (dynamic current) {
      var currentPatch = DeviceInfoPatch();
      return patch(currentPatch).applyTo(current as DeviceInfo);
    };
    return this;
  }
}

/// Field descriptors for [Device] query construction
abstract final class DeviceFields {
  static const id = Field<Device, String?>('id', _$id);

  static const deviceToken = Field<Device, String?>(
    'deviceToken',
    _$deviceToken,
  );

  static const info = Field<Device, DeviceInfo?>('info', _$info);

  static String? _$id(Device e) {
    return e.id;
  }

  static String? _$deviceToken(Device e) {
    return e.deviceToken;
  }

  static DeviceInfo? _$info(Device e) {
    return e.info;
  }
}

extension DeviceCompareE on Device {
  Map<String, dynamic> compareToDevice(Device other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (deviceToken != other.deviceToken) {
      diff['deviceToken'] = () => other.deviceToken;
    }

    if (info != other.info) {
      diff['info'] = () => other.info;
    }
    return diff;
  }
}
