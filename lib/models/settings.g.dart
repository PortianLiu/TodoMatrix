// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LayoutSettings _$LayoutSettingsFromJson(Map<String, dynamic> json) =>
    LayoutSettings(
      columnsPerRow: (json['columnsPerRow'] as num?)?.toInt() ?? 3,
      listOrder: (json['listOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LayoutSettingsToJson(LayoutSettings instance) =>
    <String, dynamic>{
      'columnsPerRow': instance.columnsPerRow,
      'listOrder': instance.listOrder,
    };

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      themeMode: json['themeMode'] == null
          ? ThemeMode.system
          : const ThemeModeConverter().fromJson(json['themeMode'] as String),
      syncEnabled: json['syncEnabled'] as bool? ?? false,
      deviceName: json['deviceName'] as String? ?? 'My Device',
      customDataPath: json['customDataPath'] as String?,
      minimizeToTray: json['minimizeToTray'] as bool? ?? true,
      pinToDesktop: json['pinToDesktop'] as bool? ?? false,
      edgeHideEnabled: json['edgeHideEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'themeMode': const ThemeModeConverter().toJson(instance.themeMode),
      'syncEnabled': instance.syncEnabled,
      'deviceName': instance.deviceName,
      'customDataPath': instance.customDataPath,
      'minimizeToTray': instance.minimizeToTray,
      'pinToDesktop': instance.pinToDesktop,
      'edgeHideEnabled': instance.edgeHideEnabled,
    };
