import 'package:flutter/gestures.dart';
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
  bool _isHoveringHeader = false; // 鼠标是否悬停在标题区

  @override
  void initState() {
    super.initState();
    // 监听焦点变化
    _addItemFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // 输入框失去焦点时，清空内容并切换回标题显示
    if (!_addItemFocusNode.hasFocus) {
      if (_addItemController.text.trim().isEmpty) {
        _addItemController.clear();
      }
      // 失去焦点时强制刷新，切换回标题显示
      setState(() {});
    }
  }

  @override
  void dispose() {
    _addItemFocusNode.removeListener(_onFocusChange);
    _addItemController.dispose();
    _addItemFocusNode.dispose();
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
          Expanded(child: _buildItemsList(list)),
        ],
      ),
    );
  }

  Widget _buildHeader(TodoList list) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 列表装饰竖线（类似乐谱起始符）
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          // 标题/输入框区域（仅此区域监听鼠标悬停）
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHoveringHeader = true),
              onExit: (_) => setState(() => _isHoveringHeader = false),
              child: _buildTitleOrInput(list),
            ),
          ),
          // 操作按钮
          _buildHeaderActions(list),
        ],
      ),
    );
  }

  /// 构建标题或输入框
  /// 鼠标悬停在标题区或输入框有焦点时显示输入框，否则显示标题
  Widget _buildTitleOrInput(TodoList list) {
    // 只有悬停在标题区或输入框有焦点时才显示输入框
    final showInput = _isHoveringHeader || _addItemFocusNode.hasFocus;
    
    if (showInput) {
      return _buildAddItemInput(list);
    } else {
      return Text(
        list.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  /// 构建添加待办项的输入框（位于标题栏）
  Widget _buildAddItemInput(TodoList list) {
    return TextField(
      controller: _addItemController,
      focusNode: _addItemFocusNode,
      decoration: InputDecoration(
        hintText: '输入新待办...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
          fontWeight: FontWeight.normal,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // 弱化边框
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
      style: Theme.of(context).textTheme.titleMedium,
      onSubmitted: (_) => _addItem(),
    );
  }

  Widget _buildHeaderActions(TodoList list) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 待办项数量（已完成/总数）
        Text(
          '${list.items.where((i) => i.isCompleted).length}/${list.items.length}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(width: 4),
        // 更多操作菜单
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: Theme.of(context).colorScheme.outline,
          ),
          tooltip: '更多',
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              height: 36,
              child: Text('重命名'),
            ),
            const PopupMenuItem(
              value: 'color',
              height: 36,
              child: Text('设置底色'),
            ),
            const PopupMenuDivider(height: 8),
            const PopupMenuItem(
              value: 'delete',
              height: 36,
              child: Text('删除列表', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameDialog(list);
            } else if (value == 'color') {
              _showColorPicker(list);
            } else if (value == 'delete') {
              _confirmDelete(list);
            }
          },
        ),
      ],
    );
  }

  /// 显示重命名对话框
  void _showRenameDialog(TodoList list) {
    final controller = TextEditingController(text: list.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '列表名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(appDataProvider.notifier).updateListTitle(
                    widget.listId,
                    value.trim(),
                  );
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(appDataProvider.notifier).updateListTitle(
                      widget.listId,
                      newTitle,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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

    // 排序：新添加的在上方（sortOrder 大的在前）
    final sortedItems = [...list.items]
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      itemCount: sortedItems.length,
      onReorder: (oldIndex, newIndex) {
        // 由于排序反转，需要调整索引
        final actualOldIndex = list.items.length - 1 - oldIndex;
        var actualNewIndex = list.items.length - 1 - newIndex;
        if (newIndex > oldIndex) actualNewIndex++;
        ref.read(appDataProvider.notifier).moveTodoItemInList(
              widget.listId,
              actualOldIndex,
              actualNewIndex,
            );
      },
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        // 使用 _MouseAwareDragWrapper 根据设备类型决定拖拽行为
        return _MouseAwareDragWrapper(
          key: ValueKey(item.id),
          index: index,
          child: TodoItemWidget(
            listId: widget.listId,
            item: item,
            index: index,
          ),
        );
      },
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


/// 根据输入设备类型决定拖拽行为的包装器
/// 鼠标设备：整个项可拖拽排序
/// 触摸/笔触设备：由子组件内部的拖拽手柄处理
class _MouseAwareDragWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _MouseAwareDragWrapper({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<_MouseAwareDragWrapper> createState() => _MouseAwareDragWrapperState();
}

class _MouseAwareDragWrapperState extends State<_MouseAwareDragWrapper> {
  bool _isMouseDevice = true;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _isMouseDevice = event.kind == PointerDeviceKind.mouse;
        });
      },
      child: _isMouseDevice
          ? ReorderableDragStartListener(
              index: widget.index,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
