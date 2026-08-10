// ignore_for_file: deprecated_member_use, use_null_aware_elements

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Widget? rightWidget;
  final Widget? leftWidget;
  final bool obscureText;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final double? height;
  final void Function(String)? onChanged;
  final Color? hintColor;
  final double? hintSize;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final int? maxLength;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.rightWidget,
    this.leftWidget,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.height = 60,
    this.hintColor,
    this.hintSize,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.maxLength,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          rightWidget ?? const SizedBox.shrink(),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              minLines: maxLines,
              maxLength: maxLength,
              readOnly: readOnly,
              onTap: onTap,

              validator: validator,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: maxLines,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: hintColor ?? AppColors.textSecondary,
                  fontSize: hintSize ?? 15,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: leftWidget != null ? 0 : 2,
                ),
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          if (leftWidget != null) leftWidget!,
        ],
      ),
    );
  }
}
