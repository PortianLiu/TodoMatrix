import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/todo_provider.dart';

/// 待办项组件
/// 显示单个待办项，支持完成状态切换、描述编辑、优先级显示等
class TodoItemWidget extends ConsumerStatefulWidget {
  final String listId;
  final TodoItem item;
  /// 列表内排序的索引（用于 ReorderableDragStartListener）
  final int index;

  const TodoItemWidget({
    super.key,
    required this.listId,
    required this.item,
    required this.index,
  });

  @override
  ConsumerState<TodoItemWidget> createState() => _TodoItemWidgetState();
}

class _TodoItemWidgetState extends ConsumerState<TodoItemWidget> {
  bool _isEditing = false;
  bool _isMouseDevice = true; // 当前是否是鼠标设备
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
    // 使用 Listener 检测输入设备类型
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _isMouseDevice = event.kind == PointerDeviceKind.mouse;
        });
      },
      child: _buildContent(),
    );
  }


  Widget _buildContent() {
    // 跨列表拖拽（长按触发）
    return LongPressDraggable<Map<String, String>>(
      data: {
        'sourceListId': widget.listId,
        'itemId': widget.item.id,
      },
      feedback: _buildDragFeedback(),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildItemContent(),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showContextMenuAt(details.globalPosition),
        onLongPress: () {
          // 触摸/笔触场景下长按显示菜单
          if (!_isMouseDevice) {
            _showContextMenuAtCenter();
          }
        },
        child: _buildItemContent(),
      ),
    );
  }

  Widget _buildDragFeedback() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.item.description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildItemContent() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        contentPadding: const EdgeInsets.only(left: 8, right: 6),
        horizontalTitleGap: 6,
        leading: _buildDragHandle(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: _toggleCompleted,
      ),
    );
  }

  /// 构建拖拽手柄
  /// 鼠标设备：整个项可拖拽（手柄只是视觉提示）
  /// 触摸/笔触：只有手柄区域可拖拽
  Widget _buildDragHandle() {
    final handle = Icon(
      Icons.drag_indicator,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
      size: 16,
    );

    // 触摸/笔触设备：只有手柄区域响应拖拽
    if (!_isMouseDevice) {
      return ReorderableDragStartListener(
        index: widget.index,
        child: handle,
      );
    }

    // 鼠标设备：手柄只是视觉提示，整个项都可拖拽
    return handle;
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
        // 删除按钮
        IconButton(
          icon: Icon(
            Icons.close,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          tooltip: '删除',
          onPressed: _deleteItem,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    }
  }

  /// 在指定位置显示上下文菜单
  void _showContextMenuAt(Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: _buildMenuItems(),
    ).then((value) {
      if (value != null) _handleMenuAction(value);
    });
  }

  /// 在组件中心显示上下文菜单（用于长按触发）
  void _showContextMenuAtCenter() {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final position = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    _showContextMenuAt(position);
  }

  /// 构建菜单项（紧凑样式，无删除项）
  List<PopupMenuEntry<String>> _buildMenuItems() {
    return [
      const PopupMenuItem<String>(
        value: 'edit',
        height: 36,
        child: Text('编辑'),
      ),
      const PopupMenuItem<String>(
        value: 'priority',
        height: 36,
        child: Text('设置优先级'),
      ),
      const PopupMenuItem<String>(
        value: 'dueDate',
        height: 36,
        child: Text('设置截止日期'),
      ),
      const PopupMenuItem<String>(
        value: 'move',
        height: 36,
        child: Text('移动到...'),
      ),
    ];
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
