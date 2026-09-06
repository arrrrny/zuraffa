// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'error_log.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ErrorLog {
  ErrorLog({
    String? this.id,
    required String this.message,
    required String this.stackTrace,
    required String this.logLevel,
    String? this.loggerName,
    String? this.userId,
    String? this.customerId,
    Map<String, dynamic>? this.deviceInfo,
    String? this.ipAddress,
    String? this.appVersion,
    String? this.platform,
    required DateTime this.timestamp,
    required DateTime this.createdAt,
  });

  factory ErrorLog.fromJson(Map<String, dynamic> json) =>
      _$ErrorLogFromJson(json);

  final String? id;

  final String message;

  final String stackTrace;

  final String logLevel;

  final String? loggerName;

  final String? userId;

  final String? customerId;

  final Map<String, dynamic>? deviceInfo;

  final String? ipAddress;

  final String? appVersion;

  final String? platform;

  final DateTime timestamp;

  final DateTime createdAt;

  ErrorLog copyWith({
    String? id,
    String? message,
    String? stackTrace,
    String? logLevel,
    String? loggerName,
    String? userId,
    String? customerId,
    Map<String, dynamic>? deviceInfo,
    String? ipAddress,
    String? appVersion,
    String? platform,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return ErrorLog(
      id: id ?? this.id,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
      logLevel: logLevel ?? this.logLevel,
      loggerName: loggerName ?? this.loggerName,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      ipAddress: ipAddress ?? this.ipAddress,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ErrorLog copyWithField<T>(Field<ErrorLog, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'message':
        return copyWith(message: value as String);
      case 'stackTrace':
        return copyWith(stackTrace: value as String);
      case 'logLevel':
        return copyWith(logLevel: value as String);
      case 'loggerName':
        return copyWith(loggerName: value as String?);
      case 'userId':
        return copyWith(userId: value as String?);
      case 'customerId':
        return copyWith(customerId: value as String?);
      case 'deviceInfo':
        return copyWith(deviceInfo: value as Map<String, dynamic>?);
      case 'ipAddress':
        return copyWith(ipAddress: value as String?);
      case 'appVersion':
        return copyWith(appVersion: value as String?);
      case 'platform':
        return copyWith(platform: value as String?);
      case 'timestamp':
        return copyWith(timestamp: value as DateTime);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ErrorLog has no settable field with this name',
        );
    }
  }

  ErrorLog copyWithErrorLog({
    String? id,
    String? message,
    String? stackTrace,
    String? logLevel,
    String? loggerName,
    String? userId,
    String? customerId,
    Map<String, dynamic>? deviceInfo,
    String? ipAddress,
    String? appVersion,
    String? platform,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      message: message,
      stackTrace: stackTrace,
      logLevel: logLevel,
      loggerName: loggerName,
      userId: userId,
      customerId: customerId,
      deviceInfo: deviceInfo,
      ipAddress: ipAddress,
      appVersion: appVersion,
      platform: platform,
      timestamp: timestamp,
      createdAt: createdAt,
    );
  }

  ErrorLog patchWithErrorLog([ErrorLogPatch? patchInput]) {
    final _patcher = patchInput ?? ErrorLogPatch();
    final _patchMap = _patcher.patchMap;
    return ErrorLog(
      id: _patchMap.containsKey(ErrorLog$.id)
          ? ((_patchMap[ErrorLog$.id] is Function)
                    ? _patchMap[ErrorLog$.id](this.id)
                    : (_patchMap[ErrorLog$.id] is Patch)
                    ? _patchMap[ErrorLog$.id].applyTo(this.id)
                    : _patchMap[ErrorLog$.id])
                as String?
          : this.id,
      message: _patchMap.containsKey(ErrorLog$.message)
          ? ((_patchMap[ErrorLog$.message] is Function)
                    ? _patchMap[ErrorLog$.message](this.message)
                    : (_patchMap[ErrorLog$.message] is Patch)
                    ? _patchMap[ErrorLog$.message].applyTo(this.message)
                    : _patchMap[ErrorLog$.message])
                as String
          : this.message,
      stackTrace: _patchMap.containsKey(ErrorLog$.stackTrace)
          ? ((_patchMap[ErrorLog$.stackTrace] is Function)
                    ? _patchMap[ErrorLog$.stackTrace](this.stackTrace)
                    : (_patchMap[ErrorLog$.stackTrace] is Patch)
                    ? _patchMap[ErrorLog$.stackTrace].applyTo(this.stackTrace)
                    : _patchMap[ErrorLog$.stackTrace])
                as String
          : this.stackTrace,
      logLevel: _patchMap.containsKey(ErrorLog$.logLevel)
          ? ((_patchMap[ErrorLog$.logLevel] is Function)
                    ? _patchMap[ErrorLog$.logLevel](this.logLevel)
                    : (_patchMap[ErrorLog$.logLevel] is Patch)
                    ? _patchMap[ErrorLog$.logLevel].applyTo(this.logLevel)
                    : _patchMap[ErrorLog$.logLevel])
                as String
          : this.logLevel,
      loggerName: _patchMap.containsKey(ErrorLog$.loggerName)
          ? ((_patchMap[ErrorLog$.loggerName] is Function)
                    ? _patchMap[ErrorLog$.loggerName](this.loggerName)
                    : (_patchMap[ErrorLog$.loggerName] is Patch)
                    ? _patchMap[ErrorLog$.loggerName].applyTo(this.loggerName)
                    : _patchMap[ErrorLog$.loggerName])
                as String?
          : this.loggerName,
      userId: _patchMap.containsKey(ErrorLog$.userId)
          ? ((_patchMap[ErrorLog$.userId] is Function)
                    ? _patchMap[ErrorLog$.userId](this.userId)
                    : (_patchMap[ErrorLog$.userId] is Patch)
                    ? _patchMap[ErrorLog$.userId].applyTo(this.userId)
                    : _patchMap[ErrorLog$.userId])
                as String?
          : this.userId,
      customerId: _patchMap.containsKey(ErrorLog$.customerId)
          ? ((_patchMap[ErrorLog$.customerId] is Function)
                    ? _patchMap[ErrorLog$.customerId](this.customerId)
                    : (_patchMap[ErrorLog$.customerId] is Patch)
                    ? _patchMap[ErrorLog$.customerId].applyTo(this.customerId)
                    : _patchMap[ErrorLog$.customerId])
                as String?
          : this.customerId,
      deviceInfo: _patchMap.containsKey(ErrorLog$.deviceInfo)
          ? ((_patchMap[ErrorLog$.deviceInfo] is Function)
                    ? _patchMap[ErrorLog$.deviceInfo](this.deviceInfo)
                    : (_patchMap[ErrorLog$.deviceInfo] is Patch)
                    ? _patchMap[ErrorLog$.deviceInfo].applyTo(this.deviceInfo)
                    : _patchMap[ErrorLog$.deviceInfo])
                as Map<String, dynamic>?
          : this.deviceInfo,
      ipAddress: _patchMap.containsKey(ErrorLog$.ipAddress)
          ? ((_patchMap[ErrorLog$.ipAddress] is Function)
                    ? _patchMap[ErrorLog$.ipAddress](this.ipAddress)
                    : (_patchMap[ErrorLog$.ipAddress] is Patch)
                    ? _patchMap[ErrorLog$.ipAddress].applyTo(this.ipAddress)
                    : _patchMap[ErrorLog$.ipAddress])
                as String?
          : this.ipAddress,
      appVersion: _patchMap.containsKey(ErrorLog$.appVersion)
          ? ((_patchMap[ErrorLog$.appVersion] is Function)
                    ? _patchMap[ErrorLog$.appVersion](this.appVersion)
                    : (_patchMap[ErrorLog$.appVersion] is Patch)
                    ? _patchMap[ErrorLog$.appVersion].applyTo(this.appVersion)
                    : _patchMap[ErrorLog$.appVersion])
                as String?
          : this.appVersion,
      platform: _patchMap.containsKey(ErrorLog$.platform)
          ? ((_patchMap[ErrorLog$.platform] is Function)
                    ? _patchMap[ErrorLog$.platform](this.platform)
                    : (_patchMap[ErrorLog$.platform] is Patch)
                    ? _patchMap[ErrorLog$.platform].applyTo(this.platform)
                    : _patchMap[ErrorLog$.platform])
                as String?
          : this.platform,
      timestamp: _patchMap.containsKey(ErrorLog$.timestamp)
          ? ((_patchMap[ErrorLog$.timestamp] is Function)
                    ? _patchMap[ErrorLog$.timestamp](this.timestamp)
                    : (_patchMap[ErrorLog$.timestamp] is Patch)
                    ? _patchMap[ErrorLog$.timestamp].applyTo(this.timestamp)
                    : _patchMap[ErrorLog$.timestamp])
                as DateTime
          : this.timestamp,
      createdAt: _patchMap.containsKey(ErrorLog$.createdAt)
          ? ((_patchMap[ErrorLog$.createdAt] is Function)
                    ? _patchMap[ErrorLog$.createdAt](this.createdAt)
                    : (_patchMap[ErrorLog$.createdAt] is Patch)
                    ? _patchMap[ErrorLog$.createdAt].applyTo(this.createdAt)
                    : _patchMap[ErrorLog$.createdAt])
                as DateTime
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorLog &&
        id == other.id &&
        message == other.message &&
        stackTrace == other.stackTrace &&
        logLevel == other.logLevel &&
        loggerName == other.loggerName &&
        userId == other.userId &&
        customerId == other.customerId &&
        deviceInfo == other.deviceInfo &&
        ipAddress == other.ipAddress &&
        appVersion == other.appVersion &&
        platform == other.platform &&
        timestamp == other.timestamp &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.message,
      this.stackTrace,
      this.logLevel,
      this.loggerName,
      this.userId,
      this.customerId,
      this.deviceInfo,
      this.ipAddress,
      this.appVersion,
      this.platform,
      this.timestamp,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ErrorLog(' +
        'id: ${id}' +
        ', ' +
        'message: ${message}' +
        ', ' +
        'stackTrace: ${stackTrace}' +
        ', ' +
        'logLevel: ${logLevel}' +
        ', ' +
        'loggerName: ${loggerName}' +
        ', ' +
        'userId: ${userId}' +
        ', ' +
        'customerId: ${customerId}' +
        ', ' +
        'deviceInfo: ${deviceInfo}' +
        ', ' +
        'ipAddress: ${ipAddress}' +
        ', ' +
        'appVersion: ${appVersion}' +
        ', ' +
        'platform: ${platform}' +
        ', ' +
        'timestamp: ${timestamp}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ErrorLogToJson(this);
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

extension ErrorLogPropertyHelpers on ErrorLog {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasMessage {
    return this.message.isNotEmpty;
  }

  bool get noMessage {
    return this.message.isEmpty;
  }

  bool get hasStackTrace {
    return this.stackTrace.isNotEmpty;
  }

  bool get noStackTrace {
    return this.stackTrace.isEmpty;
  }

  bool get hasLogLevel {
    return this.logLevel.isNotEmpty;
  }

  bool get noLogLevel {
    return this.logLevel.isEmpty;
  }

  bool get hasLoggerName {
    return this.loggerName?.isNotEmpty == true;
  }

  bool get noLoggerName {
    return this.loggerName?.isEmpty ?? true;
  }

  String get loggerNameRequired {
    return this.loggerName ??
        (throw StateError('loggerName is required but was null'));
  }

  bool get hasUserId {
    return this.userId?.isNotEmpty == true;
  }

  bool get noUserId {
    return this.userId?.isEmpty ?? true;
  }

  String get userIdRequired {
    return this.userId ?? (throw StateError('userId is required but was null'));
  }

  bool get hasCustomerId {
    return this.customerId?.isNotEmpty == true;
  }

  bool get noCustomerId {
    return this.customerId?.isEmpty ?? true;
  }

  String get customerIdRequired {
    return this.customerId ??
        (throw StateError('customerId is required but was null'));
  }

  Map<String, dynamic> get deviceInfoRequired {
    return this.deviceInfo ??
        (throw StateError('deviceInfo is required but was null'));
  }

  bool get hasDeviceInfo {
    return this.deviceInfo?.isNotEmpty ?? false;
  }

  bool get noDeviceInfo {
    return this.deviceInfo?.isEmpty ?? true;
  }

  bool get hasIpAddress {
    return this.ipAddress?.isNotEmpty == true;
  }

  bool get noIpAddress {
    return this.ipAddress?.isEmpty ?? true;
  }

  String get ipAddressRequired {
    return this.ipAddress ??
        (throw StateError('ipAddress is required but was null'));
  }

  bool get hasAppVersion {
    return this.appVersion?.isNotEmpty == true;
  }

  bool get noAppVersion {
    return this.appVersion?.isEmpty ?? true;
  }

  String get appVersionRequired {
    return this.appVersion ??
        (throw StateError('appVersion is required but was null'));
  }

  bool get hasPlatform {
    return this.platform?.isNotEmpty == true;
  }

  bool get noPlatform {
    return this.platform?.isEmpty ?? true;
  }

  String get platformRequired {
    return this.platform ??
        (throw StateError('platform is required but was null'));
  }
}

extension ErrorLogSerialization on ErrorLog {
  Map<String, dynamic> toJson() {
    return _$ErrorLogToJson(this);
  }
}

enum ErrorLog$ {
  id,
  message,
  stackTrace,
  logLevel,
  loggerName,
  userId,
  customerId,
  deviceInfo,
  ipAddress,
  appVersion,
  platform,
  timestamp,
  createdAt,
}

class ErrorLogPatch extends PatchBase<ErrorLog, ErrorLog$> {
  ErrorLog applyTo(ErrorLog entity) {
    return entity.patchWithErrorLog(this);
  }

  ErrorLogPatch withId(String? value) {
    patchMap[ErrorLog$.id] = value;
    return this;
  }

  ErrorLogPatch withMessage(String? value) {
    patchMap[ErrorLog$.message] = value;
    return this;
  }

  ErrorLogPatch withStackTrace(String? value) {
    patchMap[ErrorLog$.stackTrace] = value;
    return this;
  }

  ErrorLogPatch withLogLevel(String? value) {
    patchMap[ErrorLog$.logLevel] = value;
    return this;
  }

  ErrorLogPatch withLoggerName(String? value) {
    patchMap[ErrorLog$.loggerName] = value;
    return this;
  }

  ErrorLogPatch withUserId(String? value) {
    patchMap[ErrorLog$.userId] = value;
    return this;
  }

  ErrorLogPatch withCustomerId(String? value) {
    patchMap[ErrorLog$.customerId] = value;
    return this;
  }

  ErrorLogPatch withDeviceInfo(Map<String, dynamic>? value) {
    patchMap[ErrorLog$.deviceInfo] = value;
    return this;
  }

  ErrorLogPatch withIpAddress(String? value) {
    patchMap[ErrorLog$.ipAddress] = value;
    return this;
  }

  ErrorLogPatch withAppVersion(String? value) {
    patchMap[ErrorLog$.appVersion] = value;
    return this;
  }

  ErrorLogPatch withPlatform(String? value) {
    patchMap[ErrorLog$.platform] = value;
    return this;
  }

  ErrorLogPatch withTimestamp(DateTime? value) {
    patchMap[ErrorLog$.timestamp] = value;
    return this;
  }

  ErrorLogPatch withCreatedAt(DateTime? value) {
    patchMap[ErrorLog$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [ErrorLog] query construction
abstract final class ErrorLogFields {
  static const id = Field<ErrorLog, String?>('id', _$id);

  static const message = Field<ErrorLog, String>('message', _$message);

  static const stackTrace = Field<ErrorLog, String>('stackTrace', _$stackTrace);

  static const logLevel = Field<ErrorLog, String>('logLevel', _$logLevel);

  static const loggerName = Field<ErrorLog, String?>(
    'loggerName',
    _$loggerName,
  );

  static const userId = Field<ErrorLog, String?>('userId', _$userId);

  static const customerId = Field<ErrorLog, String?>(
    'customerId',
    _$customerId,
  );

  static const deviceInfo = Field<ErrorLog, Map<String, dynamic>?>(
    'deviceInfo',
    _$deviceInfo,
  );

  static const ipAddress = Field<ErrorLog, String?>('ipAddress', _$ipAddress);

  static const appVersion = Field<ErrorLog, String?>(
    'appVersion',
    _$appVersion,
  );

  static const platform = Field<ErrorLog, String?>('platform', _$platform);

  static const timestamp = Field<ErrorLog, DateTime>('timestamp', _$timestamp);

  static const createdAt = Field<ErrorLog, DateTime>('createdAt', _$createdAt);

  static String? _$id(ErrorLog e) {
    return e.id;
  }

  static String _$message(ErrorLog e) {
    return e.message;
  }

  static String _$stackTrace(ErrorLog e) {
    return e.stackTrace;
  }

  static String _$logLevel(ErrorLog e) {
    return e.logLevel;
  }

  static String? _$loggerName(ErrorLog e) {
    return e.loggerName;
  }

  static String? _$userId(ErrorLog e) {
    return e.userId;
  }

  static String? _$customerId(ErrorLog e) {
    return e.customerId;
  }

  static Map<String, dynamic>? _$deviceInfo(ErrorLog e) {
    return e.deviceInfo;
  }

  static String? _$ipAddress(ErrorLog e) {
    return e.ipAddress;
  }

  static String? _$appVersion(ErrorLog e) {
    return e.appVersion;
  }

  static String? _$platform(ErrorLog e) {
    return e.platform;
  }

  static DateTime _$timestamp(ErrorLog e) {
    return e.timestamp;
  }

  static DateTime _$createdAt(ErrorLog e) {
    return e.createdAt;
  }
}

extension ErrorLogCompareE on ErrorLog {
  Map<String, dynamic> compareToErrorLog(ErrorLog other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (message != other.message) {
      diff['message'] = () => other.message;
    }

    if (stackTrace != other.stackTrace) {
      diff['stackTrace'] = () => other.stackTrace;
    }

    if (logLevel != other.logLevel) {
      diff['logLevel'] = () => other.logLevel;
    }

    if (loggerName != other.loggerName) {
      diff['loggerName'] = () => other.loggerName;
    }

    if (userId != other.userId) {
      diff['userId'] = () => other.userId;
    }

    if (customerId != other.customerId) {
      diff['customerId'] = () => other.customerId;
    }

    if (deviceInfo != other.deviceInfo) {
      diff['deviceInfo'] = () => other.deviceInfo;
    }

    if (ipAddress != other.ipAddress) {
      diff['ipAddress'] = () => other.ipAddress;
    }

    if (appVersion != other.appVersion) {
      diff['appVersion'] = () => other.appVersion;
    }

    if (platform != other.platform) {
      diff['platform'] = () => other.platform;
    }

    if (timestamp != other.timestamp) {
      diff['timestamp'] = () => other.timestamp;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
