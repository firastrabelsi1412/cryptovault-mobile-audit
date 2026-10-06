// lib/core/config.dart
// ✅ V1 — Aucun secret embarqué. Plus de jwtSecret, de clés API tierces,
// d'URL d'admin interne ni de devMasterToken dans le binaire.
// L'hôte backend est injecté au build via --dart-define ; les éventuelles
// clés tierces sont obtenues via un appel authentifié au serveur, jamais
// compilées dans libapp.so.
class AppConfig {
  // Configurable au build :
  //   Émulateur (défaut) : flutter run
  //   Appareil réel      : flutter run --dart-define=API_HOST=YOUR_LAN_IP
  //   Localhost / dev     : flutter run --dart-define=API_HOST=127.0.0.1
  static const String _apiHost =
      String.fromEnvironment('API_HOST', defaultValue: '10.0.2.2');
  static const String _apiPort =
      String.fromEnvironment('API_PORT', defaultValue: '3000');
  // ✅ HTTPS par défaut — le backend sécurisé écoute en TLS.
  static const String _apiProto =
      String.fromEnvironment('API_PROTO', defaultValue: 'https');
  static String get apiBaseUrl => '$_apiProto://$_apiHost:$_apiPort';

  // Certificat épinglé côté client (clé publique du serveur uniquement).
  static const String pinnedCertAsset = 'assets/certs/api.cryptovault.crt';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
