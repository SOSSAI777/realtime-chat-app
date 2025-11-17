import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_button.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmationController =
      TextEditingController();
  final TextEditingController fullNameController = TextEditingController();

  void _showSnack(BuildContext ctx, String text, {bool err = false}) {
    final snack = SnackBar(
        content: Text(text), backgroundColor: err ? Colors.red : Colors.green);
    ScaffoldMessenger.of(ctx).showSnackBar(snack);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width:
                        constraints.maxWidth > 768 ? 768 : constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logos/talkONlogo.png', height: 200),
                        const SizedBox(height: 32),
                        SizedBox(
                            width: double.infinity,
                            child: Text('Registro',
                                style: TextStyle(
                                  // Texto modernizado
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ))),
                        const SizedBox(height: 24),
                        CustomInput(
                            hint: 'Digite seu email',
                            label: 'Email',
                            controller: emailController),
                        const SizedBox(height: 16),
                        CustomInput(
                            hint: 'Digite seu nome completo',
                            label: 'Nome',
                            controller: fullNameController),
                        const SizedBox(height: 16),
                        CustomInput(
                            hint: 'Digite sua senha',
                            label: 'Senha',
                            controller: passwordController,
                            obscure: true),
                        const SizedBox(height: 16),
                        CustomInput(
                            hint: 'Confirme sua senha',
                            label: 'Confirmação da senha',
                            controller: passwordConfirmationController,
                            obscure: true),
                        const SizedBox(height: 24),
                        CustomButton(
                          buttonText: 'Registrar',
                          backgroundColor: const Color(0xFF424242),
                          buttonAction: () async {
                            if (emailController.text.isEmpty) {
                              _showSnack(context, 'O email não pode ser vazio',
                                  err: true);
                              return;
                            }
                            if (fullNameController.text.isEmpty) {
                              _showSnack(context, 'O nome não pode ser vazio',
                                  err: true);
                              return;
                            }
                            if (passwordController.text.isEmpty) {
                              _showSnack(context, 'A senha não pode ser vazia',
                                  err: true);
                              return;
                            }
                            if (passwordController.text !=
                                passwordConfirmationController.text) {
                              _showSnack(context, 'As senhas não coincidem',
                                  err: true);
                              return;
                            }

                            try {
                              final res = await auth.signUp(
                                  emailController.text.trim(),
                                  passwordController.text);

                              if (!context.mounted) return;

                              if (res.user != null) {
                                _showSnack(context,
                                    'Registrado! Verifique seu email para confirmar a conta.');
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              } else {
                                _showSnack(context, 'Erro no registro',
                                    err: true);
                              }
                            } catch (e) {
                              _showSnack(context, e.toString(), err: true);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextButton(
                          buttonText: 'Já tem uma conta? Faça login',
                          buttonAction: () =>
                              Navigator.pushNamed(context, '/login'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
