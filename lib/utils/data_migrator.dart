import '../models/settings.dart';
import 'json_schema_validator.dart';

/// 数据迁移器
/// 负责将旧版本数据迁移到新版本格式
class DataMigrator {
  /// 当前数据版本
  static const String currentVersion = '1.0';

  /// 支持的版本列表（按顺序）
  static const List<String> supportedVersions = ['1.0'];

  /// 迁移数据到最新版本
  /// 返回迁移后的 JSON 数据
  static MigrationResult migrate(Map<String, dynamic> json) {
    final version = json['version'] as String? ?? '0.0';
    final migrations = <String>[];

    var currentData = Map<String, dynamic>.from(json);

    // 检查版本是否需要迁移
    if (version == currentVersion) {
      return MigrationResult(
        data: currentData,
        fromVersion: version,
        toVersion: currentVersion,
        migrations: migrations,
        success: true,
      );
    }

    // 执行版本迁移
    try {
      // 从旧版本迁移到 1.0
      if (_compareVersions(version, '1.0') < 0) {
        currentData = _migrateToV1_0(currentData);
        migrations.add('迁移到 v1.0: 添加默认字段');
      }

      // 未来版本迁移可以在这里添加
      // if (_compareVersions(currentData['version'], '1.1') < 0) {
      //   currentData = _migrateToV1_1(currentData);
      //   migrations.add('迁移到 v1.1: ...');
      // }

      return MigrationResult(
        data: currentData,
        fromVersion: version,
        toVersion: currentVersion,
        migrations: migrations,
        success: true,
      );
    } catch (e) {
      return MigrationResult(
        data: json,
        fromVersion: version,
        toVersion: currentVersion,
        migrations: migrations,
        success: false,
        error: '迁移失败: $e',
      );
    }
  }

  /// 迁移到 v1.0
  static Map<String, dynamic> _migrateToV1_0(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);

    // 设置版本号
    result['version'] = '1.0';

    // 确保 lists 存在
    if (!result.containsKey('lists') || result['lists'] is! List) {
      result['lists'] = <Map<String, dynamic>>[];
    } else {
      // 迁移每个列表
      final lists = (result['lists'] as List).map((list) {
        if (list is! Map) return <String, dynamic>{};
        return _migrateTodoList(Map<String, dynamic>.from(list));
      }).toList();
      result['lists'] = lists;
    }

    // 确保 layout 存在
    if (!result.containsKey('layout') || result['layout'] is! Map) {
      result['layout'] = const LayoutSettings().toJson();
    } else {
      result['layout'] = _migrateLayoutSettings(
        Map<String, dynamic>.from(result['layout'] as Map),
      );
    }

    // 确保 settings 存在
    if (!result.containsKey('settings') || result['settings'] is! Map) {
      result['settings'] = const AppSettings().toJson();
    } else {
      result['settings'] = _migrateAppSettings(
        Map<String, dynamic>.from(result['settings'] as Map),
      );
    }

    // 确保 lastModified 存在
    if (!result.containsKey('lastModified') || result['lastModified'] is! String) {
      result['lastModified'] = DateTime.now().toIso8601String();
    }

    return result;
  }

  /// 迁移 TodoList
  static Map<String, dynamic> _migrateTodoList(Map<String, dynamic> list) {
    final result = Map<String, dynamic>.from(list);
    final now = DateTime.now().toIso8601String();

    // 确保必需字段存在
    result['id'] ??= _generateUuid();
    result['title'] ??= '未命名列表';
    result['createdAt'] ??= now;
    result['updatedAt'] ??= now;
    result['sortOrder'] ??= 0;

    // 迁移 items
    if (!result.containsKey('items') || result['items'] is! List) {
      result['items'] = <Map<String, dynamic>>[];
    } else {
      final items = (result['items'] as List).map((item) {
        if (item is! Map) return <String, dynamic>{};
        return _migrateTodoItem(Map<String, dynamic>.from(item));
      }).toList();
      result['items'] = items;
    }

    return result;
  }

  /// 迁移 TodoItem
  static Map<String, dynamic> _migrateTodoItem(Map<String, dynamic> item) {
    final result = Map<String, dynamic>.from(item);
    final now = DateTime.now().toIso8601String();

    // 确保必需字段存在
    result['id'] ??= _generateUuid();
    result['description'] ??= '';
    result['isCompleted'] ??= false;
    result['priority'] ??= 'medium';
    result['createdAt'] ??= now;
    result['updatedAt'] ??= now;
    result['sortOrder'] ??= 0;

    // 验证 priority 值
    final priority = result['priority'];
    if (priority is! String || !['low', 'medium', 'high'].contains(priority)) {
      result['priority'] = 'medium';
    }

    return result;
  }

  /// 迁移 LayoutSettings
  static Map<String, dynamic> _migrateLayoutSettings(Map<String, dynamic> layout) {
    final result = Map<String, dynamic>.from(layout);

    // 确保必需字段存在
    result['columnsPerRow'] ??= 3;
    result['listOrder'] ??= <String>[];

    // 验证 columnsPerRow 范围
    final columns = result['columnsPerRow'];
    if (columns is! int || columns < 1 || columns > 10) {
      result['columnsPerRow'] = 3;
    }

    // 确保 listOrder 是字符串列表
    if (result['listOrder'] is! List) {
      result['listOrder'] = <String>[];
    }

    return result;
  }

  /// 迁移 AppSettings
  static Map<String, dynamic> _migrateAppSettings(Map<String, dynamic> settings) {
    final result = Map<String, dynamic>.from(settings);

    // 确保必需字段存在
    result['themeMode'] ??= 'system';
    result['syncEnabled'] ??= false;
    result['deviceName'] ??= 'My Device';

    // 验证 themeMode 值
    final themeMode = result['themeMode'];
    if (themeMode is! String || !['light', 'dark', 'system'].contains(themeMode)) {
      result['themeMode'] = 'system';
    }

    // 可选字段的默认值
    result['minimizeToTray'] ??= true;
    result['pinToDesktop'] ??= false;
    result['edgeHideEnabled'] ??= false;

    return result;
  }

  /// 比较版本号
  /// 返回: -1 (v1 < v2), 0 (v1 == v2), 1 (v1 > v2)
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (var i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// 生成简单的 UUID（用于迁移时生成缺失的 ID）
  static String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'migrated-$now-${now.hashCode.abs()}';
  }

  /// 尝试修复无效数据
  /// 返回修复后的数据，如果无法修复则返回 null
  static Map<String, dynamic>? tryRepair(Map<String, dynamic> json) {
    try {
      // 首先尝试迁移
      final migrationResult = migrate(json);
      if (!migrationResult.success) {
        return null;
      }

      // 验证迁移后的数据
      final validationResult = JsonSchemaValidator.validateAppData(
        migrationResult.data,
      );

      if (validationResult.isValid) {
        return migrationResult.data;
      }

      // 如果仍然无效，返回 null
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// 迁移结果
class MigrationResult {
  /// 迁移后的数据
  final Map<String, dynamic> data;

  /// 原始版本
  final String fromVersion;

  /// 目标版本
  final String toVersion;

  /// 执行的迁移步骤
  final List<String> migrations;

  /// 是否成功
  final bool success;

  /// 错误信息
  final String? error;

  const MigrationResult({
    required this.data,
    required this.fromVersion,
    required this.toVersion,
    required this.migrations,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    if (success) {
      return 'MigrationResult: $fromVersion -> $toVersion (${migrations.length} 步迁移)';
    }
    return 'MigrationResult: 失败 - $error';
  }
}
