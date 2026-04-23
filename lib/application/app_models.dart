import '../core/typedefs.dart';
import '../domain/models/enums.dart';

class HouseholdSummaryVm {
  const HouseholdSummaryVm({
    required this.householdId,
    required this.name,
    required this.activeListCount,
    required this.memberCount,
  });

  final HouseholdId householdId;
  final String name;
  final int activeListCount;
  final int memberCount;
}

class ListVm {
  const ListVm({
    required this.listId,
    required this.name,
    required this.type,
    required this.archived,
    required this.itemCount,
    required this.completedCount,
  });

  final ListId listId;
  final String name;
  final ListType type;
  final bool archived;
  final int itemCount;
  final int completedCount;
}

class ItemVm {
  const ItemVm({
    required this.itemId,
    required this.listId,
    required this.title,
    required this.subtitle,
    required this.checked,
  });

  final ItemId itemId;
  final ListId listId;
  final String title;
  final String? subtitle;
  final bool checked;
}
