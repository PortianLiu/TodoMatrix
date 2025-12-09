// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppData _$AppDataFromJson(Map<String, dynamic> json) => AppData(
      version: json['version'] as String? ?? '1.0',
      lists: (json['lists'] as List<dynamic>?)
              ?.map((e) => TodoList.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      layout: json['layout'] == null
          ? const LayoutSettings()
          : LayoutSettings.fromJson(json['layout'] as Map<String, dynamic>),
      settings: json['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );

Map<String, dynamic> _$AppDataToJson(AppData instance) => <String, dynamic>{
      'version': instance.version,
      'lists': instance.lists,
      'layout': instance.layout,
      'settings': instance.settings,
      'lastModified': instance.lastModified.toIso8601String(),
    };
