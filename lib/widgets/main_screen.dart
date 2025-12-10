import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';
import '../providers/layout_provider.dart';
import '../services/window_service.dart';
import 'settings_panel.dart';
import 'todo_list_widget.dart';

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
    // 应用钉在桌面设置
    if (settings.pinToDesktop) {
      await WindowService.instance.setPinToDesktop(true);
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(
          'TodoMatrix',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        actions: [
          _buildColumnsSelector(),
          IconButton(
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimaryContainer),
            tooltip: '新建列表',
            onPressed: _createNewList,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
            tooltip: '设置',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
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
