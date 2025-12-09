import 'package:flutter/material.dart' show ThemeMode;
import 'package:json_annotation/json_annotation.dart';

part 'settings.g.dart';

/// ThemeMode JSON 转换器
class ThemeModeConverter implements JsonConverter<ThemeMode, String> {
  const ThemeModeConverter();

  @override
  ThemeMode fromJson(String json) {
    switch (json) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  String toJson(ThemeMode object) {
    switch (object) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// 布局设置
@JsonSerializable()
class LayoutSettings {
  /// 每行显示的列表数量
  final int columnsPerRow;

  /// 列表 ID 排序
  final List<String> listOrder;

  const LayoutSettings({
    this.columnsPerRow = 3,
    this.listOrder = const [],
  });

  factory LayoutSettings.fromJson(Map<String, dynamic> json) =>
      _$LayoutSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$LayoutSettingsToJson(this);

  LayoutSettings copyWith({
    int? columnsPerRow,
    List<String>? listOrder,
  }) {
    return LayoutSettings(
      columnsPerRow: columnsPerRow ?? this.columnsPerRow,
      listOrder: listOrder ?? this.listOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LayoutSettings) return false;
    if (other.columnsPerRow != columnsPerRow ||
        other.listOrder.length != listOrder.length) {
      return false;
    }
    for (int i = 0; i < listOrder.length; i++) {
      if (listOrder[i] != other.listOrder[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(columnsPerRow, Object.hashAll(listOrder));
}

/// 应用设置
@JsonSerializable()
class AppSettings {
  /// 主题模式
  @ThemeModeConverter()
  final ThemeMode themeMode;

  /// 是否启用同步
  final bool syncEnabled;

  /// 设备名称
  final String deviceName;

  /// 自定义数据路径（低优先级）
  final String? customDataPath;

  /// 最小化到托盘（Windows）
  final bool minimizeToTray;

  /// 钉在桌面（低优先级）
  final bool pinToDesktop;

  /// 贴边隐藏（低优先级）
  final bool edgeHideEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.syncEnabled = false,
    this.deviceName = 'My Device',
    this.customDataPath,
    this.minimizeToTray = true,
    this.pinToDesktop = false,
    this.edgeHideEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? syncEnabled,
    String? deviceName,
    String? customDataPath,
    bool? minimizeToTray,
    bool? pinToDesktop,
    bool? edgeHideEnabled,
    bool clearCustomDataPath = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      deviceName: deviceName ?? this.deviceName,
      customDataPath:
          clearCustomDataPath ? null : (customDataPath ?? this.customDataPath),
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      pinToDesktop: pinToDesktop ?? this.pinToDesktop,
      edgeHideEnabled: edgeHideEnabled ?? this.edgeHideEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.syncEnabled == syncEnabled &&
        other.deviceName == deviceName &&
        other.customDataPath == customDataPath &&
        other.minimizeToTray == minimizeToTray &&
        other.pinToDesktop == pinToDesktop &&
        other.edgeHideEnabled == edgeHideEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      themeMode,
      syncEnabled,
      deviceName,
      customDataPath,
      minimizeToTray,
      pinToDesktop,
      edgeHideEnabled,
    );
  }
}
