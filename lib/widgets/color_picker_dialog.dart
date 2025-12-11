import 'package:flutter/material.dart';

/// 从十六进制字符串解析颜色
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// 颜色选择对话框（支持预设颜色和自定义颜色）
class ColorPickerDialog extends StatefulWidget {
  final String title;
  final String currentColor;
  final List<String> presetColors;
  final void Function(String colorHex) onColorSelected;
  final bool isCircle; // 是否使用圆形色块

  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.currentColor,
    required this.presetColors,
    required this.onColorSelected,
    this.isCircle = true,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late TextEditingController _controller;
  String? _errorText;
  Color? _previewColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentColor);
    _previewColor = hexToColor(widget.currentColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  /// 验证并解析颜色
  bool _validateAndParseColor(String text) {
    final hex = text.replaceAll('#', '').trim();
    if (hex.length != 6) {
      setState(() {
        _errorText = '请输入6位十六进制颜色';
        _previewColor = null;
      });
      return false;
    }
    try {
      final color = hexToColor(hex);
      setState(() {
        _errorText = null;
        _previewColor = color;
      });
      return true;
    } catch (e) {
      setState(() {
        _errorText = '无效的颜色格式';
        _previewColor = null;
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预设颜色
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.presetColors.map((colorHex) {
                final color = hexToColor(colorHex);
                final isSelected = widget.currentColor == colorHex;
                return GestureDetector(
                  onTap: () {
                    widget.onColorSelected(colorHex);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: widget.isCircle ? 40 : 36,
                    height: widget.isCircle ? 40 : 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: widget.isCircle ? null : BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            color: _isLightColor(color) ? Colors.black54 : Colors.white,
                            size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 3),
            // 自定义颜色输入
            Text('自定义颜色', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 颜色预览
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _previewColor ?? Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _previewColor == null
                      ? const Icon(Icons.close, color: Colors.grey, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                // 输入框
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      prefixText: '#',
                      hintText: 'RRGGBB',
                      errorText: _errorText,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      counterText: '', // 隐藏字符计数器
                    ),
                    maxLength: 6,
                    onChanged: _validateAndParseColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _previewColor != null
              ? () {
                  final hex = _controller.text.replaceAll('#', '').trim();
                  widget.onColorSelected(hex);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }

  /// 判断颜色是否为浅色
  bool _isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }
}
