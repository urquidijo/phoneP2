// lib/features/admin/users/users_section.dart
import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import '../shared/empty_state.dart';

class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});
  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<User> _users = const [];
  List<Role> _roles = const [];
  final Map<int, int?> _draftRoles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_api.fetchUsers(), _api.fetchRoles()]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<User>;
        _roles = results[1] as List<Role>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los usuarios: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveRole(User user) async {
    final selection = _draftRoles[user.id];
    try {
      await _api.adminUpdateUser(user.id, AdminUserPayload(rol: selection));
      _draftRoles.remove(user.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pudimos actualizarlo: $e')));
    }
  }

  Future<void> _delete(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar definitivamente a ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.adminDeleteUser(user.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pudimos eliminarlo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const LoadingView(message: 'Sincronizando usuarios...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_users.isEmpty)
      return const EmptyState(message: 'No hay usuarios registrados.');

    return SectionScaffold(
      child: Column(
        children: _users.map((user) {
          final draft = _draftRoles[user.id] ?? user.rol;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '#${user.id}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: draft,
                    decoration: const InputDecoration(
                      labelText: 'Rol asignado',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin rol'),
                      ),
                      ..._roles.map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _draftRoles[user.id] = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _delete(user),
                          child: const Text('Eliminar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _saveRole(user),
                          child: const Text('Guardar rol'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
