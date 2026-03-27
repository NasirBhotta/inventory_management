abstract class Validators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  static String? positiveInt(String? value) {
    final v = int.tryParse(value ?? '');
    if (v == null || v < 0) return 'Enter a valid number';
    return null;
  }

  static String? nonZeroInt(String? value) {
    final v = int.tryParse(value ?? '');
    if (v == null || v <= 0) return 'Must be greater than 0';
    return null;
  }

  static String? positiveDouble(String? value) {
    final v = double.tryParse(value ?? '');
    if (v == null || v < 0) return 'Enter a valid amount';
    return null;
  }

  static String? nonZeroDouble(String? value) {
    final v = double.tryParse(value ?? '');
    if (v == null || v <= 0) return 'Must be greater than 0';
    return null;
  }

  static String? wholeNumberWhenRequired(
    String? value, {
    required bool allowFraction,
    String message = 'Only whole numbers are allowed for this product',
  }) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final number = double.tryParse(raw);
    if (number == null) return 'Enter a valid number';
    if (!allowFraction && number != number.roundToDouble()) {
      return message;
    }
    return null;
  }
}
