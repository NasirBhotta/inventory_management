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
}
