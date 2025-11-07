// lib/features/admin/shared/search_field.dart
import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => onChanged(v.trim().toLowerCase()),
    );
  }
}
