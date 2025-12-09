import 'package:json_annotation/json_annotation.dart';
import 'todo_item.dart';

part 'todo_list.g.dart';

/// 待办列表模型
/// 包含多个待办项的容器
@JsonSerializable()
class TodoList {
  /// 唯一标识符
  final String id;

  /// 列表标题
  final String title;

  /// 待办项列表
  final List<TodoItem> items;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 排序顺序
  final int sortOrder;

  const TodoList({
    required this.id,
    required this.title,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  /// 从 JSON 创建 TodoList
  factory TodoList.fromJson(Map<String, dynamic> json) => _$TodoListFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$TodoListToJson(this);

  /// 创建副本并修改指定字段
  TodoList copyWith({
    String? id,
    String? title,
    List<TodoItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return TodoList(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TodoList) return false;
    if (other.id != id ||
        other.title != title ||
        other.createdAt != createdAt ||
        other.updatedAt != updatedAt ||
        other.sortOrder != sortOrder ||
        other.items.length != items.length) {
      return false;
    }
    // 逐项比较
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      Object.hashAll(items),
      createdAt,
      updatedAt,
      sortOrder,
    );
  }

  @override
  String toString() {
    return 'TodoList(id: $id, title: $title, items: ${items.length}, sortOrder: $sortOrder)';
  }
}
