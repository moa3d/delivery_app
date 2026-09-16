import 'package:flutter/material.dart';
import 'package:delivery_app/core/constants/app_colors.dart';

/// ويدجت حقل نص مخصص يدعم التنسيق الموحد للتطبيق
class CustomTextField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextDirection? textDirection;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.controller,
    this.onChanged,
    this.textDirection,
    this.keyboardType,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: widget.onChanged,
      controller: widget.controller,
      obscureText: _obscure,
      textDirection: widget.textDirection,
      keyboardType: widget.keyboardType,
      // 3. ربطها بـ TextFormField الأصلي
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.grey.shade300,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
              color: AppColors.primaryOrange.withValues(alpha: 0.5)),
        ),
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
        prefixIcon: Icon(widget.icon, color: AppColors.textGrey, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textGrey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: AppColors.darkCard.withValues(alpha: 0.8),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}