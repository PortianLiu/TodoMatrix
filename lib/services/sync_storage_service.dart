import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sync_manifest.dart';
import '../models/local_settings.dart';
import '../models/todo_list.dart';

/// 同步存储服务
/// 管理分离的数据存储：
/// - sync_data/manifest.json - 列表清单
/// - sync_data/list_xxx.json - 各列表数据
/// - local_settings.json - 设备本地设置
class SyncStorageService {
  static const String _syncDataDir = 'sync_data';
  static const String _manifestFileName = 'manifest.json';
  static const String _localSettingsFileName = 'local_settings.json';

  /// 自动保存防抖时间（毫秒）
  static const int _autoSaveDebounceMs = 1500;

  /// 自定义数据路径
  String? customDataPath;

  /// 防抖定时器
  Timer? _manifestSaveTimer;
  Timer? _settingsSaveTimer;
  final Map<String, Timer> _listSaveTimers = {};

  /// 待保存的数据
  SyncManifest? _pendingManifest;
  LocalSettings? _pendingSettings;
  final Map<String, TodoList> _pendingLists = {};

  /// 保存回调
  final void Function(String message)? onSaveError;
  final void Function()? onSaveSuccess;

  SyncStorageService({
    this.customDataPath,
    this.onSaveError,
    this.onSaveSuccess,
  });

  /// 获取数据根目录
  Future<Directory> _getDataDirectory() async {
    try {
      if (customDataPath != null && customDataPath!.isNotEmpty) {
        final dir = Directory(customDataPath!);
        if (await dir.exists()) {
          return dir;
        }
      }

      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final dir = Directory('$appData/TodoMatrix');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      }

      // Android/iOS/其他平台
      final docDir = await getApplicationDocumentsDirectory();
      debugPrint('[SyncStorage] 文档目录: ${docDir.path}');
      final dir = Directory('${docDir.path}/TodoMatrix');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint('[SyncStorage] 创建数据目录: ${dir.path}');
      }
      return dir;
    } catch (e) {
      debugPrint('[SyncStorage] 获取数据目录失败: $e');
      rethrow;
    }
  }

  /// 获取同步数据目录
  Future<Directory> _getSyncDataDirectory() async {
    final root = await _getDataDirectory();
    final syncDir = Directory('${root.path}/$_syncDataDir');
    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }
    return syncDir;
  }

  // ==================== 清单操作 ====================

  /// 加载清单
  Future<SyncManifest> loadManifest() async {
    final syncDir = await _getSyncDataDirectory();
    final file = File('${syncDir.path}/$_manifestFileName');

    if (!await file.exists()) {
      debugPrint('[SyncStorage] 清单文件不存在，返回空清单');
      return SyncManifest.empty();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      debugPrint('[SyncStorage] 加载清单成功，包含 ${(json['lists'] as List?)?.length ?? 0} 个列表');
      return SyncManifest.fromJson(json);
    } catch (e) {
      debugPrint('[SyncStorage] 加载清单失败: $e');
      return SyncManifest.empty();
    }
  }

  /// 保存清单
  Future<void> saveManifest(SyncManifest manifest) async {
    final syncDir = await _getSyncDataDirectory();
    final file = File('${syncDir.path}/$_manifestFileName');

    try {
      final content = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
      await file.writeAsString(content);
      debugPrint('[SyncStorage] 保存清单成功');
      onSaveSuccess?.call();
    } catch (e) {
      debugPrint('[SyncStorage] 保存清单失败: $e');
      onSaveError?.call('保存清单失败: $e');
    }
  }

  /// 触发清单自动保存（带防抖）
  void triggerManifestSave(SyncManifest manifest) {
    _pendingManifest = manifest;
    _manifestSaveTimer?.cancel();
    _manifestSaveTimer = Timer(
      const Duration(milliseconds: _autoSaveDebounceMs),
      () async {
        if (_pendingManifest != null) {
          await saveManifest(_pendingManifest!);
          _pendingManifest = null;
        }
      },
    );
  }

  // ==================== 列表操作 ====================

  /// 加载单个列表
  Future<TodoList?> loadList(String listId) async {
    final syncDir = await _getSyncDataDirectory();
    final file = File('${syncDir.path}/list_$listId.json');

    if (!await file.exists()) {
      debugPrint('[SyncStorage] 列表文件不存在: $listId');
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      debugPrint('[SyncStorage] 加载列表成功: $listId');
      return TodoList.fromJson(json);
    } catch (e) {
      debugPrint('[SyncStorage] 加载列表失败 ($listId): $e');
      return null;
    }
  }

  /// 加载所有列表
  Future<List<TodoList>> loadAllLists(SyncManifest manifest) async {
    final lists = <TodoList>[];
    for (final meta in manifest.lists) {
      final list = await loadList(meta.id);
      if (list != null) {
        lists.add(list);
      }
    }
    debugPrint('[SyncStorage] 加载所有列表完成，共 ${lists.length} 个');
    return lists;
  }

  /// 保存单个列表
  Future<void> saveList(TodoList list) async {
    final syncDir = await _getSyncDataDirectory();
    final file = File('${syncDir.path}/list_${list.id}.json');

    try {
      final content = const JsonEncoder.withIndent('  ').convert(list.toJson());
      await file.writeAsString(content);
      debugPrint('[SyncStorage] 保存列表成功: ${list.id}');
    } catch (e) {
      debugPrint('[SyncStorage] 保存列表失败 (${list.id}): $e');
      onSaveError?.call('保存列表失败: $e');
    }
  }

  /// 触发列表自动保存（带防抖）
  void triggerListSave(TodoList list) {
    _pendingLists[list.id] = list;
    _listSaveTimers[list.id]?.cancel();
    _listSaveTimers[list.id] = Timer(
      const Duration(milliseconds: _autoSaveDebounceMs),
      () async {
        final pending = _pendingLists.remove(list.id);
        if (pending != null) {
          await saveList(pending);
        }
        _listSaveTimers.remove(list.id);
      },
    );
  }

  /// 删除列表文件
  Future<void> deleteList(String listId) async {
    final syncDir = await _getSyncDataDirectory();
    final file = File('${syncDir.path}/list_$listId.json');

    if (await file.exists()) {
      try {
        await file.delete();
        debugPrint('[SyncStorage] 删除列表文件成功: $listId');
      } catch (e) {
        debugPrint('[SyncStorage] 删除列表文件失败 ($listId): $e');
      }
    }

    // 取消待保存
    _listSaveTimers[listId]?.cancel();
    _listSaveTimers.remove(listId);
    _pendingLists.remove(listId);
  }

  // ==================== 本地设置操作 ====================

  /// 加载本地设置
  Future<LocalSettings> loadLocalSettings() async {
    final root = await _getDataDirectory();
    final file = File('${root.path}/$_localSettingsFileName');

    if (!await file.exists()) {
      debugPrint('[SyncStorage] 本地设置文件不存在，返回默认设置');
      return const LocalSettings();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      debugPrint('[SyncStorage] 加载本地设置成功');
      return LocalSettings.fromJson(json);
    } catch (e) {
      debugPrint('[SyncStorage] 加载本地设置失败: $e');
      return const LocalSettings();
    }
  }

  /// 保存本地设置
  Future<void> saveLocalSettings(LocalSettings settings) async {
    final root = await _getDataDirectory();
    final file = File('${root.path}/$_localSettingsFileName');

    try {
      final content = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await file.writeAsString(content);
      debugPrint('[SyncStorage] 保存本地设置成功');
    } catch (e) {
      debugPrint('[SyncStorage] 保存本地设置失败: $e');
      onSaveError?.call('保存设置失败: $e');
    }
  }

  /// 触发本地设置自动保存（带防抖）
  void triggerSettingsSave(LocalSettings settings) {
    _pendingSettings = settings;
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = Timer(
      const Duration(milliseconds: _autoSaveDebounceMs),
      () async {
        if (_pendingSettings != null) {
          await saveLocalSettings(_pendingSettings!);
          _pendingSettings = null;
        }
      },
    );
  }

  // ==================== 数据迁移 ====================

  /// 从旧版 data.json 迁移数据
  Future<bool> migrateFromLegacy() async {
    final root = await _getDataDirectory();
    final legacyFile = File('${root.path}/data.json');

    if (!await legacyFile.exists()) {
      debugPrint('[SyncStorage] 无旧版数据需要迁移');
      return false;
    }

    try {
      debugPrint('[SyncStorage] 开始迁移旧版数据...');
      final content = await legacyFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 提取列表数据
      final listsJson = json['lists'] as List<dynamic>? ?? [];
      final lists = listsJson
          .map((e) => TodoList.fromJson(e as Map<String, dynamic>))
          .toList();

      // 提取布局设置
      final layoutJson = json['layout'] as Map<String, dynamic>?;
      final listOrder = (layoutJson?['listOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      final columnsPerRow = layoutJson?['columnsPerRow'] as int? ?? 3;
      final listHeight = (layoutJson?['listHeight'] as num?)?.toDouble() ?? 400;

      // 提取应用设置
      final settingsJson = json['settings'] as Map<String, dynamic>?;

      // 创建清单
      final manifest = SyncManifest(
        lists: lists
            .map((l) => ListMeta(
                  id: l.id,
                  title: l.title,
                  sortOrder: l.sortOrder,
                  updatedAt: l.updatedAt,
                  backgroundColor: l.backgroundColor,
                ))
            .toList(),
        listOrder: listOrder,
        lastModified: DateTime.now(),
      );

      // 创建本地设置
      final localSettings = LocalSettings(
        themeColor: settingsJson?['themeColor'] as String? ?? '9999ff',
        deviceName: settingsJson?['deviceName'] as String? ?? 'My Device',
        minimizeToTray: settingsJson?['minimizeToTray'] as bool? ?? true,
        pinToDesktop: settingsJson?['pinToDesktop'] as bool? ?? false,
        edgeHideEnabled: settingsJson?['edgeHideEnabled'] as bool? ?? false,
        pinOpacity: (settingsJson?['pinOpacity'] as num?)?.toDouble() ?? 0.85,
        windowX: (settingsJson?['windowX'] as num?)?.toDouble(),
        windowY: (settingsJson?['windowY'] as num?)?.toDouble(),
        windowWidth: (settingsJson?['windowWidth'] as num?)?.toDouble(),
        windowHeight: (settingsJson?['windowHeight'] as num?)?.toDouble(),
        columnsPerRow: columnsPerRow,
        listHeight: listHeight,
        syncEnabled: settingsJson?['syncEnabled'] as bool? ?? false,
      );

      // 保存新格式数据
      await saveManifest(manifest);
      for (final list in lists) {
        await saveList(list);
      }
      await saveLocalSettings(localSettings);

      // 备份并删除旧文件
      final backupFile = File('${root.path}/data.json.bak');
      await legacyFile.copy(backupFile.path);
      await legacyFile.delete();

      debugPrint('[SyncStorage] 数据迁移完成，已备份旧文件');
      return true;
    } catch (e) {
      debugPrint('[SyncStorage] 数据迁移失败: $e');
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _manifestSaveTimer?.cancel();
    _settingsSaveTimer?.cancel();
    for (final timer in _listSaveTimers.values) {
      timer.cancel();
    }
    _listSaveTimers.clear();
    _pendingManifest = null;
    _pendingSettings = null;
    _pendingLists.clear();
  }
}
