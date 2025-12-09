import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/todo_provider.dart';
import 'todo_item_widget.dart';

/// 待办列表组件
/// 显示单个列表，支持添加/编辑/删除待办项
class TodoListWidget extends ConsumerStatefulWidget {
  final String listId;
  final VoidCallback? onDelete;

  const TodoListWidget({
    super.key,
    required this.listId,
    this.onDelete,
  });

  @override
  ConsumerState<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends ConsumerState<TodoListWidget> {
  final _addItemController = TextEditingController();
  final _addItemFocusNode = FocusNode();
  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(todoListProvider(widget.listId));

    if (list == null) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(list),
          const Divider(height: 1),
          _buildItemsList(list),
          _buildAddItemField(list),
        ],
      ),
    );
  }

  Widget _buildHeader(TodoList list) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 拖拽手柄
          Icon(
            Icons.drag_indicator,
            color: Theme.of(context).colorScheme.outline,
            size: 20,
          ),
          const SizedBox(width: 8),
          // 标题
          Expanded(
            child: _isEditingTitle
                ? _buildTitleEditor(list)
                : _buildTitleDisplay(list),
          ),
          // 操作按钮
          _buildHeaderActions(list),
        ],
      ),
    );
  }

  Widget _buildTitleDisplay(TodoList list) {
    return GestureDetector(
      onTap: () => _startEditingTitle(list),
      child: Text(
        list.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTitleEditor(TodoList list) {
    return TextField(
      controller: _titleController,
      autofocus: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(),
      ),
      style: Theme.of(context).textTheme.titleMedium,
      onSubmitted: (_) => _saveTitle(),
      onTapOutside: (_) => _saveTitle(),
    );
  }

  void _startEditingTitle(TodoList list) {
    _titleController.text = list.title;
    setState(() => _isEditingTitle = true);
  }

  void _saveTitle() {
    if (_isEditingTitle) {
      final newTitle = _titleController.text.trim();
      if (newTitle.isNotEmpty) {
        ref.read(appDataProvider.notifier).updateListTitle(
              widget.listId,
              newTitle,
            );
      }
      setState(() => _isEditingTitle = false);
    }
  }

  Widget _buildHeaderActions(TodoList list) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 待办项数量
        Text(
          '${list.items.where((i) => !i.isCompleted).length}/${list.items.length}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(width: 4),
        // 删除按钮
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '删除列表',
          onPressed: widget.onDelete,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildItemsList(TodoList list) {
    if (list.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '暂无待办项',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 按 sortOrder 排序
    final sortedItems = [...list.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: sortedItems.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref.read(appDataProvider.notifier).moveTodoItemInList(
              widget.listId,
              oldIndex,
              newIndex,
            );
      },
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        return ReorderableDragStartListener(
          key: ValueKey(item.id),
          index: index,
          child: TodoItemWidget(
            listId: widget.listId,
            item: item,
          ),
        );
      },
    );
  }

  Widget _buildAddItemField(TodoList list) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _addItemController,
        focusNode: _addItemFocusNode,
        decoration: InputDecoration(
          hintText: '添加待办项...',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
          ),
        ),
        onSubmitted: (_) => _addItem(),
      ),
    );
  }

  void _addItem() {
    final description = _addItemController.text.trim();
    if (description.isNotEmpty) {
      ref.read(appDataProvider.notifier).addTodoItem(
            widget.listId,
            description,
          );
      _addItemController.clear();
      _addItemFocusNode.requestFocus();
    }
  }
}
