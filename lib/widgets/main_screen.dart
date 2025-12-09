import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';
import '../providers/layout_provider.dart';
import 'settings_panel.dart';
import 'todo_list_widget.dart';

/// 主界面
/// 显示所有待办列表的网格布局，支持拖拽排序
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoMatrix'),
        actions: [
          // 列数调整
          _buildColumnsSelector(),
          const SizedBox(width: 8),
          // 添加列表按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建列表',
            onPressed: _createNewList,
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
      icon: const Icon(Icons.grid_view),
      tooltip: '调整列数',
      initialValue: columns,
      onSelected: (value) {
        ref.read(layoutControllerProvider).setColumnsPerRow(value);
      },
      itemBuilder: (context) => List.generate(
        5,
        (index) => PopupMenuItem(
          value: index + 1,
          child: Text('${index + 1} 列'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredColumns = ref.watch(columnsPerRowProvider);
        final columns = calculateResponsiveColumns(
          constraints.maxWidth,
          preferredColumns: preferredColumns,
        );

        return _buildReorderableGrid(lists, columns);
      },
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
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有待办列表',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _createNewList,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个列表'),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableGrid(List lists, int columns) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: lists.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          ref.read(appDataProvider.notifier).moveList(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final list = lists[index];
          return ReorderableDragStartListener(
            key: ValueKey(list.id),
            index: index,
            child: _buildListCard(list, index, columns),
          );
        },
      ),
    );
  }

  Widget _buildListCard(dynamic list, int index, int columns) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TodoListWidget(listId: list.id),
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
