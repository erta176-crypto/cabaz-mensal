import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../local/base_local.dart';
import '../repositorios.dart';
import 'servidor.dart';

/// Envia a fila de alterações e puxa as alterações do servidor.
///
/// - Envio por ordem; erro transitório para o envio (tenta mais tarde, com
///   espera crescente); erro permanente fica visível e não bloqueia a fila.
/// - Receção incremental por atualizado_em, com margem de sobreposição; as
///   linhas com alterações por enviar não são substituídas.
/// - Conflitos: vence a última escrita a chegar ao servidor.
class Sincronizador {
  Sincronizador({
    required this.base,
    required this.servidor,
    required this.utilizadorId,
    this.rede,
    this.margem = const Duration(minutes: 5),
    this.periodo = const Duration(seconds: 30),
    this.maxTentativas = 20,
  });

  final BaseLocal base;
  final ServidorSync servidor;
  final String utilizadorId;
  final Stream<bool>? rede;
  final Duration margem;
  final Duration periodo;

  /// Um erro "transitório" que se repete tantas vezes passa a permanente.
  final int maxTentativas;

  final _estado = StreamController<EstadoSync>.broadcast();
  EstadoSync _atual = const EstadoSync();
  EstadoSync get estadoAtual => _atual;
  Stream<EstadoSync> get estado async* {
    yield _atual;
    yield* _estado.stream;
  }

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _periodico;
  Timer? _novaTentativa;
  Timer? _atrasoRececao;
  int _falhasSeguidas = 0;
  int _ticks = 0;
  Future<void>? _emCurso;
  bool _repetir = false;
  bool _fechado = false;

  void _emitir(EstadoSync e) {
    _atual = e;
    if (!_estado.isClosed) _estado.add(e);
  }

  /// Prepara a cache para este utilizador e começa a sincronizar.
  Future<void> iniciar() async {
    final anterior = await base.lerEstado('utilizador');
    if (anterior != utilizadorId) {
      await base.limparTudo();
      await base.gravarEstado('utilizador', utilizadorId);
    }
    _subs.add(
      base.observarPendentes().listen((l) {
        final erro = l.where((p) => p.erro != null).length;
        _emitir(_atual.copyWith(pendentes: l.length - erro, comErro: erro));
      }),
    );
    final ligacao = rede;
    if (ligacao != null) {
      _subs.add(
        ligacao.listen((ligado) {
          if (ligado) {
            _falhasSeguidas = 0;
            sincronizar();
          } else {
            _emitir(_atual.copyWith(online: false));
          }
        }),
      );
    }
    _subs.add(
      servidor.alteracoes(tabelasSync).listen((_) {
        _atrasoRececao?.cancel();
        _atrasoRececao = Timer(const Duration(milliseconds: 400), sincronizar);
      }),
    );
    _periodico = Timer.periodic(periodo, (_) {
      _ticks++;
      // Com pendentes, tenta a cada período; sem pendentes, puxa de 2 em 2
      // (rede de segurança se o tempo real falhar).
      if (_atual.pendentes > 0 || _ticks.isEven) sincronizar();
    });
    await sincronizar();
  }

  /// Envia e depois puxa. Não corre duas vezes em paralelo: um pedido feito
  /// durante uma sincronização faz outra volta no fim.
  Future<void> sincronizar() {
    if (_fechado) return Future.value();
    if (_emCurso != null) {
      _repetir = true;
      return _emCurso!;
    }
    return _emCurso = _volta().whenComplete(() {
      _emCurso = null;
      if (_repetir && !_fechado) {
        _repetir = false;
        sincronizar();
      }
    });
  }

  Future<void> _volta() async {
    _emitir(_atual.copyWith(aSincronizar: true));
    try {
      await enviar();
      await puxar();
      _falhasSeguidas = 0;
      _novaTentativa?.cancel();
      _emitir(
        _atual.copyWith(
          online: true,
          ultimoErro: () => null,
          ultimaSincronizacao: DateTime.now(),
        ),
      );
    } on ErroSync catch (e) {
      // Um erro permanente ao puxar não tem remédio aqui: fica para a
      // próxima volta, sem dizer que não há rede.
      _registar('sincronizar', e);
      _emitir(
        _atual.copyWith(
          online: e.transitorio ? false : null,
          ultimoErro: () => e.mensagem,
        ),
      );
      if (e.transitorio) _falhasSeguidas++;
      _agendarNovaTentativa();
    } catch (e, s) {
      // Erro de programação (não de rede): fica visível em vez de parecer
      // "sem rede".
      _registar('sincronizar', e, s);
      _falhasSeguidas++;
      _emitir(_atual.copyWith(online: true, ultimoErro: () => '$e'));
      _agendarNovaTentativa();
    } finally {
      _emitir(_atual.copyWith(aSincronizar: false));
    }
  }

  void _registar(String onde, Object erro, [StackTrace? pilha]) {
    // Visível no logcat (Android) e na consola (web), também em release.
    // ignore: avoid_print
    print('[Sincronizador] $onde: $erro${pilha == null ? '' : '\n$pilha'}');
  }

  /// Espera crescente: 2 s, 4 s, 8 s… até 60 s.
  Duration get esperaAtual => Duration(
    seconds: min(60, 2 * pow(2, max(0, _falhasSeguidas - 1)).toInt()),
  );

  void _agendarNovaTentativa() {
    _novaTentativa?.cancel();
    _novaTentativa = Timer(esperaAtual, sincronizar);
  }

  /// Envia a fila por ordem. Lança [ErroSync] transitório se a rede falhar.
  Future<void> enviar() async {
    for (final p in await base.pendentesPorEnviar()) {
      if (_fechado) return;
      try {
        await _executar(p);
        await base.removerPendente(p.id);
      } on ErroSync catch (e) {
        final permanente =
            !e.transitorio || p.tentativas + 1 >= maxTentativas;
        await base.marcarTentativa(p.id, erro: permanente ? e.mensagem : null);
        if (!permanente) rethrow;
        // A cache pode ter ficado diferente do servidor: puxar outra vez
        // as tabelas afetadas desde o início.
        for (final t in _tabelasDe(p)) {
          await base.gravarEstado('cursor:$t', null);
        }
      }
    }
  }

  Future<void> _executar(Pendente p) {
    final payload = (jsonDecode(p.payload) as Map).cast<String, dynamic>();
    return switch (p.operacao) {
      'inserir' => servidor.inserir(
        p.alvo,
        (payload['linha'] as Map).cast<String, dynamic>(),
        onConflict: payload['on_conflict'] as String,
      ),
      'atualizar' => servidor.atualizar(
        p.alvo,
        (payload['filtro'] as Map).cast<String, Object?>(),
        (payload['campos'] as Map).cast<String, dynamic>(),
      ),
      'rpc' => servidor.rpc(p.alvo, payload),
      _ => throw ErroSync(
        'Operação desconhecida: ${p.operacao}',
        transitorio: false,
      ),
    };
  }

  Set<String> _tabelasDe(Pendente p) => {
    for (final c in p.chaves.split('\n'))
      if (c.contains(':')) c.substring(0, c.indexOf(':')),
  };

  /// Puxa as alterações de todas as tabelas em cache.
  Future<void> puxar() async {
    final bloqueadas = await base.chavesBloqueadas();
    // O cursor nunca fica mais atrás do que "agora − margem" no servidor: as
    // linhas antigas (ex.: importadas há horas) não voltam a ser puxadas a
    // cada volta, e uma escrita lenta dentro da margem continua a ser vista.
    final piso = (await servidor.agora()).subtract(margem);
    for (final tabela in tabelasSync) {
      if (_fechado) return;
      final cursorTxt = await base.lerEstado('cursor:$tabela');
      final cursor = cursorTxt == null ? null : DateTime.parse(cursorTxt);
      final linhas = await servidor.puxar(tabela, cursor?.subtract(margem));

      if (tabela == 'preferencias' && await _reiniciado(linhas)) {
        // Os dados foram apagados a sério no servidor: recomeçar do zero.
        return puxar();
      }

      DateTime? maior = cursor != null && cursor.isAfter(piso) ? cursor : piso;
      await base.transaction(() async {
        for (final linha in linhas) {
          final t = DateTime.parse(linha['atualizado_em'] as String);
          if (maior == null || t.isAfter(maior!)) maior = t;
          if (bloqueadas.contains('$tabela:${chaveDe(tabela, linha)}')) {
            continue;
          }
          await base.gravarLinha(tabela, linha);
        }
        await base.gravarEstado(
          'cursor:$tabela',
          maior!.toUtc().toIso8601String(),
        );
      });
    }
  }

  Future<bool> _reiniciado(List<Map<String, dynamic>> linhas) async {
    if (linhas.isEmpty) return false;
    final servidorValor = linhas.last['reiniciado_em'] as String?;
    final visto = await base.lerEstado('reiniciado_em');
    if (servidorValor == null || servidorValor == visto) return false;
    await base.limparCache();
    await base.gravarEstado('reiniciado_em', servidorValor);
    return true;
  }

  /// Descarta uma alteração com erro e volta a carregar as tabelas afetadas.
  Future<void> descartar(Pendente p) async {
    await base.transaction(() async {
      await base.removerPendente(p.id);
      for (final c in p.chaves.split('\n')) {
        final i = c.indexOf(':');
        if (i < 0) continue;
        await base.apagarLinha(c.substring(0, i), c.substring(i + 1));
        await base.gravarEstado('cursor:${c.substring(0, i)}', null);
      }
    });
    await sincronizar();
  }

  /// Volta a puxar tudo (ex.: depois de importar no servidor).
  Future<void> recarregarTudo() async {
    await base.limparCache();
    await sincronizar();
  }

  Future<void> fechar() async {
    _fechado = true;
    _periodico?.cancel();
    _novaTentativa?.cancel();
    _atrasoRececao?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _estado.close();
  }
}
