// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodoList _$TodoListFromJson(Map<String, dynamic> json) => TodoList(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: (json['sortOrder'] as num).toInt(),
      backgroundColor: json['backgroundColor'] as String?,
    );

Map<String, dynamic> _$TodoListToJson(TodoList instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'items': instance.items,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'sortOrder': instance.sortOrder,
      'backgroundColor': instance.backgroundColor,
    };
