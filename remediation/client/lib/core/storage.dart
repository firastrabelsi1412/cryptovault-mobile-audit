// lib/core/storage.dart
// ✅ V2 — Stockage chiffré via Android Keystore (AES-256-GCM). Inaccessible via
//         `adb run-as` ou `adb backup`. On ne conserve QUE le strict minimum :
//         jeton d'accès, jeton de rafraîchissement, identifiant utilisateur.
//         Le solde, l'IBAN/adresse, le KYC sont relus via API au besoin ;
//         la seed phrase ne quitte jamais l'appareil en clair.
// ✅ V5b — logout() révoque le refresh token côté serveur PUIS efface tout.
//
// NB : on garde le nom de classe `LocalStorage` pour limiter les imports à
// modifier dans le reste de l'app. La logique, elle, est entièrement refaite.
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network.dart';

class LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';

  /// Enregistre la session après un POST /auth/login réussi.
  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: accessToken),
      _storage.write(key: _kRefresh, value: refreshToken),
      _storage.write(key: _kUserId, value: userId.toString()),
    ]);
  }

  /// Nom conservé (`getToken`) pour compatibilité avec le code appelant existant.
  static Future<String?> getToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _kUserId);
    return v == null ? null : int.tryParse(v);
  }

  static Future<void> updateAccessToken(String token) =>
      _storage.write(key: _kAccess, value: token);

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  /// ✅ V5b — Déconnexion COMPLÈTE : révocation serveur + effacement Keystore.
  static Future<void> logout() async {
    final refresh = await getRefreshToken();
    if (refresh != null) {
      try {
        await ApiClient.instance.post('/auth/revoke', data: {'token': refresh});
      } on DioException {
        /* serveur injoignable — on efface quand même localement */
      }
    }
    await _storage.deleteAll();
  }
}
