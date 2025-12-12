// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalSettings _$LocalSettingsFromJson(Map<String, dynamic> json) =>
    LocalSettings(
      themeMode: json['themeMode'] == null
          ? ThemeMode.system
          : const ThemeModeConverter().fromJson(json['themeMode'] as String),
      themeColor: json['themeColor'] as String? ?? '9999ff',
      deviceName: json['deviceName'] as String? ?? 'My Device',
      customDataPath: json['customDataPath'] as String?,
      minimizeToTray: json['minimizeToTray'] as bool? ?? true,
      pinToDesktop: json['pinToDesktop'] as bool? ?? false,
      edgeHideEnabled: json['edgeHideEnabled'] as bool? ?? false,
      pinOpacity: (json['pinOpacity'] as num?)?.toDouble() ?? 0.85,
      windowX: (json['windowX'] as num?)?.toDouble(),
      windowY: (json['windowY'] as num?)?.toDouble(),
      windowWidth: (json['windowWidth'] as num?)?.toDouble(),
      windowHeight: (json['windowHeight'] as num?)?.toDouble(),
      columnsPerRow: (json['columnsPerRow'] as num?)?.toInt() ?? 3,
      listHeight: (json['listHeight'] as num?)?.toDouble() ?? 400,
      syncEnabled: json['syncEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$LocalSettingsToJson(LocalSettings instance) =>
    <String, dynamic>{
      'themeMode': const ThemeModeConverter().toJson(instance.themeMode),
      'themeColor': instance.themeColor,
      'deviceName': instance.deviceName,
      'customDataPath': instance.customDataPath,
      'minimizeToTray': instance.minimizeToTray,
      'pinToDesktop': instance.pinToDesktop,
      'edgeHideEnabled': instance.edgeHideEnabled,
      'pinOpacity': instance.pinOpacity,
      'windowX': instance.windowX,
      'windowY': instance.windowY,
      'windowWidth': instance.windowWidth,
      'windowHeight': instance.windowHeight,
      'columnsPerRow': instance.columnsPerRow,
      'listHeight': instance.listHeight,
      'syncEnabled': instance.syncEnabled,
    };
