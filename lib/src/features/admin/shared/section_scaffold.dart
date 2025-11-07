// lib/features/admin/shared/section_scaffold.dart
import 'package:flutter/material.dart';

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.child,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 96),
  });

  final Widget child;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    if (onRefresh == null) return SingleChildScrollView(child: content);
    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: ListView(children: [content]),
    );
  }
}
