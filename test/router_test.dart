import 'package:cabaz_mensal/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a app abre no Painel', () => expect(rotaInicial, '/painel'));

  test('com sessão, não mexe nas rotas', () {
    expect(redirecionar(temSessao: true, local: '/painel'), isNull);
    expect(redirecionar(temSessao: true, local: '/lista'), isNull);
  });

  test('sem sessão, vai para a entrada (e fica lá)', () {
    expect(redirecionar(temSessao: false, local: '/painel'), '/entrar');
    expect(redirecionar(temSessao: false, local: '/entrar'), isNull);
  });

  test('depois de entrar, vai para o Painel', () {
    expect(redirecionar(temSessao: true, local: '/entrar'), '/painel');
  });
}
