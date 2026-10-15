import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
final _data = DateFormat('d MMM y', 'pt_PT');
final _inteiro = NumberFormat.decimalPattern('pt_PT');

/// 465226 → "4652,26 €" (pt-PT; o separador de milhares é um espaço fino).
String formatarCent(int cent) => _moeda.format(cent / 100);

/// Valor em euros para um campo de texto: 123 → "1,23".
String centParaCampo(int cent) =>
    '${cent ~/ 100},${(cent % 100).toString().padLeft(2, '0')}';

String formatarData(DateTime d) => _data.format(d);

String formatarInteiro(int n) => _inteiro.format(n);
