import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CustomLogoContainer extends StatelessWidget {
  final double size;
  final String? imagePath;
  final IconData? icon;
  final Color? backgroundColor;
  final double borderRadius;
  final bool hasShadow;
  final bool isYellow;

  const CustomLogoContainer({
    super.key,
    this.size = 80.0,
    this.imagePath,
    this.backgroundColor = AppColors.primaryOrange,
    this.borderRadius = 15.0,
    this.hasShadow = true,
    this.icon,
    this.isYellow = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: (backgroundColor ?? AppColors.primaryOrange)
                      .withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      padding: EdgeInsets.all(size * 0.2),
      child: imagePath != null
          ? Image.asset(imagePath!, fit: BoxFit.contain)
          : Icon(icon, color: isYellow ? Colors.yellow : Colors.white),
    );
  }
}
