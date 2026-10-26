import 'package:cabaz_mensal/domain/orcamento.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dispositivo.dart';
import 'servidor_falso.dart';

final _out = DateTime(2026, 10);
final _set = DateTime(2026, 9);

void main() {
  late ServidorFalso servidor;
  late Dispositivo telemovel;
  late Dispositivo pc;

  setUp(() {
    servidor = ServidorFalso();
    telemovel = Dispositivo(servidor);
    pc = Dispositivo(servidor);
  });

  tearDown(() async {
    await telemovel.fechar();
    await pc.fechar();
  });

  List<Map<String, dynamic>> ativos() => [
    for (final o in servidor.t('orcamentos'))
      if (o['apagado_em'] == null) o,
  ];

  test(
    'definido sem rede é enviado depois e chega ao outro aparelho',
    () async {
      servidor.online = false;
      await telemovel.orcamentos.definir(_out, null, 50000);
      await telemovel.sincronizar().catchError((_) {});
      expect(servidor.t('orcamentos'), isEmpty);

      servidor.online = true;
      await telemovel.sincronizar();
      expect(ativos().single['valor_cent'], 50000);
      expect(ativos().single['id'], idOrcamento('u1', _out, null));

      await pc.sincronizar();
      final noPc = await pc.orcamentos.observar().first;
      expect(noPc.single.valorCent, 50000);
    },
  );

  test('dois aparelhos sem rede: uma só linha, vence o último', () async {
    servidor.online = false;
    await telemovel.orcamentos.definir(_out, null, 40000);
    await pc.orcamentos.definir(_out, null, 45000);
    servidor.online = true;
    await telemovel.sincronizar();
    await pc.sincronizar();
    await telemovel.sincronizar();

    expect(servidor.t('orcamentos'), hasLength(1));
    expect(ativos().single['valor_cent'], 45000);
    final noTelemovel = await telemovel.orcamentos.observar().first;
    expect(noTelemovel.single.valorCent, 45000);
  });

  test('apagar e voltar a definir reativa a mesma linha', () async {
    await telemovel.orcamentos.definir(_out, 'cat-fruta', 8000);
    await telemovel.sincronizar();
    await telemovel.orcamentos.definir(_out, 'cat-fruta', null);
    await telemovel.sincronizar();
    expect(ativos(), isEmpty);
    expect(await telemovel.orcamentos.observar().first, isEmpty);

    await telemovel.orcamentos.definir(_out, 'cat-fruta', 9000);
    await telemovel.sincronizar();
    expect(servidor.t('orcamentos'), hasLength(1));
    expect(ativos().single['valor_cent'], 9000);
  });

  test('copiar passa total e categorias para o mês seguinte', () async {
    await telemovel.orcamentos.definir(_set, null, 50000);
    await telemovel.orcamentos.definir(_set, 'cat-fruta', 8000);
    await telemovel.orcamentos.copiar(_set, _out);
    await telemovel.sincronizar();

    final outubro = [
      for (final o in await telemovel.orcamentos.observar().first)
        if (o.mes == _out) o,
    ];
    expect(outubro.map((o) => (o.categoriaId, o.valorCent)), {
      (null, 50000),
      ('cat-fruta', 8000),
    });
    expect(ativos(), hasLength(4));
  });

  test('limparCache apaga os orçamentos locais', () async {
    await telemovel.orcamentos.definir(_out, null, 50000);
    await telemovel.sincronizar();
    await telemovel.base.limparCache();
    expect(await telemovel.orcamentos.observar().first, isEmpty);
    await telemovel.sincronizar();
    expect(await telemovel.orcamentos.observar().first, hasLength(1));
  });
}
