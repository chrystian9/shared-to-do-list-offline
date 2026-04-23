enum ErrorCategory {
  validation,
  invariant,
  storage,
  transport,
  protocol,
  compatibility,
  authorization,
  corruption,
}

class DomainError {
  const DomainError({
    required this.category,
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final ErrorCategory category;
  final String code;
  final String message;
  final bool retryable;
}
