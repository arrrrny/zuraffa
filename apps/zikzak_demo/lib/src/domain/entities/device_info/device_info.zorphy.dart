// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'device_info.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class DeviceInfo {
  DeviceInfo({
    String? this.systemName,
    String? this.deviceModel,
    String? this.systemVersion,
    String? this.deviceId,
    String? this.brand,
    String? this.manufacturer,
    bool? this.isPhysicalDevice,
    Map<String, dynamic>? this.additionalProperties,
    required OperatingSystem this.os,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);

  final String? systemName;

  final String? deviceModel;

  final String? systemVersion;

  final String? deviceId;

  final String? brand;

  final String? manufacturer;

  final bool? isPhysicalDevice;

  final Map<String, dynamic>? additionalProperties;

  final OperatingSystem os;

  DeviceInfo copyWith({
    String? systemName,
    String? deviceModel,
    String? systemVersion,
    String? deviceId,
    String? brand,
    String? manufacturer,
    bool? isPhysicalDevice,
    Map<String, dynamic>? additionalProperties,
    OperatingSystem? os,
  }) {
    return DeviceInfo(
      systemName: systemName ?? this.systemName,
      deviceModel: deviceModel ?? this.deviceModel,
      systemVersion: systemVersion ?? this.systemVersion,
      deviceId: deviceId ?? this.deviceId,
      brand: brand ?? this.brand,
      manufacturer: manufacturer ?? this.manufacturer,
      isPhysicalDevice: isPhysicalDevice ?? this.isPhysicalDevice,
      additionalProperties: additionalProperties ?? this.additionalProperties,
      os: os ?? this.os,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  DeviceInfo copyWithField<T>(Field<DeviceInfo, T> field, T value) {
    switch (field.name) {
      case 'systemName':
        return copyWith(systemName: value as String?);
      case 'deviceModel':
        return copyWith(deviceModel: value as String?);
      case 'systemVersion':
        return copyWith(systemVersion: value as String?);
      case 'deviceId':
        return copyWith(deviceId: value as String?);
      case 'brand':
        return copyWith(brand: value as String?);
      case 'manufacturer':
        return copyWith(manufacturer: value as String?);
      case 'isPhysicalDevice':
        return copyWith(isPhysicalDevice: value as bool?);
      case 'additionalProperties':
        return copyWith(additionalProperties: value as Map<String, dynamic>?);
      case 'os':
        return copyWith(os: value as OperatingSystem);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'DeviceInfo has no settable field with this name',
        );
    }
  }

  DeviceInfo copyWithDeviceInfo({
    String? systemName,
    String? deviceModel,
    String? systemVersion,
    String? deviceId,
    String? brand,
    String? manufacturer,
    bool? isPhysicalDevice,
    Map<String, dynamic>? additionalProperties,
    OperatingSystem? os,
  }) {
    return copyWith(
      systemName: systemName,
      deviceModel: deviceModel,
      systemVersion: systemVersion,
      deviceId: deviceId,
      brand: brand,
      manufacturer: manufacturer,
      isPhysicalDevice: isPhysicalDevice,
      additionalProperties: additionalProperties,
      os: os,
    );
  }

  DeviceInfo patchWithDeviceInfo([DeviceInfoPatch? patchInput]) {
    final _patcher = patchInput ?? DeviceInfoPatch();
    final _patchMap = _patcher.patchMap;
    return DeviceInfo(
      systemName: _patchMap.containsKey(DeviceInfo$.systemName)
          ? ((_patchMap[DeviceInfo$.systemName] is Function)
                    ? _patchMap[DeviceInfo$.systemName](this.systemName)
                    : (_patchMap[DeviceInfo$.systemName] is Patch)
                    ? _patchMap[DeviceInfo$.systemName].applyTo(this.systemName)
                    : _patchMap[DeviceInfo$.systemName])
                as String?
          : this.systemName,
      deviceModel: _patchMap.containsKey(DeviceInfo$.deviceModel)
          ? ((_patchMap[DeviceInfo$.deviceModel] is Function)
                    ? _patchMap[DeviceInfo$.deviceModel](this.deviceModel)
                    : (_patchMap[DeviceInfo$.deviceModel] is Patch)
                    ? _patchMap[DeviceInfo$.deviceModel].applyTo(
                        this.deviceModel,
                      )
                    : _patchMap[DeviceInfo$.deviceModel])
                as String?
          : this.deviceModel,
      systemVersion: _patchMap.containsKey(DeviceInfo$.systemVersion)
          ? ((_patchMap[DeviceInfo$.systemVersion] is Function)
                    ? _patchMap[DeviceInfo$.systemVersion](this.systemVersion)
                    : (_patchMap[DeviceInfo$.systemVersion] is Patch)
                    ? _patchMap[DeviceInfo$.systemVersion].applyTo(
                        this.systemVersion,
                      )
                    : _patchMap[DeviceInfo$.systemVersion])
                as String?
          : this.systemVersion,
      deviceId: _patchMap.containsKey(DeviceInfo$.deviceId)
          ? ((_patchMap[DeviceInfo$.deviceId] is Function)
                    ? _patchMap[DeviceInfo$.deviceId](this.deviceId)
                    : (_patchMap[DeviceInfo$.deviceId] is Patch)
                    ? _patchMap[DeviceInfo$.deviceId].applyTo(this.deviceId)
                    : _patchMap[DeviceInfo$.deviceId])
                as String?
          : this.deviceId,
      brand: _patchMap.containsKey(DeviceInfo$.brand)
          ? ((_patchMap[DeviceInfo$.brand] is Function)
                    ? _patchMap[DeviceInfo$.brand](this.brand)
                    : (_patchMap[DeviceInfo$.brand] is Patch)
                    ? _patchMap[DeviceInfo$.brand].applyTo(this.brand)
                    : _patchMap[DeviceInfo$.brand])
                as String?
          : this.brand,
      manufacturer: _patchMap.containsKey(DeviceInfo$.manufacturer)
          ? ((_patchMap[DeviceInfo$.manufacturer] is Function)
                    ? _patchMap[DeviceInfo$.manufacturer](this.manufacturer)
                    : (_patchMap[DeviceInfo$.manufacturer] is Patch)
                    ? _patchMap[DeviceInfo$.manufacturer].applyTo(
                        this.manufacturer,
                      )
                    : _patchMap[DeviceInfo$.manufacturer])
                as String?
          : this.manufacturer,
      isPhysicalDevice: _patchMap.containsKey(DeviceInfo$.isPhysicalDevice)
          ? ((_patchMap[DeviceInfo$.isPhysicalDevice] is Function)
                    ? _patchMap[DeviceInfo$.isPhysicalDevice](
                        this.isPhysicalDevice,
                      )
                    : (_patchMap[DeviceInfo$.isPhysicalDevice] is Patch)
                    ? _patchMap[DeviceInfo$.isPhysicalDevice].applyTo(
                        this.isPhysicalDevice,
                      )
                    : _patchMap[DeviceInfo$.isPhysicalDevice])
                as bool?
          : this.isPhysicalDevice,
      additionalProperties:
          _patchMap.containsKey(DeviceInfo$.additionalProperties)
          ? ((_patchMap[DeviceInfo$.additionalProperties] is Function)
                    ? _patchMap[DeviceInfo$.additionalProperties](
                        this.additionalProperties,
                      )
                    : (_patchMap[DeviceInfo$.additionalProperties] is Patch)
                    ? _patchMap[DeviceInfo$.additionalProperties].applyTo(
                        this.additionalProperties,
                      )
                    : _patchMap[DeviceInfo$.additionalProperties])
                as Map<String, dynamic>?
          : this.additionalProperties,
      os: _patchMap.containsKey(DeviceInfo$.os)
          ? ((_patchMap[DeviceInfo$.os] is Function)
                    ? _patchMap[DeviceInfo$.os](this.os)
                    : (_patchMap[DeviceInfo$.os] is Patch)
                    ? _patchMap[DeviceInfo$.os].applyTo(this.os)
                    : _patchMap[DeviceInfo$.os])
                as OperatingSystem
          : this.os,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        systemName == other.systemName &&
        deviceModel == other.deviceModel &&
        systemVersion == other.systemVersion &&
        deviceId == other.deviceId &&
        brand == other.brand &&
        manufacturer == other.manufacturer &&
        isPhysicalDevice == other.isPhysicalDevice &&
        additionalProperties == other.additionalProperties &&
        os == other.os;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.systemName,
      this.deviceModel,
      this.systemVersion,
      this.deviceId,
      this.brand,
      this.manufacturer,
      this.isPhysicalDevice,
      this.additionalProperties,
      this.os,
    );
  }

  @override
  String toString() {
    return 'DeviceInfo(' +
        'systemName: ${systemName}' +
        ', ' +
        'deviceModel: ${deviceModel}' +
        ', ' +
        'systemVersion: ${systemVersion}' +
        ', ' +
        'deviceId: ${deviceId}' +
        ', ' +
        'brand: ${brand}' +
        ', ' +
        'manufacturer: ${manufacturer}' +
        ', ' +
        'isPhysicalDevice: ${isPhysicalDevice}' +
        ', ' +
        'additionalProperties: ${additionalProperties}' +
        ', ' +
        'os: ${os})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$DeviceInfoToJson(this);
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

extension DeviceInfoPropertyHelpers on DeviceInfo {
  bool get hasSystemName {
    return this.systemName?.isNotEmpty == true;
  }

  bool get noSystemName {
    return this.systemName?.isEmpty ?? true;
  }

  String get systemNameRequired {
    return this.systemName ??
        (throw StateError('systemName is required but was null'));
  }

  bool get hasDeviceModel {
    return this.deviceModel?.isNotEmpty == true;
  }

  bool get noDeviceModel {
    return this.deviceModel?.isEmpty ?? true;
  }

  String get deviceModelRequired {
    return this.deviceModel ??
        (throw StateError('deviceModel is required but was null'));
  }

  bool get hasSystemVersion {
    return this.systemVersion?.isNotEmpty == true;
  }

  bool get noSystemVersion {
    return this.systemVersion?.isEmpty ?? true;
  }

  String get systemVersionRequired {
    return this.systemVersion ??
        (throw StateError('systemVersion is required but was null'));
  }

  bool get hasDeviceId {
    return this.deviceId?.isNotEmpty == true;
  }

  bool get noDeviceId {
    return this.deviceId?.isEmpty ?? true;
  }

  String get deviceIdRequired {
    return this.deviceId ??
        (throw StateError('deviceId is required but was null'));
  }

  bool get hasBrand {
    return this.brand?.isNotEmpty == true;
  }

  bool get noBrand {
    return this.brand?.isEmpty ?? true;
  }

  String get brandRequired {
    return this.brand ?? (throw StateError('brand is required but was null'));
  }

  bool get hasManufacturer {
    return this.manufacturer?.isNotEmpty == true;
  }

  bool get noManufacturer {
    return this.manufacturer?.isEmpty ?? true;
  }

  String get manufacturerRequired {
    return this.manufacturer ??
        (throw StateError('manufacturer is required but was null'));
  }

  bool get hasIsPhysicalDevice {
    return this.isPhysicalDevice != null;
  }

  bool get noIsPhysicalDevice {
    return this.isPhysicalDevice == null;
  }

  bool get isPhysicalDeviceRequired {
    return this.isPhysicalDevice ??
        (throw StateError('isPhysicalDevice is required but was null'));
  }

  Map<String, dynamic> get additionalPropertiesRequired {
    return this.additionalProperties ??
        (throw StateError('additionalProperties is required but was null'));
  }

  bool get hasAdditionalProperties {
    return this.additionalProperties?.isNotEmpty ?? false;
  }

  bool get noAdditionalProperties {
    return this.additionalProperties?.isEmpty ?? true;
  }

  bool get isOsIos {
    return this.os == OperatingSystem.ios;
  }

  bool get isOsAndroid {
    return this.os == OperatingSystem.android;
  }

  bool get isOsMacos {
    return this.os == OperatingSystem.macos;
  }

  bool get isOsWindows {
    return this.os == OperatingSystem.windows;
  }

  bool get isOsLinux {
    return this.os == OperatingSystem.linux;
  }

  bool get isOsWeb {
    return this.os == OperatingSystem.web;
  }
}

extension DeviceInfoSerialization on DeviceInfo {
  Map<String, dynamic> toJson() {
    return _$DeviceInfoToJson(this);
  }
}

enum DeviceInfo$ {
  systemName,
  deviceModel,
  systemVersion,
  deviceId,
  brand,
  manufacturer,
  isPhysicalDevice,
  additionalProperties,
  os,
}

class DeviceInfoPatch extends PatchBase<DeviceInfo, DeviceInfo$> {
  DeviceInfo applyTo(DeviceInfo entity) {
    return entity.patchWithDeviceInfo(this);
  }

  DeviceInfoPatch withSystemName(String? value) {
    patchMap[DeviceInfo$.systemName] = value;
    return this;
  }

  DeviceInfoPatch withDeviceModel(String? value) {
    patchMap[DeviceInfo$.deviceModel] = value;
    return this;
  }

  DeviceInfoPatch withSystemVersion(String? value) {
    patchMap[DeviceInfo$.systemVersion] = value;
    return this;
  }

  DeviceInfoPatch withDeviceId(String? value) {
    patchMap[DeviceInfo$.deviceId] = value;
    return this;
  }

  DeviceInfoPatch withBrand(String? value) {
    patchMap[DeviceInfo$.brand] = value;
    return this;
  }

  DeviceInfoPatch withManufacturer(String? value) {
    patchMap[DeviceInfo$.manufacturer] = value;
    return this;
  }

  DeviceInfoPatch withIsPhysicalDevice(bool? value) {
    patchMap[DeviceInfo$.isPhysicalDevice] = value;
    return this;
  }

  DeviceInfoPatch withAdditionalProperties(Map<String, dynamic>? value) {
    patchMap[DeviceInfo$.additionalProperties] = value;
    return this;
  }

  DeviceInfoPatch withOs(OperatingSystem? value) {
    patchMap[DeviceInfo$.os] = value;
    return this;
  }
}

/// Field descriptors for [DeviceInfo] query construction
abstract final class DeviceInfoFields {
  static const systemName = Field<DeviceInfo, String?>(
    'systemName',
    _$systemName,
  );

  static const deviceModel = Field<DeviceInfo, String?>(
    'deviceModel',
    _$deviceModel,
  );

  static const systemVersion = Field<DeviceInfo, String?>(
    'systemVersion',
    _$systemVersion,
  );

  static const deviceId = Field<DeviceInfo, String?>('deviceId', _$deviceId);

  static const brand = Field<DeviceInfo, String?>('brand', _$brand);

  static const manufacturer = Field<DeviceInfo, String?>(
    'manufacturer',
    _$manufacturer,
  );

  static const isPhysicalDevice = Field<DeviceInfo, bool?>(
    'isPhysicalDevice',
    _$isPhysicalDevice,
  );

  static const additionalProperties = Field<DeviceInfo, Map<String, dynamic>?>(
    'additionalProperties',
    _$additionalProperties,
  );

  static const os = Field<DeviceInfo, OperatingSystem>('os', _$os);

  static String? _$systemName(DeviceInfo e) {
    return e.systemName;
  }

  static String? _$deviceModel(DeviceInfo e) {
    return e.deviceModel;
  }

  static String? _$systemVersion(DeviceInfo e) {
    return e.systemVersion;
  }

  static String? _$deviceId(DeviceInfo e) {
    return e.deviceId;
  }

  static String? _$brand(DeviceInfo e) {
    return e.brand;
  }

  static String? _$manufacturer(DeviceInfo e) {
    return e.manufacturer;
  }

  static bool? _$isPhysicalDevice(DeviceInfo e) {
    return e.isPhysicalDevice;
  }

  static Map<String, dynamic>? _$additionalProperties(DeviceInfo e) {
    return e.additionalProperties;
  }

  static OperatingSystem _$os(DeviceInfo e) {
    return e.os;
  }
}

extension DeviceInfoCompareE on DeviceInfo {
  Map<String, dynamic> compareToDeviceInfo(DeviceInfo other) {
    final Map<String, dynamic> diff = {};

    if (systemName != other.systemName) {
      diff['systemName'] = () => other.systemName;
    }

    if (deviceModel != other.deviceModel) {
      diff['deviceModel'] = () => other.deviceModel;
    }

    if (systemVersion != other.systemVersion) {
      diff['systemVersion'] = () => other.systemVersion;
    }

    if (deviceId != other.deviceId) {
      diff['deviceId'] = () => other.deviceId;
    }

    if (brand != other.brand) {
      diff['brand'] = () => other.brand;
    }

    if (manufacturer != other.manufacturer) {
      diff['manufacturer'] = () => other.manufacturer;
    }

    if (isPhysicalDevice != other.isPhysicalDevice) {
      diff['isPhysicalDevice'] = () => other.isPhysicalDevice;
    }

    if (additionalProperties != other.additionalProperties) {
      diff['additionalProperties'] = () => other.additionalProperties;
    }

    if (os != other.os) {
      diff['os'] = () => other.os;
    }
    return diff;
  }
}
