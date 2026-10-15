import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/local/repositorios_locais.dart';
import 'package:cabaz_mensal/data/sync/escrita.dart';
import 'package:cabaz_mensal/data/sync/sincronizador.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

import 'servidor_falso.dart';

/// Um telemóvel ou PC: base local em memória + fila + repositórios, todos
/// ligados ao mesmo [ServidorFalso].
class Dispositivo {
  Dispositivo(this.servidor) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    base = BaseLocal(NativeDatabase.memory());
    escrita = Escrita(base);
    sync = Sincronizador(
      base: base,
      servidor: servidor,
      utilizadorId: 'u1',
    );
    lojas = LocalLojasRepository(base, escrita, compras: (_) async => 0);
    categorias = LocalCategoriasRepository(base, escrita);
    artigos = LocalArtigosRepository(base, escrita);
    lista = LocalListaRepository(base, escrita);
    preferencias = LocalPreferenciasRepository(base, escrita);
    compras = LocalComprasRepository(base, escrita, _ConsultasFalsas());
  }

  final ServidorFalso servidor;
  late final BaseLocal base;
  late final Escrita escrita;
  late final Sincronizador sync;
  late final LocalLojasRepository lojas;
  late final LocalCategoriasRepository categorias;
  late final LocalArtigosRepository artigos;
  late final LocalListaRepository lista;
  late final LocalPreferenciasRepository preferencias;
  late final LocalComprasRepository compras;

  /// Envia a fila e puxa, como faria o sincronizador quando há rede.
  Future<void> sincronizar() async {
    await sync.enviar();
    await sync.puxar();
  }

  Future<void> fechar() async {
    await sync.fechar();
    await base.close();
  }
}

class _ConsultasFalsas implements ConsultasCompras {
  @override
  Future<int> contarCompras() async => 0;
  @override
  Future<int> comprasDaLoja(String lojaId) async => 0;
  @override
  Future<List<String>> locaisUsados(String lojaId) async => const [];
}
