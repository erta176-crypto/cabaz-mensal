import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');

  if (!Config.valida) {
    runApp(const _SemConfiguracao());
    return;
  }

  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: CabazMensalApp()));
}

/// Mostrado quando a app é corrida sem --dart-define-from-file=env/local.json.
class _SemConfiguracao extends StatelessWidget {
  const _SemConfiguracao();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Falta a configuração do Supabase.\n'
            'Corre com: flutter run --dart-define-from-file=env/local.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
