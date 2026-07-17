import 'package:flutter/material.dart';

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.textInputAction,
    required this.autofillHints,
    required this.validator,
    this.focusNode,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Smooth, premium background colors for text fields
    final fillColor = isDark 
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) 
        : const Color(0xFFF3F4F6);
    
    final labelColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.7);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      obscuringCharacter: '•',
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      keyboardType: label.startsWith('Employee')
          ? TextInputType.text
          : TextInputType.visiblePassword,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: theme.colorScheme.primary,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: labelColor, size: 20),
        suffixIcon: suffixIcon,
        suffixIconColor: labelColor,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _border(theme.colorScheme.outlineVariant.withOpacity(0.3)),
        enabledBorder: _border(theme.colorScheme.outlineVariant.withOpacity(0.3)),
        focusedBorder: _border(theme.colorScheme.primary, width: 1.8),
        errorBorder: _border(theme.colorScheme.error.withOpacity(0.8)),
        focusedErrorBorder: _border(theme.colorScheme.error, width: 1.8),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
