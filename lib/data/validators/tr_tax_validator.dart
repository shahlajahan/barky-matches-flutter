// lib/data/validators/tr_tax_validator.dart

class TrTaxValidator {
  /// Turkish VKN (Vergi Kimlik Numarası) checksum validation
  /// - Must be 10 digits
  static bool isValidVkn(String input) {
    final v = input.replaceAll(RegExp(r'\D'), '');
    if (v.length != 10) return false;

    final digits = v.split('').map(int.parse).toList();
    final last = digits[9];

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final d = digits[i];

      // (d + (9 - i)) % 10
      int c = (d + (9 - i)) % 10;

      // c * 2^(9 - i) mod 9
      // pow2 = 2^(9-i) mod 9 (we can compute directly)
      int pow2 = 1;
      for (int k = 0; k < (9 - i); k++) {
        pow2 = (pow2 * 2) % 9;
      }

      c = (c * pow2) % 9;

      // if c == 0 and d != 0 -> 9
      if (c == 0 && d != 0) c = 9;

      sum += c;
    }

    final check = (10 - (sum % 10)) % 10;
    return check == last;
  }
}