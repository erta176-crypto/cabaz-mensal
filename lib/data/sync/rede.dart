import 'package:connectivity_plus/connectivity_plus.dart';

/// true quando o dispositivo tem alguma ligação (wifi, dados, ethernet…).
/// Não garante que o Supabase responda: isso vê-se ao enviar.
Stream<bool> observarRede() => Connectivity().onConnectivityChanged.map(
  (r) => r.any((c) => c != ConnectivityResult.none),
);
