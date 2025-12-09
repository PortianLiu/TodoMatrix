import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';
import '../utils/json_schema_validator.dart';
import '../utils/data_migrator.dart';

/// 存储相关错误基类
sealed class StorageError implements Exception {
  const StorageError();
}

/// 文件未找到错误
class FileNotFoundError extends StorageError {
  final String path;
  const FileNotFoundError(this.path);

  @override
  String toString() => '文件未找到: $path';
}

/// 无效数据格式错误
class InvalidDataFormatError extends StorageError {
  final String message;
  final String? details;
  const InvalidDataFormatError(this.message, [this.details]);

  @override
  String toString() => '数据格式错误: $message${details != null ? ' ($details)' : ''}';
}

/// 存储写入错误
class StorageWriteError extends StorageError {
  final String path;
  final String reason;
  const StorageWriteError(this.path, this.reason);

  @override
  String toString() => '写入失败 ($path): $reason';
}

/// 存储服务接口
abstract class IStorageService {
  /// 加载应用数据
  Future<AppData> loadData();

  /// 保存应用数据
  Future<void> saveData(AppData data);

  /// 导出数据到指定文件
  Future<void> exportToFile(String path);

  /// 从指定文件导入数据
  Future<AppData> importFromFile(String path);

  /// 触发自动保存（带防抖）
  void triggerAutoSave(AppData data);

  /// 释放资源
  void dispose();
}

/// 存储服务实现
/// 负责数据的持久化存储、导入导出
class StorageService implements IStorageService {
  /// 数据文件名
  static const String _dataFileName = 'data.json';

  /// 备份目录名
  static const String _backupDirName = 'backups';

  /// 自动保存防抖时间（毫秒）
  static const int _autoSaveDebounceMs = 2000;

  /// 保存失败重试次数
  static const int _maxRetries = 3;

  /// 重试间隔（毫秒）
  static const int _retryDelayMs = 5000;

  /// 自动保存防抖定时器
  Timer? _autoSaveTimer;

  /// 待保存的数据
  AppData? _pendingData;

  /// 当前重试次数
  int _currentRetry = 0;

  /// 保存失败回调
  final void Function(StorageError error)? onSaveError;

  /// 保存成功回调
  final void Function()? onSaveSuccess;

  /// 自定义数据路径（可选）
  String? customDataPath;

  StorageService({
    this.onSaveError,
    this.onSaveSuccess,
    this.customDataPath,
  });

  /// 获取数据存储目录
  Future<Directory> _getDataDirectory() async {
    if (customDataPath != null && customDataPath!.isNotEmpty) {
      final dir = Directory(customDataPath!);
      if (await dir.exists()) {
        return dir;
      }
      // 自定义路径不可用，回退到默认路径
    }

    if (Platform.isWindows) {
      // Windows: %APPDATA%/TodoMatrix/
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final dir = Directory('$appData/TodoMatrix');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }

    // 默认使用应用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/TodoMatrix');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 获取数据文件路径
  Future<File> _getDataFile() async {
    final dir = await _getDataDirectory();
    return File('${dir.path}/$_dataFileName');
  }

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    final dir = await _getDataDirectory();
    final backupDir = Directory('${dir.path}/$_backupDirName');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  @override
  Future<AppData> loadData() async {
    final file = await _getDataFile();

    if (!await file.exists()) {
      // 文件不存在，返回空数据
      return AppData.empty();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 验证数据格式
      final validationResult = JsonSchemaValidator.validateAppData(json);

      if (!validationResult.isValid) {
        // 尝试迁移和修复数据
        final repairedData = DataMigrator.tryRepair(json);
        if (repairedData != null) {
          // 修复成功，保存修复后的数据
          final appData = AppData.fromJson(repairedData);
          await saveData(appData);
          return appData;
        }

        // 无法修复，抛出错误
        throw InvalidDataFormatError(
          '数据格式验证失败',
          validationResult.errors.join('; '),
        );
      }

      // 检查是否需要版本迁移
      final migrationResult = DataMigrator.migrate(json);
      if (migrationResult.migrations.isNotEmpty) {
        // 有迁移操作，保存迁移后的数据
        final appData = AppData.fromJson(migrationResult.data);
        await saveData(appData);
        return appData;
      }

      return AppData.fromJson(json);
    } on FormatException catch (e) {
      throw InvalidDataFormatError('JSON 解析失败', e.message);
    } on StorageError {
      rethrow;
    } catch (e) {
      throw InvalidDataFormatError('数据加载失败', e.toString());
    }
  }

  @override
  Future<void> saveData(AppData data) async {
    final file = await _getDataFile();

    try {
      // 创建备份（如果文件已存在）
      if (await file.exists()) {
        await _createBackup(file);
      }

      // 序列化并保存
      final json = data.toJson();
      final content = const JsonEncoder.withIndent('  ').convert(json);
      await file.writeAsString(content);

      _currentRetry = 0;
      onSaveSuccess?.call();
    } on FileSystemException catch (e) {
      throw StorageWriteError(file.path, e.message);
    } catch (e) {
      throw StorageWriteError(file.path, e.toString());
    }
  }

  /// 创建备份文件
  Future<void> _createBackup(File sourceFile) async {
    try {
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final backupFile = File('${backupDir.path}/data_$timestamp.json');
      await sourceFile.copy(backupFile.path);

      // 清理旧备份（保留最近 10 个）
      await _cleanOldBackups(backupDir);
    } catch (e) {
      // 备份失败不影响主流程
      debugPrint('备份创建失败: $e');
    }
  }

  /// 清理旧备份文件
  Future<void> _cleanOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();

      if (files.length <= 10) return;

      // 按修改时间排序
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // 删除旧文件
      for (var i = 10; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      debugPrint('清理备份失败: $e');
    }
  }

  @override
  Future<void> exportToFile(String path) async {
    final data = await loadData();
    final json = data.toJson();
    final content = const JsonEncoder.withIndent('  ').convert(json);

    final file = File(path);
    try {
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      throw StorageWriteError(path, e.message);
    }
  }

  @override
  Future<AppData> importFromFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw FileNotFoundError(path);
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 验证数据格式
      final validationResult = JsonSchemaValidator.validateAppData(json);

      if (!validationResult.isValid) {
        // 尝试迁移和修复数据
        final repairedData = DataMigrator.tryRepair(json);
        if (repairedData != null) {
          return AppData.fromJson(repairedData);
        }

        // 无法修复，抛出错误
        throw InvalidDataFormatError(
          '导入数据格式验证失败',
          validationResult.errors.join('; '),
        );
      }

      // 检查是否需要版本迁移
      final migrationResult = DataMigrator.migrate(json);
      return AppData.fromJson(migrationResult.data);
    } on FormatException catch (e) {
      throw InvalidDataFormatError('JSON 解析失败', e.message);
    } on StorageError {
      rethrow;
    } catch (e) {
      throw InvalidDataFormatError('数据导入失败', e.toString());
    }
  }

  @override
  void triggerAutoSave(AppData data) {
    _pendingData = data;

    // 取消之前的定时器
    _autoSaveTimer?.cancel();

    // 设置新的防抖定时器
    _autoSaveTimer = Timer(
      const Duration(milliseconds: _autoSaveDebounceMs),
      _performAutoSave,
    );
  }

  /// 执行自动保存
  Future<void> _performAutoSave() async {
    if (_pendingData == null) return;

    final dataToSave = _pendingData!;
    _pendingData = null;

    try {
      await saveData(dataToSave);
    } on StorageError catch (e) {
      _handleSaveError(e, dataToSave);
    }
  }

  /// 处理保存错误（带重试）
  void _handleSaveError(StorageError error, AppData data) {
    _currentRetry++;

    if (_currentRetry < _maxRetries) {
      // 安排重试
      Timer(const Duration(milliseconds: _retryDelayMs), () {
        _pendingData = data;
        _performAutoSave();
      });
    } else {
      // 达到最大重试次数，通知错误
      _currentRetry = 0;
      onSaveError?.call(error);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _pendingData = null;
  }
}
