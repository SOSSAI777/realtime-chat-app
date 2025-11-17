import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String buttonText;
  final Color backgroundColor;
  final VoidCallback buttonAction;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.buttonText,
    required this.backgroundColor,
    required this.buttonAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52, // Um pouco mais alto para um toque moderno
      child: ElevatedButton(
        onPressed: isLoading ? null : buttonAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withAlpha((255 * 0.6).round()),
          foregroundColor: Colors.white, // Garante que o texto/ícone seja branco
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Cantos arredondados
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(buttonText),
      ),
    );
  }
}