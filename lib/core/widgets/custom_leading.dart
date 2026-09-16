import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomLeading extends StatefulWidget {
  final IconData? icon;
  final Function()? onPressed;

  const CustomLeading({super.key, this.onPressed, this.icon});

  @override
  State<CustomLeading> createState() => _CustomLeadingState();
}

class _CustomLeadingState extends State<CustomLeading> {
  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
      icon: Icon(
        widget.icon ?? Icons.arrow_back,
        color: isDark ? Colors.white : Colors.black87,
        size: 20,
      ),
      // مهم: نستخدم Navigator.maybePop لا Get.back() — لأن PopScope (المستخدَم
      // مثلاً في ActiveOrderPopGuard لحماية تدفّق الطلب النشط) يعترض فقط
      // محاولات الرجوع التي تمرّ عبر maybePop (وهو ما يستخدمه أيضاً زر
      // النظام/سحبة iOS تلقائياً). أما pop()/Get.back() المباشر فيتجاوز
      // PopScope كلياً بغضّ النظر عن canPop — هذا سلوك Flutter موثَّق، لا خطأ.
      onPressed: widget.onPressed ?? () => Navigator.maybePop(context),
    );
  }
}