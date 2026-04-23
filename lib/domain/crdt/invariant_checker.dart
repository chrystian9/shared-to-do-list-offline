import '../../core/results.dart';
import '../models/state.dart';

class InvariantChecker {
  InvariantCheckResult check(MaterializedHouseholdState state) {
    final violations = <String>[];

    for (final listId in state.deletedListIds) {
      final list = state.lists[listId];
      if (list == null || !list.deleted) {
        violations.add('Deleted list tombstone missing for $listId');
      }
    }

    for (final itemId in state.deletedItemIds) {
      final item = state.items[itemId];
      if (item == null || !item.deleted) {
        violations.add('Deleted item tombstone missing for $itemId');
      }
    }

    for (final item in state.items.values) {
      final parent = state.lists[item.listId];
      if (parent == null) {
        violations.add('Item ${item.itemId} references missing parent list.');
      }
    }

    return InvariantCheckResult(
      passed: violations.isEmpty,
      violations: violations,
    );
  }
}
