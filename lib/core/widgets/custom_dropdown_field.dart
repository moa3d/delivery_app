import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CustomDropdownField extends StatelessWidget {
  final String hint;
  final IconData prefixIcon;
  final List<String> items;
  final String? value;
  final Function(String?) onChanged;

  const CustomDropdownField({
    super.key,
    required this.hint,
    required this.prefixIcon,
    required this.items,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: AppColors.darkCard,
            borderRadius: BorderRadius.all(Radius.circular(8)),
            hint: Row(
              children: [
                Icon(prefixIcon, color: AppColors.textGrey, size: 22),
                const SizedBox(width: 12),
                Text(hint, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
              ],
            ),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey),
            isExpanded: true,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
              );
            }).toList(), onChanged: onChanged,
          ),
        ),
    );
  }
}
