import 'package:json_annotation/json_annotation.dart';
import 'todo_list.dart';
import 'settings.dart';

part 'app_data.g.dart';

/// 应用数据（顶层容器）
/// 包含所有待办列表、布局设置和应用设置
@JsonSerializable()
class AppData {
  /// 数据版本号
  final String version;

  /// 所有待办列表
  final List<TodoList> lists;

  /// 布局设置
  final LayoutSettings layout;

  /// 应用设置
  final AppSettings settings;

  /// 最后修改时间
  final DateTime lastModified;

  const AppData({
    this.version = '1.0',
    this.lists = const [],
    this.layout = const LayoutSettings(),
    this.settings = const AppSettings(),
    required this.lastModified,
  });

  /// 创建空的应用数据
  factory AppData.empty() {
    return AppData(
      lastModified: DateTime.now(),
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) => _$AppDataFromJson(json);

  Map<String, dynamic> toJson() => _$AppDataToJson(this);

  AppData copyWith({
    String? version,
    List<TodoList>? lists,
    LayoutSettings? layout,
    AppSettings? settings,
    DateTime? lastModified,
  }) {
    return AppData(
      version: version ?? this.version,
      lists: lists ?? this.lists,
      layout: layout ?? this.layout,
      settings: settings ?? this.settings,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppData) return false;
    if (other.version != version ||
        other.lastModified != lastModified ||
        other.layout != layout ||
        other.settings != settings ||
        other.lists.length != lists.length) {
      return false;
    }
    for (int i = 0; i < lists.length; i++) {
      if (lists[i] != other.lists[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      Object.hashAll(lists),
      layout,
      settings,
      lastModified,
    );
  }

  @override
  String toString() {
    return 'AppData(version: $version, lists: ${lists.length}, lastModified: $lastModified)';
  }
}
