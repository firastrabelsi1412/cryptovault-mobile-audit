# CryptoVault — backend sécurisé (Phase 2c)

Remplace l'ancien `json-server --watch db.json --routes routes.json`.
Express + HTTPS + JWT **RS256** + bcrypt + RBAC.

## Lancer
```
npm install      # une fois
start.bat        # ou : node server.js
```
Écoute en **HTTPS** sur `:3000`. Sur appareil réel, lancer l'app Flutter avec
`--dart-define=API_HOST=YOUR_LAN_IP` (l'IP est dans le SAN du certificat).

## Comptes de test
| Email | Mot de passe | Rôle |
|---|---|---|
| ali@cryptovault.tn | Ali2026! | user |
| sarra@cryptovault.tn | Sarra2026! | user |
| admin@cryptovault.tn | Admin@2026 | admin |

Le compte backdoor `dev@cryptovault.local` n'existe plus (V10b corrigé).

## Ce qui a changé vs version vulnérable
- **V6** : `userId` est imposé par le serveur d'après le JWT ; un user ne peut
  plus lire les transactions/wallets d'autrui.
- **V5a** : le rôle est vérifié côté serveur (JWT RS256) ; `/admin/whoami`.
- **V5b** : `POST /auth/revoke` blackliste le refresh token.
- **V10c** : plus de `/admin/dump-db`, `/admin/users-with-secrets`, `/test/faucet` ;
  `/admin/*` exige rôle admin **et** IP autorisée, et ne renvoie aucun secret.
- **V3** : tout passe en HTTPS (certificat épinglé côté app).
- **V1/V4** : clés via fichiers, logs = métadonnées seulement (jamais de token).

## Matériel cryptographique (DÉMO uniquement)
- `keys/jwt_private.pem` / `keys/jwt_public.pem` — paire RSA pour signer/vérifier les JWT.
- `certs/server.{key,crt}.pem` — certificat TLS auto-signé (SAN : YOUR_LAN_IP, 10.0.2.2, 127.0.0.1, localhost).
- L'app embarque **uniquement** `jwt_public.pem` et le `.crt` (jamais les clés privées).
- ⚠️ Régénérer pour tout usage réel.
