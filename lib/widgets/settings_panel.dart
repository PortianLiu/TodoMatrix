import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/layout_provider.dart';
import '../providers/todo_provider.dart';

/// 设置面板
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final layoutSettings = ref.watch(layoutSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 主题设置
          _buildSectionHeader(context, '外观'),
          _buildThemeTile(context, ref, settings.themeMode),
          const Divider(),

          // 布局设置
          _buildSectionHeader(context, '布局'),
          _buildColumnsTile(context, ref, layoutSettings.columnsPerRow),
          const Divider(),

          // 同步设置（预留）
          _buildSectionHeader(context, '同步'),
          _buildSyncTile(context, ref, settings.syncEnabled),
          _buildDeviceNameTile(context, ref, settings.deviceName),
        ],
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  /// 构建主题设置项
  Widget _buildThemeTile(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题'),
      subtitle: Text(_getThemeModeText(currentMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, ref, currentMode),
    );
  }

  /// 获取主题模式文本
  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  /// 显示主题选择对话框
  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, ref, ThemeMode.system, '跟随系统', currentMode),
            _buildThemeOption(context, ref, ThemeMode.light, '浅色', currentMode),
            _buildThemeOption(context, ref, ThemeMode.dark, '深色', currentMode),
          ],
        ),
      ),
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
    String label,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: mode,
      groupValue: currentMode,
      onChanged: (value) {
        if (value != null) {
          ref.read(appDataProvider.notifier).setThemeMode(value);
          Navigator.of(context).pop();
        }
      },
    );
  }

  /// 构建列数设置项
  Widget _buildColumnsTile(BuildContext context, WidgetRef ref, int currentColumns) {
    return ListTile(
      leading: const Icon(Icons.grid_view_outlined),
      title: const Text('每行列数'),
      subtitle: Text('$currentColumns 列'),
      trailing: SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: currentColumns > 1
                  ? () => ref.read(appDataProvider.notifier).setColumnsPerRow(currentColumns - 1)
                  : null,
            ),
            Text('$currentColumns', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: currentColumns < 10
                  ? () => ref.read(appDataProvider.notifier).setColumnsPerRow(currentColumns + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建同步开关
  Widget _buildSyncTile(BuildContext context, WidgetRef ref, bool syncEnabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.sync_outlined),
      title: const Text('启用局域网同步'),
      subtitle: Text(syncEnabled ? '已启用' : '已禁用'),
      value: syncEnabled,
      onChanged: (value) {
        final currentSettings = ref.read(appSettingsProvider);
        ref.read(appDataProvider.notifier).updateSettings(
              currentSettings.copyWith(syncEnabled: value),
            );
      },
    );
  }

  /// 构建设备名称设置项
  Widget _buildDeviceNameTile(BuildContext context, WidgetRef ref, String deviceName) {
    return ListTile(
      leading: const Icon(Icons.devices_outlined),
      title: const Text('设备名称'),
      subtitle: Text(deviceName),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _showDeviceNameDialog(context, ref, deviceName),
    );
  }

  /// 显示设备名称编辑对话框
  void _showDeviceNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入设备名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final currentSettings = ref.read(appSettingsProvider);
                ref.read(appDataProvider.notifier).updateSettings(
                      currentSettings.copyWith(deviceName: newName),
                    );
              }
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
