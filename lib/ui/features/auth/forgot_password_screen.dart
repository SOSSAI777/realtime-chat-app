import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;

  void _showSnack(BuildContext ctx, String text, {bool err = false}) {
    final snack = SnackBar(
        content: Text(text),
        backgroundColor: err ? Colors.red : Colors.green);
    ScaffoldMessenger.of(ctx).showSnackBar(snack);
  }

  Future<void> _sendResetLink() async {
    if (emailController.text.isEmpty) {
      _showSnack(context, 'Por favor, digite seu email', err: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.sendPasswordResetEmail(emailController.text.trim());
      if (!context.mounted) return;

      _showSnack(context, 'Link enviado! Verifique sua caixa de entrada.');
      //  Voltar para o login após o sucesso
      if (mounted) {
         Navigator.pop(context);
      }
     
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Erro ao enviar email: $e', err: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar para o usuário poder voltar
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black, // Cor dos ícones e texto
      ),
      body: Center(
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
                      
                      Icon(Icons.lock_reset, size: 100, color: Colors.grey[400]),
                      const SizedBox(height: 32),
                      SizedBox(
                          width: double.infinity,
                          child: Text('Esqueceu sua senha?',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ))),
                      const SizedBox(height: 16),
                      Text(
                        'Não se preocupe! Insira seu email abaixo e enviaremos um link para redefinir sua senha.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      CustomInput(
                          hint: 'Digite seu email',
                          label: 'Email',
                          controller: emailController),
                      const SizedBox(height: 24),
                      CustomButton(
                        buttonText: 'Enviar Link de Recuperação',
                        backgroundColor:
                            const Color(0xFF424242), 
                        isLoading: _isLoading,
                        buttonAction: _sendResetLink,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}