import 'package:flutter/material.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;

  const HomeSearchBar({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            hintText: 'بحث...',
            height: 48,
            rightWidget: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            ),
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tune, color: Colors.white),
        ),
      ],
    );
  }
}
