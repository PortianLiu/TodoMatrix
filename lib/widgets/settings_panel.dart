import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../models/settings.dart';
import '../providers/data_provider.dart';
import '../providers/sync_provider.dart';
import '../services/discovery_service.dart';
import '../services/window_service.dart';
import 'color_picker_dialog.dart';

/// 从十六进制字符串解析颜色
Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// 设置面板
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(localSettingsProvider);
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: isWindows ? _buildWindowsAppBar(context) : AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 主题设置
          _buildSectionHeader(context, '外观'),
          _buildThemeTile(context, ref, settings.themeMode),
          _buildThemeColorTile(context, ref, settings.themeColor),
          const Divider(),

          // 布局设置（列数和高度仅 Windows 显示，列表排序所有平台显示）
          _buildSectionHeader(context, '布局'),
          if (isWindows) ...[
            _buildColumnsTile(context, ref, settings.columnsPerRow),
            _buildListHeightTile(context, ref, settings.listHeight),
          ],
          _buildListOrderTile(context, ref),
          const Divider(),

          // 同步设置
          _buildSectionHeader(context, '同步'),
          _buildSyncTile(context, ref, settings.syncEnabled),
          _buildDeviceNameTile(context, ref, settings.deviceName),
          if (settings.syncEnabled) ...[
            _buildSyncStatusTile(context, ref),
            _buildDeviceListTile(context, ref),
          ],
          const Divider(),

          // Windows 高级功能（仅 Windows 平台显示）
          if (!kIsWeb && Platform.isWindows) ...[
            _buildSectionHeader(context, 'Windows 功能'),
            _buildPinToDesktopTile(context, ref, settings.pinToDesktop),
            if (settings.pinToDesktop)
              _buildPinOpacityTile(context, ref, settings.pinOpacity),
            _buildEdgeHideTile(context, ref, settings.edgeHideEnabled),
            _buildCustomDataPathTile(context, ref, settings.customDataPath),
          ],
        ],
      ),
    );
  }

  /// 构建 Windows 自定义 AppBar（支持拖拽）
  PreferredSizeWidget _buildWindowsAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: GestureDetector(
        onPanStart: (_) {
          // 通知开始拖拽
          WindowService.instance.notifyDragStart();
          windowManager.startDragging();
        },
        onPanEnd: (_) {
          // 通知结束拖拽
          WindowService.instance.notifyDragEnd();
        },
        child: AppBar(
          title: const Text('设置'),
        ),
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
          ref.read(dataProvider.notifier).setThemeMode(value);
          Navigator.of(context).pop();
        }
      },
    );
  }

  /// 构建主题色设置项
  Widget _buildThemeColorTile(BuildContext context, WidgetRef ref, String currentColor) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _hexToColor(currentColor),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
      title: const Text('主题色'),
      subtitle: Text('#$currentColor'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeColorDialog(context, ref, currentColor),
    );
  }

  /// 显示主题色选择对话框
  void _showThemeColorDialog(BuildContext context, WidgetRef ref, String currentColor) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        title: '选择主题色',
        currentColor: currentColor,
        presetColors: ThemeColors.presetColors,
        onColorSelected: (colorHex) {
          ref.read(dataProvider.notifier).setThemeColor(colorHex);
        },
      ),
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
                  ? () => ref.read(dataProvider.notifier).setColumnsPerRow(currentColumns - 1)
                  : null,
            ),
            Text('$currentColumns', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: currentColumns < 10
                  ? () => ref.read(dataProvider.notifier).setColumnsPerRow(currentColumns + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建列表高度设置项
  Widget _buildListHeightTile(BuildContext context, WidgetRef ref, double currentHeight) {
    return ListTile(
      leading: const Icon(Icons.height_outlined),
      title: const Text('列表高度'),
      subtitle: Text('${currentHeight.toInt()} 像素'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: currentHeight,
          min: 200,
          max: 800,
          divisions: 12,
          label: '${currentHeight.toInt()}',
          onChanged: (value) {
            ref.read(dataProvider.notifier).setListHeight(value);
          },
        ),
      ),
    );
  }

  /// 构建列表排序设置项
  /// 构建列表排序设置项（内嵌可拖拽方块）
  Widget _buildListOrderTile(BuildContext context, WidgetRef ref) {
    return _ListOrderSection();
  }

  /// 构建同步开关
  Widget _buildSyncTile(BuildContext context, WidgetRef ref, bool syncEnabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.sync_outlined),
      title: const Text('启用局域网同步'),
      subtitle: Text(syncEnabled ? '已启用' : '已禁用'),
      value: syncEnabled,
      onChanged: (value) {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
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
                final currentSettings = ref.read(localSettingsProvider);
                ref.read(dataProvider.notifier).updateSettings(
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

  /// 构建同步状态项
  Widget _buildSyncStatusTile(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final status = syncState.status;

    String statusText;
    IconData statusIcon;
    Color? statusColor;
    bool isAnimating = false;

    switch (status) {
      case SyncStatus.idle:
        statusText = syncState.isListening 
            ? '监听中 (${syncState.devices.length} 个设备在线)'
            : '未启动';
        statusIcon = syncState.isListening ? Icons.wifi : Icons.cloud_outlined;
        statusColor = syncState.devices.isNotEmpty ? Colors.green : null;
        break;
      case SyncStatus.broadcasting:
        statusText = '正在广播...';
        statusIcon = Icons.sync;
        statusColor = Colors.blue;
        isAnimating = true;
        break;
      case SyncStatus.connecting:
        statusText = syncState.message ?? '正在连接...';
        statusIcon = Icons.sync;
        statusColor = Colors.orange;
        isAnimating = true;
        break;
      case SyncStatus.syncing:
        statusText = syncState.message ?? '正在同步...';
        statusIcon = Icons.sync;
        statusColor = Colors.orange;
        isAnimating = true;
        break;
      case SyncStatus.completed:
        statusText = syncState.lastResult?.toString() ?? '同步完成';
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case SyncStatus.failed:
        statusText = syncState.message ?? '同步失败';
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
    }

    return ListTile(
      leading: _SyncStatusIcon(
        icon: statusIcon,
        color: statusColor,
        isAnimating: isAnimating,
      ),
      title: const Text('同步状态'),
      subtitle: Text(statusText),
      trailing: IconButton(
        icon: const Icon(Icons.sync),
        tooltip: '立即同步',
        onPressed: () async {
          final settings = ref.read(localSettingsProvider);
          final notifier = ref.read(syncProvider.notifier);
          await notifier.initialize(settings.deviceName);
          await notifier.broadcastAndSync();
        },
      ),
    );
  }

  /// 构建设备列表项
  Widget _buildDeviceListTile(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(discoveredDevicesProvider);

    if (devices.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.devices_other),
        title: Text('附近设备'),
        subtitle: Text('未发现设备，请确保其他设备已开启同步'),
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.devices_other),
      title: const Text('附近设备'),
      subtitle: Text('发现 ${devices.length} 个设备'),
      children: devices.map((device) => _buildDeviceItem(context, ref, device)).toList(),
    );
  }

  /// 构建单个设备项
  Widget _buildDeviceItem(BuildContext context, WidgetRef ref, DeviceInfo device) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(device.deviceName),
      subtitle: Text(device.address.address),
      trailing: FilledButton.tonal(
        onPressed: () => ref.read(syncProvider.notifier).syncWithDevice(device),
        child: const Text('同步'),
      ),
    );
  }

  /// 构建钉在桌面设置项
  Widget _buildPinToDesktopTile(BuildContext context, WidgetRef ref, bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.push_pin_outlined),
      title: const Text('钉在桌面'),
      subtitle: const Text('窗口半透明置顶，不占用任务栏位置'),
      value: enabled,
      onChanged: (value) async {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(pinToDesktop: value),
            );
        // 应用窗口设置（使用保存的透明度）
        await WindowService.instance.setPinToDesktop(value, opacity: currentSettings.pinOpacity);
      },
    );
  }

  /// 构建钉在桌面透明度设置项
  Widget _buildPinOpacityTile(BuildContext context, WidgetRef ref, double opacity) {
    return ListTile(
      leading: const Icon(Icons.opacity_outlined),
      title: const Text('窗口透明度'),
      subtitle: Text('${(opacity * 100).toInt()}%'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: opacity,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          label: '${(opacity * 100).toInt()}%',
          onChanged: (value) async {
            final currentSettings = ref.read(localSettingsProvider);
            ref.read(dataProvider.notifier).updateSettings(
                  currentSettings.copyWith(pinOpacity: value),
                );
            // 实时应用透明度
            await WindowService.instance.setPinOpacity(value);
          },
        ),
      ),
    );
  }

  /// 构建贴边隐藏设置项
  Widget _buildEdgeHideTile(BuildContext context, WidgetRef ref, bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.border_left_outlined),
      title: const Text('贴边隐藏'),
      subtitle: const Text('窗口贴边后自动隐藏，鼠标靠近时滑出'),
      value: enabled,
      onChanged: (value) async {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(edgeHideEnabled: value),
            );
        // 应用窗口设置
        await WindowService.instance.setEdgeHide(value);
      },
    );
  }

  /// 构建自定义数据路径设置项
  Widget _buildCustomDataPathTile(BuildContext context, WidgetRef ref, String? currentPath) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: const Text('数据存储路径'),
      subtitle: Text(currentPath ?? '默认路径（%APPDATA%/TodoMatrix）'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentPath != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '恢复默认',
              onPressed: () => _resetDataPath(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '选择文件夹',
            onPressed: () => _selectDataPath(context, ref),
          ),
        ],
      ),
    );
  }

  /// 选择数据路径
  Future<void> _selectDataPath(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择数据存储路径',
    );

    if (result != null) {
      // 确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更改数据路径'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('确定要将数据存储路径更改为：'),
              const SizedBox(height: 8),
              Text(
                result,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '注意：更改路径后需要重启应用才能生效。\n现有数据不会自动迁移。',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(customDataPath: result),
            );
        // 提示重启
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据路径已更改，请重启应用以生效')),
          );
        }
      }
    }
  }

  /// 重置数据路径
  Future<void> _resetDataPath(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认路径'),
        content: const Text('确定要恢复默认数据存储路径吗？\n更改后需要重启应用才能生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentSettings = ref.read(localSettingsProvider);
      ref.read(dataProvider.notifier).updateSettings(
            currentSettings.copyWith(clearCustomDataPath: true),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复默认路径，请重启应用以生效')),
        );
      }
    }
  }
}


/// 列表排序区域（内嵌可拖拽方块，即时生效）
class _ListOrderSection extends ConsumerStatefulWidget {
  const _ListOrderSection();

  @override
  ConsumerState<_ListOrderSection> createState() => _ListOrderSectionState();
}

class _ListOrderSectionState extends ConsumerState<_ListOrderSection> {
  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.reorder),
        title: Text('列表排序'),
        subtitle: Text('暂无列表'),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reorder,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 10),
              Text(
                '列表排序',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(width: 10),
              Text(
                '拖拽调整顺序',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ReorderableWrap(
            spacing: 8,
            runSpacing: 8,
            onReorder: (oldIndex, newIndex) {
              // 即时保存排序
              final currentOrder = lists.map((l) => l.id).toList();
              final item = currentOrder.removeAt(oldIndex);
              currentOrder.insert(newIndex, item);
              ref.read(dataProvider.notifier).updateListOrder(currentOrder);
            },
            children: lists.map((list) {
              return _buildListChip(context, list);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListChip(BuildContext context, dynamic list) {
    // 获取列表底色（适配深浅色模式）
    Color bgColor;
    if (list.backgroundColor != null && list.backgroundColor != 'ffffff') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final baseColor = _hexToColor(list.backgroundColor!);
      if (isDark) {
        // 深色模式：降低亮度
        final hsl = HSLColor.fromColor(baseColor);
        final darkHsl = hsl.withLightness((hsl.lightness * 0.3).clamp(0.15, 0.35));
        bgColor = darkHsl.toColor();
      } else {
        bgColor = baseColor;
      }
    } else {
      bgColor = Theme.of(context).cardColor;
    }

    return Container(
      key: ValueKey(list.id),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        list.title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// 可重排序的 Wrap 组件
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;
  final double spacing;
  final double runSpacing;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.onReorder,
    this.spacing = 0,
    this.runSpacing = 0,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        return Draggable<int>(
          data: index,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(opacity: 0.9, child: child),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) {
              widget.onReorder(details.data, index);
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: candidateData.isNotEmpty
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
                child: child,
              );
            },
          ),
        );
      }),
    );
  }
}

/// 同步状态图标（带旋转动画）
class _SyncStatusIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final bool isAnimating;

  const _SyncStatusIcon({
    required this.icon,
    this.color,
    this.isAnimating = false,
  });

  @override
  State<_SyncStatusIcon> createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends State<_SyncStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_SyncStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.forward().then((_) {
        if (!widget.isAnimating) {
          _controller.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 同步图标需要水平翻转以适应旋转方向
    final needsFlip = widget.icon == Icons.sync;
    
    if (!widget.isAnimating) {
      if (needsFlip) {
        return Transform.scale(
          scaleX: -1,
          child: Icon(widget.icon, color: widget.color),
        );
      }
      return Icon(widget.icon, color: widget.color);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (needsFlip) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(-1.0, 1.0)
              ..rotateZ(-_controller.value * 2 * 3.14159), // 逆时针旋转（翻转后视觉上为顺时针）
            child: Icon(widget.icon, color: widget.color),
          );
        }
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Icon(widget.icon, color: widget.color),
        );
      },
    );
  }
}
