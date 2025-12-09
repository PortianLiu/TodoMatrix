/// 托盘菜单配置
/// 
/// 托盘菜单的实际实现在 [WindowService] 中
/// 此文件提供菜单项的配置和本地化支持

/// 托盘菜单项类型
enum TrayMenuItemType {
  showWindow,
  separator,
  exit,
}

/// 托盘菜单项配置
class TrayMenuItem {
  final TrayMenuItemType type;
  final String label;
  final void Function()? onClicked;

  const TrayMenuItem({
    required this.type,
    required this.label,
    this.onClicked,
  });

  /// 显示窗口菜单项
  static TrayMenuItem showWindow({void Function()? onClicked}) {
    return TrayMenuItem(
      type: TrayMenuItemType.showWindow,
      label: '显示窗口',
      onClicked: onClicked,
    );
  }

  /// 分隔符
  static const TrayMenuItem separator = TrayMenuItem(
    type: TrayMenuItemType.separator,
    label: '',
  );

  /// 退出菜单项
  static TrayMenuItem exit({void Function()? onClicked}) {
    return TrayMenuItem(
      type: TrayMenuItemType.exit,
      label: '退出',
      onClicked: onClicked,
    );
  }
}

/// 默认托盘菜单配置
List<TrayMenuItem> getDefaultTrayMenuItems({
  void Function()? onShowWindow,
  void Function()? onExit,
}) {
  return [
    TrayMenuItem.showWindow(onClicked: onShowWindow),
    TrayMenuItem.separator,
    TrayMenuItem.exit(onClicked: onExit),
  ];
}
