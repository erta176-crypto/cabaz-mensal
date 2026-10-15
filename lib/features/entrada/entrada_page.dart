import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class EntradaPage extends ConsumerStatefulWidget {
  const EntradaPage({super.key});

  @override
  ConsumerState<EntradaPage> createState() => _EntradaPageState();
}

class _EntradaPageState extends ConsumerState<EntradaPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _palavraPasse = TextEditingController();
  bool _ocupado = false;
  String? _erro;
  String? _aviso;

  @override
  void dispose() {
    _email.dispose();
    _palavraPasse.dispose();
    super.dispose();
  }

  Future<void> _executar({required bool criar}) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _erro = null;
      _aviso = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (criar) {
        final comSessao = await auth.criarConta(
          email: _email.text.trim(),
          palavraPasse: _palavraPasse.text,
        );
        if (!comSessao && mounted) {
          setState(
            () => _aviso =
                'Conta criada. Confirma o email (abre a mensagem que '
                'recebeste) e depois entra aqui.',
          );
        }
      } else {
        await auth.entrar(
          email: _email.text.trim(),
          palavraPasse: _palavraPasse.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.shopping_basket,
                          size: 48,
                          color: tema.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cabaz Mensal',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Escreve um email válido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _palavraPasse,
                          decoration: const InputDecoration(
                            labelText: 'Palavra-passe',
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => v == null || v.length < 6
                              ? 'Mínimo de 6 caracteres.'
                              : null,
                          onFieldSubmitted: (_) => _executar(criar: false),
                        ),
                        if (_erro != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _erro!,
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                        ],
                        if (_aviso != null) ...[
                          const SizedBox(height: 16),
                          Text(_aviso!),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _ocupado
                              ? null
                              : () => _executar(criar: false),
                          child: const Text('Entrar'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _ocupado
                              ? null
                              : () => _executar(criar: true),
                          child: const Text('Criar conta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
