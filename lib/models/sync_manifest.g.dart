// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListMeta _$ListMetaFromJson(Map<String, dynamic> json) => ListMeta(
      id: json['id'] as String,
      title: json['title'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      backgroundColor: json['backgroundColor'] as String?,
    );

Map<String, dynamic> _$ListMetaToJson(ListMeta instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'sortOrder': instance.sortOrder,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'backgroundColor': instance.backgroundColor,
    };

DeletedItem _$DeletedItemFromJson(Map<String, dynamic> json) => DeletedItem(
      id: json['id'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
      type: json['type'] as String,
      listId: json['listId'] as String?,
    );

Map<String, dynamic> _$DeletedItemToJson(DeletedItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deletedAt': instance.deletedAt.toIso8601String(),
      'type': instance.type,
      'listId': instance.listId,
    };

SyncManifest _$SyncManifestFromJson(Map<String, dynamic> json) => SyncManifest(
      version: json['version'] as String? ?? '2.0',
      lists: (json['lists'] as List<dynamic>?)
              ?.map((e) => ListMeta.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      listOrder: (json['listOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastModified: DateTime.parse(json['lastModified'] as String),
      deletedItems: (json['deletedItems'] as List<dynamic>?)
              ?.map((e) => DeletedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SyncManifestToJson(SyncManifest instance) =>
    <String, dynamic>{
      'version': instance.version,
      'lists': instance.lists,
      'listOrder': instance.listOrder,
      'lastModified': instance.lastModified.toIso8601String(),
      'deletedItems': instance.deletedItems,
    };
