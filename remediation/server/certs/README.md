# TLS certificate

The server runs over HTTPS and expects two files in this folder:

- `server.key.pem`: TLS private key. **Server only. Never commit it.**
- `server.crt.pem`: self-signed certificate, which the client pins.

Generate a self-signed certificate for local testing (OpenSSL 1.1.1 or newer). Replace `YOUR_LAN_IP` with the LAN address of the machine running the server; `10.0.2.2` is the Android emulator's alias for the host.

```bash
cd remediation/server/certs
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
  -keyout server.key.pem -out server.crt.pem \
  -subj "/CN=api.cryptovault.local" \
  -addext "subjectAltName=IP:YOUR_LAN_IP,IP:10.0.2.2,IP:127.0.0.1,DNS:localhost"
```

The IP you pass to `--dart-define=API_HOST=...` must appear in the certificate's subjectAltName, otherwise pinning fails.

The client pins the public certificate only. Copy it to `client/assets/certs/api.cryptovault.crt` (see `client/pubspec_changes.yaml`):

```bash
cp server.crt.pem ../../client/assets/certs/api.cryptovault.crt
```

Both generated files are excluded by `.gitignore`.