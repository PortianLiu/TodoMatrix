import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/todo_provider.dart';
import '../providers/layout_provider.dart';
import '../services/window_service.dart';
import 'settings_panel.dart';
import 'todo_list_widget.dart';

// ignore: unused_import 用于 windowManager.startDragging()

/// 主界面
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ref.read(appDataProvider.notifier).loadData();
    if (mounted) {
      setState(() => _isLoading = false);
      // 应用保存的窗口设置（仅 Windows）
      _applyWindowSettings();
    }
  }

  /// 应用保存的窗口设置
  Future<void> _applyWindowSettings() async {
    if (kIsWeb || !Platform.isWindows) return;

    final settings = ref.read(appSettingsProvider);
    // 应用钉在桌面设置（使用保存的透明度）
    if (settings.pinToDesktop) {
      await WindowService.instance.setPinToDesktop(true, opacity: settings.pinOpacity);
    }
    // 应用贴边隐藏设置
    if (settings.edgeHideEnabled) {
      await WindowService.instance.setEdgeHide(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Windows 平台使用自定义标题栏
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // 自定义标题栏
          if (isWindows) _buildCustomTitleBar(),
          // 主内容
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 构建自定义标题栏（Windows）- 仅用于拖拽和工具栏
  Widget _buildCustomTitleBar() {
    return GestureDetector(
      onPanStart: (_) {
        // 通知开始拖拽
        WindowService.instance.notifyDragStart();
        windowManager.startDragging();
      },
      onPanEnd: (_) {
        // 通知结束拖拽
        WindowService.instance.notifyDragEnd();
      },
      child: Container(
        height: 56, // 与 AppBar 默认高度一致
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          children: [
            const SizedBox(width: 12),
            // 应用图标和标题
            Icon(
              Icons.checklist,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              'TodoMatrix',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const Spacer(),
            // 工具栏按钮（图钉在最左边，贴边隐藏在第二位）
            _buildPinButton(),
            _buildEdgeHideButton(),
            _buildColumnsSelector(),
            IconButton(
              icon: Icon(Icons.add, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
              tooltip: '新建列表',
              onPressed: _createNewList,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
              tooltip: '设置',
              onPressed: _openSettings,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnsSelector() {
    final columns = ref.watch(columnsPerRowProvider);

    return PopupMenuButton<int>(
      icon: Icon(Icons.grid_view, color: Theme.of(context).colorScheme.onPrimaryContainer),
      tooltip: '调整列数',
      initialValue: columns,
      onSelected: (value) {
        ref.read(appDataProvider.notifier).setColumnsPerRow(value);
      },
      itemBuilder: (context) => List.generate(
        6,
        (index) => PopupMenuItem(
          value: index + 1,
          child: Row(
            children: [
              if (columns == index + 1) const Icon(Icons.check, size: 18),
              if (columns == index + 1) const SizedBox(width: 8),
              Text('${index + 1} 列'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return _buildEmptyState();
    }

    final columns = ref.watch(columnsPerRowProvider);
    return _buildGridView(lists, columns);
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有待办列表',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _createNewList,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个列表'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List lists, int columns) {
    final listHeight = ref.watch(listHeightProvider);
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: listHeight, // 使用设置的列表高度
        ),
        itemCount: lists.length,
        itemBuilder: (context, index) {
          final list = lists[index];
          return DragTarget<Map<String, String>>(
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data['sourceListId'] != list.id) {
                ref.read(appDataProvider.notifier).moveTodoItemToList(
                      data['sourceListId']!,
                      list.id,
                      data['itemId']!,
                    );
              }
            },
            onWillAcceptWithDetails: (details) {
              return details.data['sourceListId'] != list.id;
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: candidateData.isNotEmpty
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: TodoListWidget(listId: list.id),
              );
            },
          );
        },
      ),
    );
  }

  /// 构建钉在桌面按钮（倾斜图钉效果）
  Widget _buildPinButton() {
    final settings = ref.watch(appSettingsProvider);
    final isPinned = settings.pinToDesktop;

    return IconButton(
      icon: Transform.rotate(
        angle: isPinned ? 0 : math.pi * 2 / 9, // 未钉住时倾斜 40 度
        child: Icon(
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          size: 20,
          color: isPinned
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      tooltip: isPinned ? '取消钉在桌面' : '钉在桌面',
      onPressed: _togglePinToDesktop,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 构建贴边隐藏按钮
  Widget _buildEdgeHideButton() {
    final settings = ref.watch(appSettingsProvider);
    final isEnabled = settings.edgeHideEnabled;

    return IconButton(
      icon: Icon(
        isEnabled ? Icons.dock : Icons.dock_outlined,
        size: 20,
        color: isEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      tooltip: isEnabled ? '关闭贴边隐藏' : '开启贴边隐藏',
      onPressed: _toggleEdgeHide,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 切换贴边隐藏状态
  Future<void> _toggleEdgeHide() async {
    final settings = ref.read(appSettingsProvider);
    final newValue = !settings.edgeHideEnabled;
    
    // 更新设置
    ref.read(appDataProvider.notifier).updateSettings(
      settings.copyWith(edgeHideEnabled: newValue),
    );
    
    // 应用窗口设置
    await WindowService.instance.setEdgeHide(newValue);
  }

  /// 切换钉在桌面状态
  Future<void> _togglePinToDesktop() async {
    final settings = ref.read(appSettingsProvider);
    final newValue = !settings.pinToDesktop;
    
    // 更新设置
    ref.read(appDataProvider.notifier).updateSettings(
      settings.copyWith(pinToDesktop: newValue),
    );
    
    // 应用窗口设置
    await WindowService.instance.setPinToDesktop(newValue, opacity: settings.pinOpacity);
  }

  void _createNewList() {
    ref.read(appDataProvider.notifier).createList();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPanel(),
      ),
    );
  }
}
