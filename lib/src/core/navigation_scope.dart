import 'package:flutter/widgets.dart';

class ShellNavigationScope extends InheritedWidget {
  const ShellNavigationScope({
    super.key,
    required this.idIndex,
    required this.onNavigate,
    required super.child,
  });

  final Map<String, int> idIndex;
  final void Function(String id) onNavigate;

  static ShellNavigationScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellNavigationScope>();
  }

  @override
  bool updateShouldNotify(ShellNavigationScope oldWidget) => idIndex != oldWidget.idIndex;
}
