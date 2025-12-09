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

/// 预设主题色
class ThemeColors {
  static const String defaultColor = '9999ff';
  
  static const List<String> presetColors = [
    '9999ff', // 淡紫色（默认）
    'ff6b6b', // 珊瑚红
    '4ecdc4', // 青绿色
    'ffe66d', // 明黄色
    '95e1d3', // 薄荷绿
    'dda0dd', // 梅红色
    '87ceeb', // 天蓝色
    'f0e68c', // 卡其色
    'ffa07a', // 浅鲑鱼色
    'b0c4de', // 浅钢蓝
  ];
}

/// 预设列表底色
class ListColors {
  static const List<String> presetColors = [
    'ffffff', // 白色（默认）
    'fff3e0', // 浅橙
    'e3f2fd', // 浅蓝
    'f3e5f5', // 浅紫
    'e8f5e9', // 浅绿
    'fff8e1', // 浅黄
    'fce4ec', // 浅粉
    'e0f7fa', // 浅青
    'f5f5f5', // 浅灰
    'ede7f6', // 淡紫
  ];
}

/// 应用设置
@JsonSerializable()
class AppSettings {
  /// 主题模式
  @ThemeModeConverter()
  final ThemeMode themeMode;

  /// 自定义主题色（十六进制，不含#）
  final String themeColor;

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
    this.themeColor = '9999ff',
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
    String? themeColor,
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
      themeColor: themeColor ?? this.themeColor,
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
        other.themeColor == themeColor &&
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
      themeColor,
      syncEnabled,
      deviceName,
      customDataPath,
      minimizeToTray,
      pinToDesktop,
      edgeHideEnabled,
    );
  }
}
