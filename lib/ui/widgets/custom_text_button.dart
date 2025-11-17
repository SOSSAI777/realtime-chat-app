import 'package:flutter/material.dart';

class CustomTextButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback buttonAction;

  const CustomTextButton({
    super.key,
    required this.buttonText,
    required this.buttonAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: buttonAction,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[700], // Cor mais suave
      ),
      child: Text(
        buttonText,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}