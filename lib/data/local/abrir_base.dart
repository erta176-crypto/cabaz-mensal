import 'package:drift_flutter/drift_flutter.dart';

import 'base_local.dart';

/// Abre a base local: SQLite no Android; na web, sqlite3.wasm com um worker
/// (os dois ficheiros estão em web/ e são publicados no GitHub Pages; os URIs
/// relativos resolvem-se com o base-href /cabaz-mensal/).
BaseLocal abrirBaseLocal() => BaseLocal(
  driftDatabase(
    name: 'cabaz_mensal',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  ),
);
