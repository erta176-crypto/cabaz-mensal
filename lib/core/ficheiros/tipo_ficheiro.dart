/// Tipo MIME pela extensão do nome do ficheiro.
String tipoDe(String nome) => switch (nome.split('.').last.toLowerCase()) {
  'json' => 'application/json',
  'csv' => 'text/csv',
  'txt' => 'text/plain',
  'pdf' => 'application/pdf',
  'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  _ => 'application/octet-stream',
};
