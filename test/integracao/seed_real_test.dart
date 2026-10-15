// Teste de integração OPCIONAL com o seed real.
//
// Só corre quando existem:
//   - dados-privados/cabaz-seed.json
//   - env/local.json
//   - um Supabase LOCAL a correr (`supabase start`, precisa de Docker)
// Em qualquer outro caso faz skip, sem falhar. Nunca corre contra o projeto
// real: o URL usado é sempre o do Supabase local (127.0.0.1:54321).
// No CI não corre (não há seed nem Docker).

import 'dart:io';

import 'package:cabaz_mensal/data/supabase/supabase_repositorios.dart';
import 'package:cabaz_mensal/import/importar_seed.dart';
import 'package:cabaz_mensal/import/seed_modelo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _urlLocal = 'http://127.0.0.1:54321';

/// Chave anon de demonstração que o `supabase start` usa por omissão (é igual
/// em todas as instalações locais). Pode ser trocada com
/// SUPABASE_LOCAL_ANON_KEY.
const _chaveDemoLocal =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9s'
    'ZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

final _seed = File('dados-privados/cabaz-seed.json');
final _env = File('env/local.json');

Future<bool> _supabaseLocalAcessivel() async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final r = await (await http.getUrl(Uri.parse('$_urlLocal/auth/v1/health')))
        .close()
        .timeout(const Duration(seconds: 3));
    return r.statusCode < 500;
  } catch (_) {
    return false;
  } finally {
    http.close(force: true);
  }
}

Future<SupabaseClient> _novoUtilizador(String chave) async {
  final c = SupabaseClient(
    _urlLocal,
    chave,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final email = 'teste-${DateTime.now().microsecondsSinceEpoch}@exemplo.pt';
  await c.auth.signUp(email: email, password: 'palavra-passe-de-teste');
  if (c.auth.currentSession == null) {
    await c.auth.signInWithPassword(
      email: email,
      password: 'palavra-passe-de-teste',
    );
  }
  return c;
}

void main() {
  final faltam = [
    if (!_seed.existsSync()) 'dados-privados/cabaz-seed.json',
    if (!_env.existsSync()) 'env/local.json',
  ];

  test(
    'seed real no Supabase local: números certos e RLS isola utilizadores',
    () async {
      if (!await _supabaseLocalAcessivel()) {
        markTestSkipped(
          'Supabase local não está a correr (supabase start); teste saltado.',
        );
        return;
      }
      final chave =
          Platform.environment['SUPABASE_LOCAL_ANON_KEY'] ?? _chaveDemoLocal;
      final a = await _novoUtilizador(chave);
      final b = await _novoUtilizador(chave);

      final seed = SeedFicheiro.lerTexto(await _seed.readAsString());
      final dadosA = SupabaseDadosRepository(a);
      final r = await ImportadorSeed(
        dados: dadosA,
        lojas: SupabaseLojasRepository(a),
      ).importar(seed, substituir: true);

      expect(r.contagens['compras'], 138);
      expect(r.contagens['artigos'], 693);
      expect(r.contagens['lojas'], 3);
      expect(r.totalCent, 465226);
      for (final l in r.lojas) {
        expect(l.ok, isTrue, reason: 'total da loja ${l.slug}');
      }

      // RLS: o segundo utilizador não vê nada do primeiro.
      expect(await SupabaseComprasRepository(b).contarCompras(), 0);
      expect(await b.from('artigos').count(), 0);
      expect(await SupabaseLojasRepository(b).resumoPorLoja(), isEmpty);
      expect(await SupabaseDadosRepository(b).temDados(), isFalse);

      await dadosA.apagarTudo();
      await a.dispose();
      await b.dispose();
    },
    skip: faltam.isEmpty ? false : 'Faltam ${faltam.join(' e ')}.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
