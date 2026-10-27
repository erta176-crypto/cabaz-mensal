import 'package:flutter_test/flutter_test.dart';

import 'dispositivo.dart';
import 'servidor_falso.dart';

void main() {
  test(
    'guardarAlias sem rede sincroniza depois e chega ao outro aparelho',
    () async {
      final servidor = ServidorFalso();
      final telemovel = Dispositivo(servidor);
      final pc = Dispositivo(servidor);
      addTearDown(() async {
        await telemovel.fechar();
        await pc.fechar();
      });

      servidor.online = false;
      await telemovel.artigos.guardarAlias(
        'loja-lidl',
        'SALADA COM COENTROS',
        'a1',
      );
      expect(await telemovel.artigos.observarAliases().first, {
        'a1': ['SALADA COM COENTROS'],
      });

      servidor.online = true;
      await telemovel.sincronizar();
      expect(
        servidor.t('aliases').single['texto_talao'],
        'SALADA COM COENTROS',
      );
      expect(servidor.t('aliases').single['loja_id'], 'loja-lidl');

      await pc.sincronizar();
      expect(await pc.artigos.observarAliases().first, {
        'a1': ['SALADA COM COENTROS'],
      });

      // Gravar o mesmo alias outra vez não duplica.
      await telemovel.artigos.guardarAlias(
        'loja-lidl',
        'SALADA COM COENTROS',
        'a1',
      );
      await telemovel.sincronizar();
      expect(servidor.t('aliases'), hasLength(1));
    },
  );
}
