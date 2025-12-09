import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/todo_provider.dart';

/// 待办项组件
/// 显示单个待办项，支持完成状态切换、描述编辑、优先级显示等
class TodoItemWidget extends ConsumerStatefulWidget {
  final String listId;
  final TodoItem item;

  const TodoItemWidget({
    super.key,
    required this.listId,
    required this.item,
  });

  @override
  ConsumerState<TodoItemWidget> createState() => _TodoItemWidgetState();
}

class _TodoItemWidgetState extends ConsumerState<TodoItemWidget> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.item.description);
  }

  @override
  void didUpdateWidget(TodoItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.description != widget.item.description && !_isEditing) {
      _editController.text = widget.item.description;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: ListTile(
          dense: true,
          leading: _buildLeading(),
          title: _buildTitle(),
          subtitle: _buildSubtitle(),
          trailing: _buildTrailing(),
          onTap: _toggleCompleted,
        ),
      ),
    );
  }

  Widget _buildLeading() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 拖拽手柄
        Icon(
          Icons.drag_indicator,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          size: 16,
        ),
        const SizedBox(width: 4),
        // 完成状态复选框
        Checkbox(
          value: widget.item.isCompleted,
          onChanged: (_) => _toggleCompleted(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildTitle() {
    if (_isEditing) {
      return TextField(
        controller: _editController,
        autofocus: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _saveDescription(),
        onTapOutside: (_) => _saveDescription(),
      );
    }

    return GestureDetector(
      onDoubleTap: () => setState(() => _isEditing = true),
      child: Text(
        widget.item.description,
        style: TextStyle(
          decoration:
              widget.item.isCompleted ? TextDecoration.lineThrough : null,
          color: widget.item.isCompleted
              ? Theme.of(context).colorScheme.outline
              : null,
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final dueDate = widget.item.dueDate;
    if (dueDate == null) return null;

    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !widget.item.isCompleted;
    final isToday = dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;

    String dateText;
    if (isToday) {
      dateText = '今天';
    } else {
      dateText = '${dueDate.month}/${dueDate.day}';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: 12,
          color: isOverdue ? Colors.red : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color:
                isOverdue ? Colors.red : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 优先级指示器
        _buildPriorityIndicator(),
        // 更多操作
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
          tooltip: '更多操作',
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'priority', child: Text('设置优先级')),
            const PopupMenuItem(value: 'dueDate', child: Text('设置截止日期')),
            const PopupMenuItem(value: 'move', child: Text('移动到...')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: _handleMenuAction,
        ),
      ],
    );
  }

  Widget _buildPriorityIndicator() {
    Color color;
    switch (widget.item.priority) {
      case Priority.high:
        color = Colors.red;
        break;
      case Priority.medium:
        color = Colors.orange;
        break;
      case Priority.low:
        color = Colors.green;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  void _toggleCompleted() {
    ref.read(appDataProvider.notifier).toggleTodoCompleted(
          widget.listId,
          widget.item.id,
        );
  }

  void _saveDescription() {
    if (_isEditing) {
      final newDescription = _editController.text.trim();
      if (newDescription.isNotEmpty &&
          newDescription != widget.item.description) {
        ref.read(appDataProvider.notifier).updateTodoDescription(
              widget.listId,
              widget.item.id,
              newDescription,
            );
      }
      setState(() => _isEditing = false);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        setState(() => _isEditing = true);
        break;
      case 'priority':
        _showPriorityDialog();
        break;
      case 'dueDate':
        _showDatePicker();
        break;
      case 'move':
        _showMoveDialog();
        break;
      case 'delete':
        _deleteItem();
        break;
    }
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
        const PopupMenuItem<String>(value: 'priority', child: Text('设置优先级')),
        const PopupMenuItem<String>(value: 'dueDate', child: Text('设置截止日期')),
        const PopupMenuItem<String>(value: 'move', child: Text('移动到...')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value != null) _handleMenuAction(value);
    });
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('设置优先级'),
        children: Priority.values.map((priority) {
          String label;
          Color color;
          switch (priority) {
            case Priority.high:
              label = '高';
              color = Colors.red;
              break;
            case Priority.medium:
              label = '中';
              color = Colors.orange;
              break;
            case Priority.low:
              label = '低';
              color = Colors.green;
              break;
          }
          return SimpleDialogOption(
            onPressed: () {
              ref.read(appDataProvider.notifier).setTodoPriority(
                    widget.listId,
                    widget.item.id,
                    priority,
                  );
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(label),
                if (widget.item.priority == priority)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 16),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.item.dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (date != null) {
      ref.read(appDataProvider.notifier).setTodoDueDate(
            widget.listId,
            widget.item.id,
            date,
          );
    }
  }

  void _showMoveDialog() {
    final lists = ref.read(sortedListsProvider);
    final otherLists = lists.where((l) => l.id != widget.listId).toList();

    if (otherLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有其他列表可以移动到')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动到'),
        children: otherLists.map((list) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(appDataProvider.notifier).moveTodoItemToList(
                    widget.listId,
                    list.id,
                    widget.item.id,
                  );
              Navigator.pop(context);
            },
            child: Text(list.title),
          );
        }).toList(),
      ),
    );
  }

  void _deleteItem() {
    ref.read(appDataProvider.notifier).deleteTodoItem(
          widget.listId,
          widget.item.id,
        );
  }
}
