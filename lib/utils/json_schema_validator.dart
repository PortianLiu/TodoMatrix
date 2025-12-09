/// JSON Schema 验证器
/// 用于验证应用数据是否符合预定义的 JSON Schema
class JsonSchemaValidator {
  /// 当前支持的数据版本
  static const String currentVersion = '1.0';

  /// 验证 JSON 数据是否符合 AppData Schema
  /// 返回验证结果，包含是否有效和错误信息
  static ValidationResult validateAppData(Map<String, dynamic> json) {
    final errors = <String>[];

    // 验证必需字段
    if (!json.containsKey('version')) {
      errors.add('缺少必需字段: version');
    } else if (json['version'] is! String) {
      errors.add('version 必须是字符串类型');
    } else {
      final version = json['version'] as String;
      if (!RegExp(r'^\d+\.\d+$').hasMatch(version)) {
        errors.add('version 格式无效，应为 "x.y" 格式');
      }
    }

    if (!json.containsKey('lists')) {
      errors.add('缺少必需字段: lists');
    } else if (json['lists'] is! List) {
      errors.add('lists 必须是数组类型');
    } else {
      final lists = json['lists'] as List;
      for (var i = 0; i < lists.length; i++) {
        final listErrors = _validateTodoList(lists[i], 'lists[$i]');
        errors.addAll(listErrors);
      }
    }

    if (!json.containsKey('layout')) {
      errors.add('缺少必需字段: layout');
    } else if (json['layout'] is! Map) {
      errors.add('layout 必须是对象类型');
    } else {
      final layoutErrors = _validateLayoutSettings(
        json['layout'] as Map<String, dynamic>,
        'layout',
      );
      errors.addAll(layoutErrors);
    }

    if (!json.containsKey('settings')) {
      errors.add('缺少必需字段: settings');
    } else if (json['settings'] is! Map) {
      errors.add('settings 必须是对象类型');
    } else {
      final settingsErrors = _validateAppSettings(
        json['settings'] as Map<String, dynamic>,
        'settings',
      );
      errors.addAll(settingsErrors);
    }

    if (!json.containsKey('lastModified')) {
      errors.add('缺少必需字段: lastModified');
    } else if (json['lastModified'] is! String) {
      errors.add('lastModified 必须是字符串类型');
    } else {
      if (!_isValidDateTime(json['lastModified'] as String)) {
        errors.add('lastModified 格式无效，应为 ISO8601 日期时间格式');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// 验证 TodoList
  static List<String> _validateTodoList(dynamic list, String path) {
    final errors = <String>[];

    if (list is! Map) {
      errors.add('$path 必须是对象类型');
      return errors;
    }

    final map = list as Map<String, dynamic>;

    // 验证必需字段
    _validateRequiredString(map, 'id', path, errors);
    _validateRequiredString(map, 'title', path, errors);
    _validateRequiredDateTime(map, 'createdAt', path, errors);
    _validateRequiredDateTime(map, 'updatedAt', path, errors);
    _validateRequiredInt(map, 'sortOrder', path, errors);

    if (!map.containsKey('items')) {
      errors.add('$path 缺少必需字段: items');
    } else if (map['items'] is! List) {
      errors.add('$path.items 必须是数组类型');
    } else {
      final items = map['items'] as List;
      for (var i = 0; i < items.length; i++) {
        final itemErrors = _validateTodoItem(items[i], '$path.items[$i]');
        errors.addAll(itemErrors);
      }
    }

    return errors;
  }

  /// 验证 TodoItem
  static List<String> _validateTodoItem(dynamic item, String path) {
    final errors = <String>[];

    if (item is! Map) {
      errors.add('$path 必须是对象类型');
      return errors;
    }

    final map = item as Map<String, dynamic>;

    // 验证必需字段
    _validateRequiredString(map, 'id', path, errors);
    _validateRequiredString(map, 'description', path, errors);
    _validateRequiredBool(map, 'isCompleted', path, errors);
    _validateRequiredDateTime(map, 'createdAt', path, errors);
    _validateRequiredDateTime(map, 'updatedAt', path, errors);
    _validateRequiredInt(map, 'sortOrder', path, errors);

    // 验证 priority
    if (!map.containsKey('priority')) {
      errors.add('$path 缺少必需字段: priority');
    } else if (map['priority'] is! String) {
      errors.add('$path.priority 必须是字符串类型');
    } else {
      final priority = map['priority'] as String;
      if (!['low', 'medium', 'high'].contains(priority)) {
        errors.add('$path.priority 值无效，应为 low、medium 或 high');
      }
    }

    // 验证可选字段 dueDate
    if (map.containsKey('dueDate') && map['dueDate'] != null) {
      if (map['dueDate'] is! String) {
        errors.add('$path.dueDate 必须是字符串类型或 null');
      } else if (!_isValidDateTime(map['dueDate'] as String)) {
        errors.add('$path.dueDate 格式无效，应为 ISO8601 日期时间格式');
      }
    }

    return errors;
  }

  /// 验证 LayoutSettings
  static List<String> _validateLayoutSettings(
    Map<String, dynamic> map,
    String path,
  ) {
    final errors = <String>[];

    // 验证 columnsPerRow
    if (!map.containsKey('columnsPerRow')) {
      errors.add('$path 缺少必需字段: columnsPerRow');
    } else if (map['columnsPerRow'] is! int) {
      errors.add('$path.columnsPerRow 必须是整数类型');
    } else {
      final columns = map['columnsPerRow'] as int;
      if (columns < 1 || columns > 10) {
        errors.add('$path.columnsPerRow 值必须在 1-10 之间');
      }
    }

    // 验证 listOrder
    if (!map.containsKey('listOrder')) {
      errors.add('$path 缺少必需字段: listOrder');
    } else if (map['listOrder'] is! List) {
      errors.add('$path.listOrder 必须是数组类型');
    } else {
      final listOrder = map['listOrder'] as List;
      for (var i = 0; i < listOrder.length; i++) {
        if (listOrder[i] is! String) {
          errors.add('$path.listOrder[$i] 必须是字符串类型');
        }
      }
    }

    return errors;
  }

  /// 验证 AppSettings
  static List<String> _validateAppSettings(
    Map<String, dynamic> map,
    String path,
  ) {
    final errors = <String>[];

    // 验证 themeMode
    if (!map.containsKey('themeMode')) {
      errors.add('$path 缺少必需字段: themeMode');
    } else if (map['themeMode'] is! String) {
      errors.add('$path.themeMode 必须是字符串类型');
    } else {
      final themeMode = map['themeMode'] as String;
      if (!['light', 'dark', 'system'].contains(themeMode)) {
        errors.add('$path.themeMode 值无效，应为 light、dark 或 system');
      }
    }

    // 验证 syncEnabled
    _validateRequiredBool(map, 'syncEnabled', path, errors);

    // 验证 deviceName
    _validateRequiredString(map, 'deviceName', path, errors);

    return errors;
  }

  // 辅助验证方法
  static void _validateRequiredString(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path 缺少必需字段: $field');
    } else if (map[field] is! String) {
      errors.add('$path.$field 必须是字符串类型');
    }
  }

  static void _validateRequiredBool(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path 缺少必需字段: $field');
    } else if (map[field] is! bool) {
      errors.add('$path.$field 必须是布尔类型');
    }
  }

  static void _validateRequiredInt(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path 缺少必需字段: $field');
    } else if (map[field] is! int) {
      errors.add('$path.$field 必须是整数类型');
    }
  }

  static void _validateRequiredDateTime(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path 缺少必需字段: $field');
    } else if (map[field] is! String) {
      errors.add('$path.$field 必须是字符串类型');
    } else if (!_isValidDateTime(map[field] as String)) {
      errors.add('$path.$field 格式无效，应为 ISO8601 日期时间格式');
    }
  }

  static bool _isValidDateTime(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 验证结果
class ValidationResult {
  /// 是否有效
  final bool isValid;

  /// 错误信息列表
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult: 有效';
    }
    return 'ValidationResult: 无效\n${errors.join('\n')}';
  }
}
