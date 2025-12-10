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
      listHeight: (json['listHeight'] as num?)?.toDouble() ?? 400,
    );

Map<String, dynamic> _$LayoutSettingsToJson(LayoutSettings instance) =>
    <String, dynamic>{
      'columnsPerRow': instance.columnsPerRow,
      'listOrder': instance.listOrder,
      'listHeight': instance.listHeight,
    };

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      themeMode: json['themeMode'] == null
          ? ThemeMode.system
          : const ThemeModeConverter().fromJson(json['themeMode'] as String),
      themeColor: json['themeColor'] as String? ?? '9999ff',
      syncEnabled: json['syncEnabled'] as bool? ?? false,
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
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'themeMode': const ThemeModeConverter().toJson(instance.themeMode),
      'themeColor': instance.themeColor,
      'syncEnabled': instance.syncEnabled,
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
    };
