import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../models/settings.dart';
import '../providers/todo_provider.dart';
import 'todo_item_widget.dart';

/// 从十六进制字符串解析颜色
Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// 待办列表组件
class TodoListWidget extends ConsumerStatefulWidget {
  final String listId;

  const TodoListWidget({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends ConsumerState<TodoListWidget> {
  final _addItemController = TextEditingController();
  final _addItemFocusNode = FocusNode();
  bool _isEditingTitle = false;
  bool _isAddingItem = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    // 监听焦点变化，失去焦点时收起添加框
    _addItemFocusNode.addListener(_onAddItemFocusChange);
  }

  void _onAddItemFocusChange() {
    if (!_addItemFocusNode.hasFocus && _isAddingItem) {
      // 延迟检查，避免点击确认按钮时立即收起
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_addItemFocusNode.hasFocus && mounted && _addItemController.text.trim().isEmpty) {
          setState(() => _isAddingItem = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _addItemFocusNode.removeListener(_onAddItemFocusChange);
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(todoListProvider(widget.listId));
    if (list == null) return const SizedBox.shrink();

    // 获取列表底色
    final bgColor = list.backgroundColor != null
        ? _hexToColor(list.backgroundColor!)
        : Theme.of(context).cardColor;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(list),
          const Divider(height: 1),
          _buildItemsList(list),
          if (_isAddingItem) _buildAddItemField(),
        ],
      ),
    );
  }


  Widget _buildHeader(TodoList list) {
    return Container(
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
        // 添加按钮
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          tooltip: '添加待办项',
          onPressed: _showAddItemField,
          visualDensity: VisualDensity.compact,
        ),
        // 更多操作（设置底色）
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: Theme.of(context).colorScheme.outline,
          ),
          tooltip: '更多',
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'color', child: Text('设置底色')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除列表', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: (value) {
            if (value == 'color') {
              _showColorPicker(list);
            } else if (value == 'delete') {
              _confirmDelete(list);
            }
          },
        ),
      ],
    );
  }

  void _showAddItemField() {
    setState(() => _isAddingItem = true);
    // 延迟聚焦，等待 widget 构建完成
    Future.delayed(const Duration(milliseconds: 100), () {
      _addItemFocusNode.requestFocus();
    });
  }

  void _showColorPicker(TodoList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择底色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ListColors.presetColors.map((colorHex) {
            final color = _hexToColor(colorHex);
            final isSelected = list.backgroundColor == colorHex;
            return GestureDetector(
              onTap: () {
                ref.read(appDataProvider.notifier).updateListColor(
                      widget.listId,
                      colorHex == 'ffffff' ? null : colorHex,
                    );
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(TodoList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除列表'),
        content: Text('确定要删除列表"${list.title}"吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(appDataProvider.notifier).deleteList(widget.listId);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
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

  Widget _buildAddItemField() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _addItemController,
        focusNode: _addItemFocusNode,
        decoration: InputDecoration(
          hintText: '输入待办项内容...',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _addItem,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _addItemController.clear();
                  setState(() => _isAddingItem = false);
                },
              ),
            ],
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
