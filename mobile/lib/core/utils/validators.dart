class Validators {
  Validators._();

  static String? required(String? value, [String message = 'This field is required']) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value, [int min = 6]) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < min) return 'Password must be at least $min characters';
    return null;
  }

  static String? positiveNumber(String? value, [String message = 'Enter a valid number']) {
    if (value == null || value.trim().isEmpty) return message;
    final v = num.tryParse(value.trim());
    if (v == null || v < 0) return message;
    return null;
  }
}
