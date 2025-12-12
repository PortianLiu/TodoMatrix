import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/data_provider.dart';
import '../providers/sync_provider.dart';
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
    try {
      await ref.read(dataProvider.notifier).loadData();
    } catch (e, stackTrace) {
      debugPrint('[MainScreen] 加载数据异常: $e');
      debugPrint('[MainScreen] 堆栈: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // 应用保存的窗口设置（仅 Windows）
        _applyWindowSettings();
      }
    }
  }

  /// 应用保存的窗口设置
  Future<void> _applyWindowSettings() async {
    if (kIsWeb || !Platform.isWindows) return;

    final settings = ref.read(localSettingsProvider);
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

    // Windows 平台使用自定义标题栏 + 网格布局
    // 移动端使用标签页布局
    final isWindows = !kIsWeb && Platform.isWindows;

    if (isWindows) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            _buildCustomTitleBar(),
            Expanded(child: _buildWindowsBody()),
          ],
        ),
      );
    } else {
      return _buildMobileLayout();
    }
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
            // 工具栏按钮（同步按钮在最左边）
            _buildSyncButton(),
            _buildPinButton(),
            _buildEdgeHideButton(),
            _buildColumnsSelector(),
            IconButton(
              icon: Icon(Icons.add, size: 21, color: Theme.of(context).colorScheme.onPrimaryContainer),
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
      icon: Icon(Icons.grid_view, size: 19, color: Theme.of(context).colorScheme.onPrimaryContainer),
      tooltip: '调整列数',
      initialValue: columns,
      onSelected: (value) {
        ref.read(dataProvider.notifier).setColumnsPerRow(value);
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

  /// Windows 端主体内容（网格布局）
  Widget _buildWindowsBody() {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return _buildEmptyState();
    }

    final columns = ref.watch(columnsPerRowProvider);
    return _buildGridView(lists, columns);
  }

  /// 移动端布局（标签页）
  Widget _buildMobileLayout() {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _buildMobileAppBar(),
        body: _buildEmptyState(),
      );
    }

    return DefaultTabController(
      length: lists.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _buildMobileAppBar(),
        body: Column(
          children: [
            // 标签栏
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: lists.map((list) => Tab(text: list.title)).toList(),
              ),
            ),
            // 标签页内容
            Expanded(
              child: TabBarView(
                children: lists.map((list) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: TodoListWidget(listId: list.id),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 移动端 AppBar
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.checklist,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          const Text('TodoMatrix'),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      actions: [
        _buildMobileSyncButton(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '新建列表',
          onPressed: _createNewList,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: _openSettings,
        ),
      ],
    );
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
                ref.read(dataProvider.notifier).moveTodoItemToList(
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
    final settings = ref.watch(localSettingsProvider);
    final isPinned = settings.pinToDesktop;

    return IconButton(
      icon: Transform.rotate(
        angle: isPinned ? 0 : math.pi * 7 / 36, // 未钉住时倾斜 35 度
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
    final settings = ref.watch(localSettingsProvider);
    final isEnabled = settings.edgeHideEnabled;

    return IconButton(
      icon: Icon(
        Icons.vertical_align_top,
        size: 20,
        // 关闭时颜色加深（primary），开启时颜色变浅
        color: isEnabled
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.primary,
      ),
      tooltip: '贴边隐藏',
      onPressed: _toggleEdgeHide,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 切换贴边隐藏状态
  Future<void> _toggleEdgeHide() async {
    final settings = ref.read(localSettingsProvider);
    final newValue = !settings.edgeHideEnabled;
    
    // 更新设置
    ref.read(dataProvider.notifier).updateSettings(
      settings.copyWith(edgeHideEnabled: newValue),
    );
    
    // 应用窗口设置
    await WindowService.instance.setEdgeHide(newValue);
  }

  /// 切换钉在桌面状态
  Future<void> _togglePinToDesktop() async {
    final settings = ref.read(localSettingsProvider);
    final newValue = !settings.pinToDesktop;
    
    // 更新设置
    ref.read(dataProvider.notifier).updateSettings(
      settings.copyWith(pinToDesktop: newValue),
    );
    
    // 应用窗口设置
    await WindowService.instance.setPinToDesktop(newValue, opacity: settings.pinOpacity);
  }

  void _createNewList() {
    ref.read(dataProvider.notifier).createList();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPanel(),
      ),
    );
  }

  /// 构建同步按钮（Windows）
  Widget _buildSyncButton() {
    final syncState = ref.watch(syncProvider);
    final isDiscovering = syncState.status == SyncStatus.discovering;
    final isSyncing = syncState.status == SyncStatus.syncing ||
        syncState.status == SyncStatus.connecting;
    final hasDevices = syncState.devices.isNotEmpty;

    return IconButton(
      icon: AnimatedRotation(
        turns: isSyncing ? 1 : 0,
        duration: Duration(milliseconds: isSyncing ? 1000 : 0),
        child: Icon(
          Icons.sync,
          size: 20,
          color: isDiscovering || isSyncing
              ? Theme.of(context).colorScheme.primary
              : hasDevices
                  ? Colors.green
                  : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      tooltip: _getSyncTooltip(syncState),
      onPressed: () => _handleSyncButtonPressed(syncState),
      visualDensity: VisualDensity.compact,
    );
  }

  /// 构建同步按钮（移动端）
  Widget _buildMobileSyncButton() {
    final syncState = ref.watch(syncProvider);
    final isDiscovering = syncState.status == SyncStatus.discovering;
    final isSyncing = syncState.status == SyncStatus.syncing ||
        syncState.status == SyncStatus.connecting;
    final hasDevices = syncState.devices.isNotEmpty;

    return IconButton(
      icon: Icon(
        Icons.sync,
        color: isDiscovering || isSyncing
            ? Theme.of(context).colorScheme.primary
            : hasDevices
                ? Colors.green
                : null,
      ),
      tooltip: _getSyncTooltip(syncState),
      onPressed: () => _handleSyncButtonPressed(syncState),
    );
  }

  /// 获取同步按钮提示文本
  String _getSyncTooltip(SyncState syncState) {
    switch (syncState.status) {
      case SyncStatus.idle:
        return syncState.devices.isEmpty ? '发现设备' : '点击同步 (${syncState.devices.length} 个设备)';
      case SyncStatus.discovering:
        return '正在搜索设备...';
      case SyncStatus.connecting:
        return '正在连接...';
      case SyncStatus.syncing:
        return '正在同步...';
      case SyncStatus.completed:
        return '同步完成';
      case SyncStatus.failed:
        return '同步失败: ${syncState.message ?? "未知错误"}';
    }
  }

  /// 处理同步按钮点击
  Future<void> _handleSyncButtonPressed(SyncState syncState) async {
    final syncNotifier = ref.read(syncProvider.notifier);
    final settings = ref.read(localSettingsProvider);

    debugPrint('[Sync] 按钮点击，当前状态: ${syncState.status}');

    // 如果正在同步，不做任何操作
    if (syncState.status == SyncStatus.syncing ||
        syncState.status == SyncStatus.connecting) {
      debugPrint('[Sync] 正在同步中，忽略点击');
      return;
    }

    // 如果正在发现设备，停止发现
    if (syncState.status == SyncStatus.discovering) {
      debugPrint('[Sync] 停止设备发现');
      await syncNotifier.stopDiscovery();
      return;
    }

    // 如果有已发现的设备，触发同步
    if (syncState.devices.isNotEmpty) {
      debugPrint('[Sync] 发现 ${syncState.devices.length} 个设备，开始同步');
      // 与第一个设备同步（后续可以改为选择设备）
      await syncNotifier.syncWithDevice(syncState.devices.first);
      return;
    }

    // 否则开始设备发现
    debugPrint('[Sync] 开始设备发现，设备名: ${settings.deviceName}');
    await syncNotifier.initialize(settings.deviceName);
    await syncNotifier.startDiscovery();
  }
}

