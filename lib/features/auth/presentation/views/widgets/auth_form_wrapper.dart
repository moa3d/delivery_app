import 'package:flutter/material.dart';

class AuthFormWrapper extends StatelessWidget {
  final List<Widget> children;
  final double verticalSpacing;

  const AuthFormWrapper({
    super.key,
    required this.children,
    this.verticalSpacing = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((widget) {
        // إضافة مسافة تلقائية أسفل كل عنصر إلا العنصر الأخير
        return Padding(
          padding: EdgeInsets.only(bottom: verticalSpacing),
          child: widget,
        );
      }).toList(),
    );
  }
}