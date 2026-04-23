import '../../core/results.dart';
import '../models/enums.dart';
import '../models/operation.dart';
import '../models/state.dart';

class OperationValidationContext {
  const OperationValidationContext({
    required this.state,
  });

  final MaterializedHouseholdState state;
}

class OperationValidator {
  ValidationResult validate(
    CrdtOperation operation,
    OperationValidationContext context,
  ) {
    final issues = <ValidationIssue>[];

    if (operation.opId.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'op_id_empty',
          message: 'Operation id must not be empty.',
        ),
      );
    }

    if (operation.householdId.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'household_id_empty',
          message: 'Household id must not be empty.',
        ),
      );
    }

    if (operation.lamportTs <= 0) {
      issues.add(
        const ValidationIssue(
          code: 'lamport_non_positive',
          message: 'Lamport timestamp must be positive.',
        ),
      );
    }

    switch (operation.opType) {
      case OperationType.householdCreate:
        _requireTrimmedString(operation.payload, 'name', issues);
        break;
      case OperationType.householdRename:
        _requireTrimmedString(operation.payload, 'name', issues);
        break;
      case OperationType.householdDelete:
        break;
      case OperationType.memberAdd:
        _requireTrimmedString(operation.payload, 'memberId', issues);
        _requireTrimmedString(operation.payload, 'displayName', issues);
        break;
      case OperationType.memberRename:
        _requireTrimmedString(operation.payload, 'displayName', issues);
        break;
      case OperationType.memberRemove:
        break;
      case OperationType.listCreate:
        _requireTrimmedString(operation.payload, 'listId', issues);
        _requireTrimmedString(operation.payload, 'name', issues);
        _requireTrimmedString(operation.payload, 'type', issues);
        _requireTrimmedString(operation.payload, 'initialOrderKey', issues);
        break;
      case OperationType.listRename:
        _requireTrimmedString(operation.payload, 'name', issues);
        break;
      case OperationType.listArchiveSet:
        _requireBool(operation.payload, 'archived', issues);
        break;
      case OperationType.listDelete:
        break;
      case OperationType.listMove:
        _requireTrimmedString(operation.payload, 'newOrderKey', issues);
        break;
      case OperationType.itemCreate:
        _requireTrimmedString(operation.payload, 'itemId', issues);
        _requireTrimmedString(operation.payload, 'listId', issues);
        _requireTrimmedString(operation.payload, 'initialOrderKey', issues);
        break;
      case OperationType.itemDelete:
        break;
      case OperationType.itemMove:
        _requireTrimmedString(operation.payload, 'newOrderKey', issues);
        break;
      case OperationType.todoTextSet:
        _requireTrimmedString(operation.payload, 'text', issues);
        break;
      case OperationType.todoNoteSet:
        _allowNullableString(operation.payload, 'note', issues);
        break;
      case OperationType.todoCompletedSet:
        _requireBool(operation.payload, 'completed', issues);
        break;
      case OperationType.shopNameSet:
        _requireTrimmedString(operation.payload, 'name', issues);
        break;
      case OperationType.shopQuantitySet:
        _allowNullableString(operation.payload, 'quantityText', issues);
        break;
      case OperationType.shopNoteSet:
        _allowNullableString(operation.payload, 'note', issues);
        break;
      case OperationType.shopAcquiredSet:
        _requireBool(operation.payload, 'acquired', issues);
        break;
      case OperationType.shopCategorySet:
        _allowNullableString(operation.payload, 'category', issues);
        break;
    }

    return issues.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  void _requireTrimmedString(
    Map<String, Object?> payload,
    String key,
    List<ValidationIssue> issues,
  ) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      issues.add(
        ValidationIssue(
          code: '${key}_invalid',
          message: '$key must be a non-empty string.',
        ),
      );
    }
  }

  void _requireBool(
    Map<String, Object?> payload,
    String key,
    List<ValidationIssue> issues,
  ) {
    final value = payload[key];
    if (value is! bool) {
      issues.add(
        ValidationIssue(
          code: '${key}_invalid',
          message: '$key must be a boolean.',
        ),
      );
    }
  }

  void _allowNullableString(
    Map<String, Object?> payload,
    String key,
    List<ValidationIssue> issues,
  ) {
    final value = payload[key];
    if (value != null && value is! String) {
      issues.add(
        ValidationIssue(
          code: '${key}_invalid',
          message: '$key must be a string or null.',
        ),
      );
    }
  }
}
