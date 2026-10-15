/// Configuração passada por --dart-define (ou --dart-define-from-file).
/// Só o Project URL e a chave anon/publishable; nunca a service_role.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get valida =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
