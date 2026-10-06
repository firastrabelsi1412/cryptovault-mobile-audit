// lib/core/network.dart
// ✅ V3 — Validation TLS restaurée + certificate pinning : l'application ne fait
//         confiance QU'au certificat du serveur embarqué en asset. Un proxy
//         Burp avec un autre certificat fait échouer la requête.
// ✅ V4 — Plus aucun token ni payload dans les logs : métadonnées uniquement,
//         et seulement en mode debug.
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'config.dart';
import 'storage.dart';

class ApiClient {
  static Dio? _instance;

  /// À appeler UNE fois au démarrage, avant runApp :  await ApiClient.init();
  static Future<void> init() async {
    final certBytes = await rootBundle.load(AppConfig.pinnedCertAsset);

    // ✅ Contexte TLS qui ne fait confiance qu'à NOTRE certificat (pinning strict).
    final ctx = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(certBytes.buffer.asUint8List());

    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl, // https:// uniquement
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      // ✅ Aucun badCertificateCallback : toute erreur de certificat = échec.
      return HttpClient(context: ctx);
    };

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await LocalStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // ✅ V4 — métadonnées uniquement, jamais le token, et debug seulement.
        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.uri.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // ✅ Rafraîchissement transparent sur 401 (token d'accès court, 15 min).
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final req = error.requestOptions;
            final newTok = await LocalStorage.getToken();
            req.headers['Authorization'] = 'Bearer $newTok';
            try {
              final clone = await instance.fetch(req);
              return handler.resolve(clone);
            } catch (_) {/* retombe sur l'erreur d'origine */}
          }
        }
        if (kDebugMode) debugPrint('[API ERROR] ${error.type}');
        handler.next(error);
      },
    ));

    _instance = dio;
  }

  static Dio get instance {
    final dio = _instance;
    if (dio == null) {
      throw StateError('ApiClient.init() doit être appelé avant ApiClient.instance');
    }
    return dio;
  }

  static Future<bool> _tryRefresh() async {
    final refresh = await LocalStorage.getRefreshToken();
    if (refresh == null) return false;
    try {
      final r = await instance.post('/auth/refresh', data: {'token': refresh});
      final newAccess = r.data['accessToken'] as String?;
      if (newAccess == null) return false;
      await LocalStorage.updateAccessToken(newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }
}
