import 'errors.dart';

class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.issues = const [],
  });

  final bool isValid;
  final List<ValidationIssue> issues;

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(List<ValidationIssue> issues) =>
      ValidationResult(isValid: false, issues: issues);
}

class ApplyResult {
  const ApplyResult({
    required this.accepted,
    this.errors = const [],
  });

  final bool accepted;
  final List<DomainError> errors;
}

class ImportResult {
  const ImportResult({
    required this.importedCount,
    required this.duplicateCount,
    this.errors = const [],
  });

  final int importedCount;
  final int duplicateCount;
  final List<DomainError> errors;
}

class InvariantCheckResult {
  const InvariantCheckResult({
    required this.passed,
    this.violations = const [],
  });

  final bool passed;
  final List<String> violations;
}
