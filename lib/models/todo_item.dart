import 'package:json_annotation/json_annotation.dart';

part 'todo_item.g.dart';

/// 优先级枚举
enum Priority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
}

/// 待办项模型
/// 包含单个待办事项的所有属性
@JsonSerializable()
class TodoItem {
  /// 唯一标识符
  final String id;

  /// 待办项描述
  final String description;

  /// 是否已完成
  final bool isCompleted;

  /// 优先级
  final Priority priority;

  /// 截止日期（可选）
  final DateTime? dueDate;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 排序顺序
  final int sortOrder;

  const TodoItem({
    required this.id,
    required this.description,
    this.isCompleted = false,
    this.priority = Priority.medium,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  /// 从 JSON 创建 TodoItem
  factory TodoItem.fromJson(Map<String, dynamic> json) => _$TodoItemFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$TodoItemToJson(this);

  /// 创建副本并修改指定字段
  TodoItem copyWith({
    String? id,
    String? description,
    bool? isCompleted,
    Priority? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool clearDueDate = false,
  }) {
    return TodoItem(
      id: id ?? this.id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoItem &&
        other.id == id &&
        other.description == description &&
        other.isCompleted == isCompleted &&
        other.priority == priority &&
        other.dueDate == dueDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      description,
      isCompleted,
      priority,
      dueDate,
      createdAt,
      updatedAt,
      sortOrder,
    );
  }

  @override
  String toString() {
    return 'TodoItem(id: $id, description: $description, isCompleted: $isCompleted, '
        'priority: $priority, dueDate: $dueDate, sortOrder: $sortOrder)';
  }
}
