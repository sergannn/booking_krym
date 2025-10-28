import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/excursion.dart';
import '../../../data/models/user_summary.dart';
import '../../../data/providers.dart';

class AssignStaffSheet extends ConsumerStatefulWidget {
  const AssignStaffSheet({
    super.key,
    required this.excursion,
  });

  final Excursion excursion;

  @override
  ConsumerState<AssignStaffSheet> createState() => _AssignStaffSheetState();
}

class _AssignStaffSheetState extends ConsumerState<AssignStaffSheet> {
  final Set<int> _selectedDrivers = {};
  final Set<int> _selectedGuides = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final staff in widget.excursion.assignedStaff) {
      if (staff.roleInExcursion == 'driver') {
        _selectedDrivers.add(staff.id);
      } else if (staff.roleInExcursion == 'guide') {
        _selectedGuides.add(staff.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersFutureProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Назначить персонал — ${widget.excursion.title}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Ошибка загрузки пользователей: $error'),
                    ),
                  ),
                  data: (users) {
                    final drivers = users
                        .where((user) =>
                            user.roleName.toLowerCase().contains('водител'))
                        .toList();
                    final guides = users
                        .where((user) =>
                            user.roleName.toLowerCase().contains('экскурсов'))
                        .toList();

                    return ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _StaffSection(
                          title: 'Водители',
                          users: drivers,
                          selected: _selectedDrivers,
                          onChanged: (update) => setState(() {
                            update(_selectedDrivers);
                          }),
                        ),
                        const SizedBox(height: 24),
                        _StaffSection(
                          title: 'Экскурсоводы',
                          users: guides,
                          selected: _selectedGuides,
                          onChanged: (update) => setState(() {
                            update(_selectedGuides);
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(assignmentsRepositoryProvider);
      await repository.assignStaff(
        excursionId: widget.excursion.id,
        assignments: [
          ..._selectedDrivers.map(
            (id) => {'user_id': id, 'role_in_excursion': 'driver'},
          ),
          ..._selectedGuides.map(
            (id) => {'user_id': id, 'role_in_excursion': 'guide'},
          ),
        ],
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Назначения обновлены')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _StaffSection extends StatelessWidget {
  const _StaffSection({
    required this.title,
    required this.users,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<UserSummary> users;
  final Set<int> selected;
  final void Function(void Function(Set<int>)) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Сотрудников с такой ролью пока нет'),
          )
        else
          Wrap(
            spacing: 8,
            children: users
                .map(
                  (user) => FilterChip(
                    label: Text(user.name),
                    selected: selected.contains(user.id),
                    onSelected: (value) => onChanged((set) {
                      if (value) {
                        set.add(user.id);
                      } else {
                        set.remove(user.id);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
