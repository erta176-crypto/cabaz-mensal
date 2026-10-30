/// Ecrã de bloqueio por cima de todas as rotas (Fase 8, D3–D5): com sessão
/// e o bloqueio ligado, bloqueia ao abrir a app e ao voltar a ela depois de
/// [tempoFora] ou mais em segundo plano.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desbloqueio.dart';
import '../../data/providers.dart';
import '../definicoes/definicoes_page.dart';

const tempoFora = Duration(minutes: 5);

/// Hora atual; substituída nos testes.
final agoraProvider = Provider<DateTime Function()>((_) => DateTime.now);

class CamadaBloqueio extends ConsumerStatefulWidget {
  const CamadaBloqueio({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CamadaBloqueio> createState() => _CamadaBloqueioState();
}

class _CamadaBloqueioState extends ConsumerState<CamadaBloqueio> {
  late final AppLifecycleListener _ciclo;

  /// null enquanto a escolha do bloqueio não foi lida (não mostra nada).
  bool? _bloqueada;
  DateTime? _saiuEm;

  bool get _deveBloquear =>
      (ref.read(bloqueioProvider).value ?? false) &&
      ref.read(authRepositoryProvider).temSessao;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onHide: () => _saiuEm = ref.read(agoraProvider)(),
      onShow: () {
        final saiu = _saiuEm;
        _saiuEm = null;
        if (saiu != null &&
            ref.read(agoraProvider)().difference(saiu) >= tempoFora &&
            _deveBloquear) {
          setState(() => _bloqueada = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ao arrancar: decide uma vez, quando a escolha estiver lida.
    if (_bloqueada == null && ref.watch(bloqueioProvider).hasValue) {
      _bloqueada = _deveBloquear;
    }
    // Sem sessão (saiu da conta) nunca fica bloqueada.
    ref.listen(sessaoProvider, (_, _) {
      if (!ref.read(authRepositoryProvider).temSessao && _bloqueada == true) {
        setState(() => _bloqueada = false);
      }
    });
    return Stack(
      children: [
        Offstage(offstage: _bloqueada != false, child: widget.child),
        if (_bloqueada == null)
          ColoredBox(color: Theme.of(context).colorScheme.surface)
        else if (_bloqueada!)
          // Navigator próprio: o "Sair" pode abrir um diálogo. Sem
          // HeroController: o da app só pode ter um Navigator.
          HeroControllerScope.none(
            child: Navigator(
              pages: [
                MaterialPage(
                  child: _EcraBloqueio(
                    aoDesbloquear: () => setState(() => _bloqueada = false),
                  ),
                ),
              ],
              onDidRemovePage: (_) {},
            ),
          ),
      ],
    );
  }
}

class _EcraBloqueio extends ConsumerStatefulWidget {
  const _EcraBloqueio({required this.aoDesbloquear});
  final VoidCallback aoDesbloquear;

  @override
  ConsumerState<_EcraBloqueio> createState() => _EcraBloqueioState();
}

class _EcraBloqueioState extends ConsumerState<_EcraBloqueio> {
  bool _aPedir = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Pede logo ao aparecer (D5).
    WidgetsBinding.instance.addPostFrameCallback((_) => _pedir());
  }

  Future<void> _pedir() async {
    if (_aPedir || !mounted) return;
    setState(() {
      _aPedir = true;
      _erro = null;
    });
    try {
      if (await ref.read(desbloqueioProvider).pedir()) {
        widget.aoDesbloquear();
        return;
      }
    } on ErroDesbloqueio catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _aPedir = false);
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
                const SizedBox(height: 8),
                const Text(
                  'A app está bloqueada.',
                  textAlign: TextAlign.center,
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _aPedir ? null : _pedir,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _aPedir ? null : () => sairDaConta(context, ref),
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
