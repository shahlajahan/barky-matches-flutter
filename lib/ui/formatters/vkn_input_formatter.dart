// lib/ui/formatters/vkn_input_formatter.dart
import 'package:flutter/services.dart';

class VknInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 10 ? digits.substring(0, 10) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      // pattern: 3-3-3-1 => spaces after 3,6,9
      if (i == 2 || i == 5 || i == 8) {
        if (i != clipped.length - 1) buffer.write(' ');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}