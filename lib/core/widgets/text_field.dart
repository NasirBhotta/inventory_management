import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.decimal = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.suffix,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final bool decimal;
  final bool readOnly;
  final int maxLines;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType:
          keyboardType ??
          (decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : numeric
              ? TextInputType.number
              : null),
      inputFormatters:
          inputFormatters ??
          (decimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffix: suffix,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
