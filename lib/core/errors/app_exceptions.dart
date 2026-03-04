class AppException implements Exception {
  const AppException(this.message, [this.details]);
  final String message;
  final Object? details;

  @override
  String toString() =>
      details != null ? '$message\nDetails: $details' : message;
}

class InsufficientStockException extends AppException {
  const InsufficientStockException(String productName)
    : super('Insufficient stock for "$productName"');
}

class NegativeStockException extends AppException {
  const NegativeStockException()
    : super('Operation would result in negative stock');
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.details]);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
