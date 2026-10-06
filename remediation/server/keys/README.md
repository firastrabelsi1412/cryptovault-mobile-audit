# JWT signing keys

The server signs and verifies JWTs with RS256 and expects two files in this folder:

- `jwt_private.pem`: RSA private key. **Server only. Never commit it, never ship it in the app.**
- `jwt_public.pem`: matching public key.

Generate them locally (OpenSSL 1.1.1 or newer):

```bash
cd remediation/server/keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out jwt_private.pem
openssl pkey -in jwt_private.pem -pubout -out jwt_public.pem
```

The Flutter client bundles only `jwt_public.pem` (as `assets/keys/jwt_public.pem`, see `client/pubspec_changes.yaml`). Copy it there after generating it.

Both files are excluded by `.gitignore`.