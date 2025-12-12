import 'package:flutter/material.dart' show ThemeMode;
import 'package:json_annotation/json_annotation.dart';

import 'settings.dart';

part 'local_settings.g.dart';

/// 设备本地设置（不参与同步）
@JsonSerializable()
class LocalSettings {
  /// 主题模式
  @ThemeModeConverter()
  final ThemeMode themeMode;

  /// 自定义主题色（十六进制，不含#）
  final String themeColor;

  /// 设备名称
  final String deviceName;

  /// 自定义数据路径
  final String? customDataPath;

  /// 最小化到托盘（Windows）
  final bool minimizeToTray;

  /// 钉在桌面（Windows）
  final bool pinToDesktop;

  /// 贴边隐藏（Windows）
  final bool edgeHideEnabled;

  /// 钉在桌面时的透明度
  final double pinOpacity;

  /// 窗口位置 X（Windows）
  final double? windowX;

  /// 窗口位置 Y（Windows）
  final double? windowY;

  /// 窗口宽度（Windows）
  final double? windowWidth;

  /// 窗口高度（Windows）
  final double? windowHeight;

  /// 每行显示的列表数量
  final int columnsPerRow;

  /// 列表卡片高度
  final double listHeight;

  /// 是否启用同步
  final bool syncEnabled;

  const LocalSettings({
    this.themeMode = ThemeMode.system,
    this.themeColor = '9999ff',
    this.deviceName = 'My Device',
    this.customDataPath,
    this.minimizeToTray = true,
    this.pinToDesktop = false,
    this.edgeHideEnabled = false,
    this.pinOpacity = 0.85,
    this.windowX,
    this.windowY,
    this.windowWidth,
    this.windowHeight,
    this.columnsPerRow = 3,
    this.listHeight = 400,
    this.syncEnabled = false,
  });

  factory LocalSettings.fromJson(Map<String, dynamic> json) =>
      _$LocalSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$LocalSettingsToJson(this);

  LocalSettings copyWith({
    ThemeMode? themeMode,
    String? themeColor,
    String? deviceName,
    String? customDataPath,
    bool? minimizeToTray,
    bool? pinToDesktop,
    bool? edgeHideEnabled,
    double? pinOpacity,
    double? windowX,
    double? windowY,
    double? windowWidth,
    double? windowHeight,
    int? columnsPerRow,
    double? listHeight,
    bool? syncEnabled,
    bool clearCustomDataPath = false,
  }) {
    return LocalSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      deviceName: deviceName ?? this.deviceName,
      customDataPath:
          clearCustomDataPath ? null : (customDataPath ?? this.customDataPath),
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      pinToDesktop: pinToDesktop ?? this.pinToDesktop,
      edgeHideEnabled: edgeHideEnabled ?? this.edgeHideEnabled,
      pinOpacity: pinOpacity ?? this.pinOpacity,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      columnsPerRow: columnsPerRow ?? this.columnsPerRow,
      listHeight: listHeight ?? this.listHeight,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalSettings &&
        other.themeMode == themeMode &&
        other.themeColor == themeColor &&
        other.deviceName == deviceName &&
        other.customDataPath == customDataPath &&
        other.minimizeToTray == minimizeToTray &&
        other.pinToDesktop == pinToDesktop &&
        other.edgeHideEnabled == edgeHideEnabled &&
        other.pinOpacity == pinOpacity &&
        other.windowX == windowX &&
        other.windowY == windowY &&
        other.windowWidth == windowWidth &&
        other.windowHeight == windowHeight &&
        other.columnsPerRow == columnsPerRow &&
        other.listHeight == listHeight &&
        other.syncEnabled == syncEnabled;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        themeColor,
        deviceName,
        customDataPath,
        minimizeToTray,
        pinToDesktop,
        edgeHideEnabled,
        pinOpacity,
        windowX,
        windowY,
        windowWidth,
        windowHeight,
        columnsPerRow,
        listHeight,
        syncEnabled,
      );
}
