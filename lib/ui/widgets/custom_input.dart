import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType keyboardType;
  final bool enabled;

  const CustomInput({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Removemos a Coluna e o Text(label) separados
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        // Usamos o label como rótulo flutuante
        labelText: label,
        hintText: hint,
        
        // Estilo moderno
        filled: true,
        fillColor: Colors.grey[100], // Fundo cinza claro
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0), // Cantos arredondados
          borderSide: BorderSide.none, // Sem borda padrão
        ),
        enabledBorder: OutlineInputBorder( // Borda quando não focado
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder( // Borda quando focado
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Color(0xFF424242),
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      ),
    );
  }
}