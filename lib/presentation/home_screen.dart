import 'package:flutter/material.dart';

import '../application/app_models.dart';
import '../application/app_service.dart';
import '../domain/models/enums.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.service,
  });

  final AppService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final selectedHouseholdId = service.selectedHouseholdId;
        final lists = selectedHouseholdId == null
            ? const <ListVm>[]
            : service.visibleLists(selectedHouseholdId);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              selectedHouseholdId == null
                  ? 'Shared Lists Offline'
                  : service.householdState(selectedHouseholdId)?.household?.name.value ??
                      'Shared Lists Offline',
            ),
            actions: [
              IconButton(
                tooltip: 'Import',
                onPressed: () => _showImportDialog(context),
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: 'Export',
                onPressed: selectedHouseholdId == null
                    ? null
                    : () => _showExportDialog(context, selectedHouseholdId),
                icon: const Icon(Icons.upload),
              ),
              IconButton(
                tooltip: 'Rename household',
                onPressed: selectedHouseholdId == null
                    ? null
                    : () => _showRenameHouseholdDialog(context, selectedHouseholdId),
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
          body: selectedHouseholdId == null
              ? _EmptyState(
                  onCreate: () => _showCreateHouseholdDialog(context),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _HouseholdPane(
                        service: service,
                        onCreateHousehold: () => _showCreateHouseholdDialog(context),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _ListsPane(
                        householdId: selectedHouseholdId,
                        lists: lists,
                        service: service,
                      ),
                    ),
                  ],
                ),
          drawer: selectedHouseholdId == null
              ? null
              : Drawer(
                  child: _HouseholdPane(
                    service: service,
                    onCreateHousehold: () => _showCreateHouseholdDialog(context),
                  ),
                ),
          floatingActionButton: selectedHouseholdId == null
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateHouseholdDialog(context),
                  label: const Text('New household'),
                  icon: const Icon(Icons.group_add),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _showCreateListDialog(context, selectedHouseholdId),
                  label: const Text('New list'),
                  icon: const Icon(Icons.playlist_add),
                ),
        );
      },
    );
  }

  Future<void> _showCreateHouseholdDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create household'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Household name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await service.createHousehold(controller.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameHouseholdDialog(
    BuildContext context,
    String householdId,
  ) async {
    final currentName =
        service.householdState(householdId)?.household?.name.value ?? '';
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename household'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Household name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await service.renameHousehold(
                  householdId: householdId,
                  name: controller.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateListDialog(
    BuildContext context,
    String householdId,
  ) async {
    final controller = TextEditingController();
    var selectedType = ListType.todo;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create list'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'List name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ListType>(
                    segments: const [
                      ButtonSegment<ListType>(
                        value: ListType.todo,
                        label: Text('To-do'),
                      ),
                      ButtonSegment<ListType>(
                        value: ListType.shopping,
                        label: Text('Shopping'),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (selection) {
                      setState(() => selectedType = selection.first);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await service.createList(
                      householdId: householdId,
                      name: controller.text,
                      type: selectedType,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showExportDialog(BuildContext context, String householdId) async {
    final payload = await service.exportHousehold(householdId);
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export payload'),
          content: SizedBox(
            width: 640,
            child: SelectableText(payload),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import payload'),
          content: SizedBox(
            width: 640,
            child: TextField(
              controller: controller,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText: 'Paste exported payload here',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await service.importHousehold(controller.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }
}

class _HouseholdPane extends StatelessWidget {
  const _HouseholdPane({
    required this.service,
    required this.onCreateHousehold,
  });

  final AppService service;
  final VoidCallback onCreateHousehold;

  @override
  Widget build(BuildContext context) {
    final households = service.households;
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            title: const Text('Households'),
            subtitle: Text(service.memberName),
            trailing: IconButton(
              onPressed: onCreateHousehold,
              icon: const Icon(Icons.add),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: households.length,
              itemBuilder: (context, index) {
                final household = households[index];
                final selected = household.householdId == service.selectedHouseholdId;
                return ListTile(
                  selected: selected,
                  title: Text(household.name),
                  subtitle: Text(
                    '${household.activeListCount} lists | ${household.memberCount} members',
                  ),
                  onTap: () {
                    service.selectHousehold(household.householdId);
                    Navigator.of(context).maybePop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListsPane extends StatelessWidget {
  const _ListsPane({
    required this.householdId,
    required this.lists,
    required this.service,
  });

  final String householdId;
  final List<ListVm> lists;
  final AppService service;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _showAddListDialog(context),
          icon: const Icon(Icons.playlist_add),
          label: const Text('Create your first list'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final list = lists[index];
        return Card(
          child: ExpansionTile(
            title: Text(list.name),
            subtitle: Text(
              '${list.type == ListType.todo ? 'To-do' : 'Shopping'} | ${list.completedCount}/${list.itemCount}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'rename':
                    await _showRenameListDialog(context, list);
                    break;
                  case 'archive':
                    await service.setListArchived(
                      householdId: householdId,
                      listId: list.listId,
                      archived: !list.archived,
                    );
                    break;
                  case 'delete':
                    await service.deleteList(
                      householdId: householdId,
                      listId: list.listId,
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(list.archived ? 'Unarchive' : 'Archive'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            children: [
              ...service.visibleItems(householdId, list.listId).map(
                    (item) => CheckboxListTile(
                      value: item.checked,
                      title: Text(item.title),
                      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) async {
                        await service.setItemChecked(
                          householdId: householdId,
                          itemId: item.itemId,
                          checked: value ?? false,
                        );
                      },
                      secondary: PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await _showEditItemDialog(context, list, item);
                              break;
                            case 'delete':
                              await service.deleteItem(
                                householdId: householdId,
                                itemId: item.itemId,
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddItemDialog(context, list),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddListDialog(BuildContext context) {
    return HomeScreen(service: service)._showCreateListDialog(context, householdId);
  }

  Future<void> _showRenameListDialog(BuildContext context, ListVm list) async {
    final controller = TextEditingController(text: list.name);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename list'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'List name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await service.renameList(
                  householdId: householdId,
                  listId: list.listId,
                  name: controller.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddItemDialog(BuildContext context, ListVm list) async {
    final titleController = TextEditingController();
    final secondaryController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add ${list.type == ListType.todo ? 'task' : 'shopping item'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: list.type == ListType.todo ? 'Task' : 'Item',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondaryController,
                decoration: InputDecoration(
                  labelText: list.type == ListType.todo ? 'Note' : 'Quantity',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (list.type == ListType.todo) {
                  await service.addTodoItem(
                    householdId: householdId,
                    listId: list.listId,
                    text: titleController.text,
                    note: secondaryController.text.isEmpty
                        ? null
                        : secondaryController.text,
                  );
                } else {
                  await service.addShoppingItem(
                    householdId: householdId,
                    listId: list.listId,
                    name: titleController.text,
                    quantityText: secondaryController.text.isEmpty
                        ? null
                        : secondaryController.text,
                  );
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    ListVm list,
    ItemVm item,
  ) async {
    final titleController = TextEditingController(text: item.title);
    final secondaryController = TextEditingController(text: item.subtitle ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: list.type == ListType.todo ? 'Task' : 'Item',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondaryController,
                decoration: InputDecoration(
                  labelText: list.type == ListType.todo ? 'Note' : 'Quantity',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await service.renameItem(
                  householdId: householdId,
                  itemId: item.itemId,
                  value: titleController.text,
                );
                await service.updateItemSecondaryText(
                  householdId: householdId,
                  itemId: item.itemId,
                  value: secondaryController.text.isEmpty
                      ? null
                      : secondaryController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onCreate,
  });

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Create a household to start managing shared to-do and shopping lists offline.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.group_add),
              label: const Text('Create household'),
            ),
          ],
        ),
      ),
    );
  }
}
