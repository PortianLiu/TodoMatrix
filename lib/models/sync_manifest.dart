import 'package:json_annotation/json_annotation.dart';

part 'sync_manifest.g.dart';

/// 列表元信息（用于清单文件）
@JsonSerializable()
class ListMeta {
  /// 列表 ID
  final String id;

  /// 列表标题
  final String title;

  /// 排序顺序
  final int sortOrder;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 列表底色
  final String? backgroundColor;

  const ListMeta({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.updatedAt,
    this.backgroundColor,
  });

  factory ListMeta.fromJson(Map<String, dynamic> json) =>
      _$ListMetaFromJson(json);

  Map<String, dynamic> toJson() => _$ListMetaToJson(this);

  ListMeta copyWith({
    String? id,
    String? title,
    int? sortOrder,
    DateTime? updatedAt,
    String? backgroundColor,
    bool clearBackgroundColor = false,
  }) {
    return ListMeta(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      backgroundColor:
          clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListMeta &&
        other.id == id &&
        other.title == title &&
        other.sortOrder == sortOrder &&
        other.updatedAt == updatedAt &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, sortOrder, updatedAt, backgroundColor);
}

/// 已删除项目的墓碑记录
@JsonSerializable()
class DeletedItem {
  /// 被删除项目的 ID
  final String id;

  /// 删除时间
  final DateTime deletedAt;

  /// 类型：list 或 item
  final String type;

  /// 如果是待办项，所属列表 ID
  final String? listId;

  const DeletedItem({
    required this.id,
    required this.deletedAt,
    required this.type,
    this.listId,
  });

  factory DeletedItem.fromJson(Map<String, dynamic> json) =>
      _$DeletedItemFromJson(json);

  Map<String, dynamic> toJson() => _$DeletedItemToJson(this);
}

/// 同步数据清单
/// 管理所有列表的元信息和顺序
@JsonSerializable()
class SyncManifest {
  /// 数据版本号
  final String version;

  /// 列表元信息
  final List<ListMeta> lists;

  /// 列表顺序（ID 列表）
  final List<String> listOrder;

  /// 最后修改时间
  final DateTime lastModified;

  /// 已删除项目的墓碑记录（用于同步删除操作）
  final List<DeletedItem> deletedItems;

  const SyncManifest({
    this.version = '2.0',
    this.lists = const [],
    this.listOrder = const [],
    required this.lastModified,
    this.deletedItems = const [],
  });

  factory SyncManifest.empty() {
    // 使用一个很早的时间，确保同步时优先采用其他设备的数据
    return SyncManifest(lastModified: DateTime(2000, 1, 1));
  }

  factory SyncManifest.fromJson(Map<String, dynamic> json) =>
      _$SyncManifestFromJson(json);

  Map<String, dynamic> toJson() => _$SyncManifestToJson(this);

  SyncManifest copyWith({
    String? version,
    List<ListMeta>? lists,
    List<String>? listOrder,
    DateTime? lastModified,
    List<DeletedItem>? deletedItems,
  }) {
    return SyncManifest(
      version: version ?? this.version,
      lists: lists ?? this.lists,
      listOrder: listOrder ?? this.listOrder,
      lastModified: lastModified ?? this.lastModified,
      deletedItems: deletedItems ?? this.deletedItems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SyncManifest) return false;
    if (other.version != version ||
        other.lastModified != lastModified ||
        other.lists.length != lists.length ||
        other.listOrder.length != listOrder.length) {
      return false;
    }
    for (int i = 0; i < lists.length; i++) {
      if (lists[i] != other.lists[i]) return false;
    }
    for (int i = 0; i < listOrder.length; i++) {
      if (listOrder[i] != other.listOrder[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        version,
        Object.hashAll(lists),
        Object.hashAll(listOrder),
        lastModified,
      );
}
